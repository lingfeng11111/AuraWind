//
//  TemperatureFanChart.swift
//  AuraWind
//
//  Created by AuraWind Development Team on 2025-11-17.
//

import SwiftUI
import Charts

/// 温度-转速关联图表组件
/// 双Y轴显示温度和风扇转速的关系
struct TemperatureFanChart: View {
    
    // MARK: - Properties
    
    /// 温度数据点
    let temperatureData: [ChartDataPoint]
    
    /// 风扇转速数据点
    let fanSpeedData: [ChartDataPoint]
    
    /// 显示模式
    let displayMode: DisplayMode
    
    /// 是否显示图例
    let showLegend: Bool
    
    /// 是否显示网格
    let showGrid: Bool
    
    /// 图表高度
    let height: CGFloat
    
    /// 当前配色方案
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Initialization
    
    init(
        temperatureData: [ChartDataPoint],
        fanSpeedData: [ChartDataPoint],
        displayMode: DisplayMode = .line,
        showLegend: Bool = true,
        showGrid: Bool = true,
        height: CGFloat = 300
    ) {
        self.temperatureData = temperatureData
        self.fanSpeedData = fanSpeedData
        self.displayMode = displayMode
        self.showLegend = showLegend
        self.showGrid = showGrid
        self.height = height
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showLegend && (!uniqueTemperatureLabels.isEmpty || !uniqueFanLabels.isEmpty) {
                legendView
            }
            
            chartView
                .frame(height: height)
        }
    }
    
    // MARK: - Chart View
    
    @ViewBuilder
    private var chartView: some View {
        if temperatureData.isEmpty && fanSpeedData.isEmpty {
            emptyStateView
        } else {
            Chart {
                // 温度数据线
                ForEach(uniqueTemperatureLabels, id: \.self) { label in
                    let points = temperatureData.filter { $0.label == label }
                    
                    ForEach(points, id: \.id) { point in
                        switch displayMode {
                        case .line:
                            LineMark(
                                x: .value("时间", point.timestamp),
                                y: .value("温度", point.value)
                            )
                            .foregroundStyle(by: .value("传感器", label))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                            .interpolationMethod(.catmullRom)
                            
                        case .area:
                            AreaMark(
                                x: .value("时间", point.timestamp),
                                y: .value("温度", point.value)
                            )
                            .foregroundStyle(by: .value("传感器", label))
                            .opacity(0.2)
                            .interpolationMethod(.catmullRom)
                            
                        case .point:
                            PointMark(
                                x: .value("时间", point.timestamp),
                                y: .value("温度", point.value)
                            )
                            .foregroundStyle(by: .value("传感器", label))
                        }
                    }
                }
                
                // 风扇转速数据线
                ForEach(uniqueFanLabels, id: \.self) { label in
                    let points = fanSpeedData.filter { $0.label == label }
                    
                    ForEach(points, id: \.id) { point in
                        switch displayMode {
                        case .line:
                            LineMark(
                                x: .value("时间", point.timestamp),
                                y: .value("转速", point.value)
                            )
                            .foregroundStyle(by: .value("风扇", label))
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.catmullRom)
                            
                        case .area:
                            AreaMark(
                                x: .value("时间", point.timestamp),
                                y: .value("转速", point.value)
                            )
                            .foregroundStyle(by: .value("风扇", label))
                            .opacity(0.3)
                            .interpolationMethod(.catmullRom)
                            
                            LineMark(
                                x: .value("时间", point.timestamp),
                                y: .value("转速", point.value)
                            )
                            .foregroundStyle(by: .value("风扇", label))
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.catmullRom)
                            
                        case .point:
                            PointMark(
                                x: .value("时间", point.timestamp),
                                y: .value("转速", point.value)
                            )
                            .foregroundStyle(by: .value("风扇", label))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: xAxisStride)) { value in
                    if let date = value.as(Date.self) {
                        AxisGridLine(stroke: StrokeStyle(
                            lineWidth: showGrid ? 0.5 : 0,
                            dash: [2, 2]
                        ))
                        .foregroundStyle(gridColor)
                        
                        AxisValueLabel {
                            Text(formatTime(date))
                                .font(.caption2)
                                .foregroundStyle(labelColor)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(
                        lineWidth: showGrid ? 0.5 : 0,
                        dash: [2, 2]
                    ))
                    .foregroundStyle(gridColor)
                    
                    AxisValueLabel {
                        if let temp = value.as(Double.self) {
                            if temp < 200 { // 温度数据
                                Text("\(Int(temp))°C")
                                    .font(.caption2)
                                    .foregroundStyle(temperatureLabelColor)
                            } else { // 转速数据
                                Text(formatRPM(temp))
                                    .font(.caption2)
                                    .foregroundStyle(fanLabelColor)
                            }
                        }
                    }
                }
            }
            .chartForegroundStyleScale { label in
                colorForLabel(label)
            }
            .chartLegend(showLegend ? .visible : .hidden)
            .chartPlotStyle { plotArea in
                plotArea
                    .background(plotBackgroundColor)
                    .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Legend View
    
    private var legendView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // 温度传感器图例
                ForEach(uniqueTemperatureLabels, id: \.self) { label in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(colorForLabel(label))
                            .frame(width: 8, height: 8)
                        
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(temperatureLabelColor)
                        
                        if let latest = latestTemperatureValue(for: label) {
                            Text(ChartDataPoint.DataType.temperature.formatted(latest))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(colorForLabel(label))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark
                                ? Color.white.opacity(0.05)
                                : Color.black.opacity(0.03))
                    )
                }
                
                // 风扇图例
                ForEach(uniqueFanLabels, id: \.self) { label in
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(colorForLabel(label))
                            .frame(width: 12, height: 2)
                        
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(fanLabelColor)
                        
                        if let latest = latestFanValue(for: label) {
                            Text(formatRPM(latest))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(colorForLabel(label))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark
                                ? Color.white.opacity(0.05)
                                : Color.black.opacity(0.03))
                    )
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("暂无关联数据")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("温度和风扇数据将显示关联趋势")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helpers
    
    /// 唯一的温度传感器标签
    private var uniqueTemperatureLabels: [String] {
        let labels = temperatureData.map { $0.label }
        let uniqueSet = Set<String>(labels)
        return Array<String>(uniqueSet).sorted()
    }
    
    /// 唯一的风扇标签
    private var uniqueFanLabels: [String] {
        let labels = fanSpeedData.map { $0.label }
        let uniqueSet = Set<String>(labels)
        return Array<String>(uniqueSet).sorted()
    }
    
    /// 获取标签对应的颜色
    private func colorForLabel(_ label: String) -> Color {
        let tempLabels = uniqueTemperatureLabels
        let fanLabels = uniqueFanLabels
        
        if let index = tempLabels.firstIndex(of: label) {
            return getTemperatureColorAtIndex(index)
        } else if let index = fanLabels.firstIndex(of: label) {
            return getFanColorAtIndex(index)
        }
        
        return .gray
    }
    
    /// 根据索引获取温度颜色
    private func getTemperatureColorAtIndex(_ index: Int) -> Color {
        let colors = getTemperatureChartColors()
        return colors[index % colors.count]
    }
    
    /// 根据索引获取风扇颜色
    private func getFanColorAtIndex(_ index: Int) -> Color {
        let colors = getFanChartColors()
        return colors[index % colors.count]
    }
    
    /// 获取温度图表颜色数组
    private func getTemperatureChartColors() -> [Color] {
        return [
            Color.statusWarning,
            Color.statusDanger,
            Color.auraYellow,
            Color.orange
        ]
    }
    
    /// 获取风扇图表颜色数组
    private func getFanChartColors() -> [Color] {
        return [
            Color.auraBrightBlue,
            Color.auraSkyBlue,
            Color.auraMediumBlue,
            Color.auraPurple
        ]
    }
    
    /// 获取温度标签的最新值
    private func latestTemperatureValue(for label: String) -> Double? {
        let filteredPoints = temperatureData.filter { $0.label == label }
        guard !filteredPoints.isEmpty else { return nil }
        let latestPoint = filteredPoints.max { $0.timestamp < $1.timestamp }
        return latestPoint?.value
    }
    
    /// 获取风扇标签的最新值
    private func latestFanValue(for label: String) -> Double? {
        let filteredPoints = fanSpeedData.filter { $0.label == label }
        guard !filteredPoints.isEmpty else { return nil }
        let latestPoint = filteredPoints.max { $0.timestamp < $1.timestamp }
        return latestPoint?.value
    }
    
    /// 格式化时间
    private func formatTime(_ date: Date) -> String {
        guard !temperatureData.isEmpty || !fanSpeedData.isEmpty else { return "" }
        
        let timeSpan = calculateTimeSpan()
        let dateFormat = getDateFormat(for: timeSpan)
        
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        return formatter.string(from: date)
    }
    
    /// 格式化转速
    private func formatRPM(_ rpm: Double) -> String {
        if rpm >= 1000 {
            return String(format: "%.1fk", rpm / 1000)
        } else {
            return String(format: "%.0f", rpm)
        }
    }
    
    /// 计算时间跨度
    private func calculateTimeSpan() -> TimeInterval {
        let tempMax = temperatureData.max { $0.timestamp < $1.timestamp }?.timestamp ?? Date()
        let tempMin = temperatureData.min { $0.timestamp < $1.timestamp }?.timestamp ?? Date()
        let fanMax = fanSpeedData.max { $0.timestamp < $1.timestamp }?.timestamp ?? Date()
        let fanMin = fanSpeedData.min { $0.timestamp < $1.timestamp }?.timestamp ?? Date()
        
        let maxTimestamp = max(tempMax, fanMax)
        let minTimestamp = min(tempMin, fanMin)
        
        return maxTimestamp.timeIntervalSince(minTimestamp)
    }
    
    /// 根据时间跨度获取日期格式
    private func getDateFormat(for timeSpan: TimeInterval) -> String {
        if timeSpan > 3600 * 12 {
            return "MM/dd HH:mm"  // 超过12小时，显示日期+时间
        } else if timeSpan > 3600 {
            return "HH:mm"        // 1-12小时，显示时:分
        } else {
            return "HH:mm:ss"     // 小于1小时，显示时:分:秒
        }
    }
    
    /// X轴刻度间隔
    private var xAxisStride: Calendar.Component {
        let timeSpan = calculateTimeSpan()
        return getCalendarComponent(for: timeSpan)
    }
    
    /// 根据时间跨度获取日历组件
    private func getCalendarComponent(for timeSpan: TimeInterval) -> Calendar.Component {
        if timeSpan > 3600 * 12 {
            return .hour
        } else if timeSpan > 3600 {
            return .minute
        } else {
            return .second
        }
    }
    
    // MARK: - Colors
    
    private var gridColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.1)
            : Color.black.opacity(0.1)
    }
    
    private var labelColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.7)
            : Color.black.opacity(0.6)
    }
    
    private var temperatureLabelColor: Color {
        colorScheme == .dark
            ? Color.orange.opacity(0.8)
            : Color.red.opacity(0.7)
    }
    
    private var fanLabelColor: Color {
        colorScheme == .dark
            ? Color.auraBrightBlue.opacity(0.8)
            : Color.auraLogoBlue.opacity(0.7)
    }
    
    private var plotBackgroundColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.02)
            : Color.black.opacity(0.01)
    }
    
    // MARK: - Display Mode
    
    /// 图表显示模式
    enum DisplayMode {
        /// 折线图
        case line
        /// 面积图
        case area
        /// 散点图
        case point
    }
}

// MARK: - Preview

#if DEBUG
struct TemperatureFanChart_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 温度-风扇关联图
                BlurGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("温度-风扇关联趋势")
                            .font(.headline)
                        
                        TemperatureFanChart(
                            temperatureData: ChartDataPoint.temperatureExamples(count: 60, label: "CPU"),
                            fanSpeedData: ChartDataPoint.fanSpeedExamples(count: 60, label: "风扇1"),
                            displayMode: .line,
                            height: 250
                        )
                    }
                }
                .padding()
                
                // 空状态
                BlurGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("空状态")
                            .font(.headline)
                        
                        TemperatureFanChart(
                            temperatureData: [],
                            fanSpeedData: [],
                            height: 200
                        )
                    }
                }
                .padding()
            }
        }
        .auraBackground()
    }
}
#endif