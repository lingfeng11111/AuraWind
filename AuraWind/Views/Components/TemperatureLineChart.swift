//
//  TemperatureLineChart.swift
//  AuraWind
//
//  Created by AuraWind Development Team on 2025-11-17.
//

import SwiftUI
import Charts

/// 温度折线图组件
/// 使用Swift Charts展示多传感器温度趋势
struct TemperatureLineChart: View {
    
    // MARK: - Properties
    
    /// 图表数据点
    let dataPoints: [ChartDataPoint]
    
    /// 显示模式
    let displayMode: DisplayMode
    
    /// 是否显示图例
    let showLegend: Bool
    
    /// 是否显示网格
    let showGrid: Bool
    
    /// 图表高度
    let height: CGFloat
    
    /// Y轴范围（可选，如果不提供则使用自动范围）
    let yAxisRange: YAxisRange?
    
    /// 范围管理器（可选，用于动态范围管理）
    let rangeManager: ChartRangeManager?
    
    /// 当前配色方案
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Initialization
    
    init(
        dataPoints: [ChartDataPoint],
        displayMode: DisplayMode = .line,
        showLegend: Bool = true,
        showGrid: Bool = true,
        height: CGFloat = 300,
        yAxisRange: YAxisRange? = nil,
        rangeManager: ChartRangeManager? = nil
    ) {
        self.dataPoints = dataPoints
        self.displayMode = displayMode
        self.showLegend = showLegend
        self.showGrid = showGrid
        self.height = height
        self.yAxisRange = yAxisRange
        self.rangeManager = rangeManager
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showLegend && !uniqueLabels.isEmpty {
                legendView
            }
            
            chartView
                .frame(height: height)
        }
    }
    
    // MARK: - Chart View
    
    @ViewBuilder
    private var chartView: some View {
        if dataPoints.isEmpty {
            emptyStateView
        } else {
            Chart {
                ForEach(uniqueLabels, id: \.self) { label in
                    let points = dataPoints.filter { $0.label == label }
                    
                    ForEach(points, id: \.id) { point in
                        switch displayMode {
                        case .line:
                            LineMark(
                                x: .value("时间", point.timestamp),
                                y: .value("温度", point.value)
                            )
                            .foregroundStyle(by: .value("传感器", label))
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.catmullRom)
                            
                        case .area:
                            AreaMark(
                                x: .value("时间", point.timestamp),
                                y: .value("温度", point.value)
                            )
                            .foregroundStyle(by: .value("传感器", label))
                            .opacity(0.3)
                            .interpolationMethod(.catmullRom)
                            
                            LineMark(
                                x: .value("时间", point.timestamp),
                                y: .value("温度", point.value)
                            )
                            .foregroundStyle(by: .value("传感器", label))
                            .lineStyle(StrokeStyle(lineWidth: 2))
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
                            Text("\(Int(temp))°C")
                                .font(.caption2)
                                .foregroundStyle(labelColor)
                        }
                    }
                }
            }
            .chartYScale(domain: getYAxisDomain())
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
                ForEach(uniqueLabels, id: \.self) { label in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(colorForLabel(label))
                            .frame(width: 8, height: 8)
                        
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(labelColor)
                        
                        if let latest = latestValue(for: label) {
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
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("暂无数据")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("开始监控后将显示温度趋势图")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helpers
    
    /// 唯一的传感器标签
    private var uniqueLabels: [String] {
        let labels = dataPoints.map { $0.label }
        let uniqueSet = Set<String>(labels)
        return Array<String>(uniqueSet).sorted()
    }
    
    /// 获取标签对应的颜色
    private func colorForLabel(_ label: String) -> Color {
        let labels = uniqueLabels
        let index = labels.firstIndex(of: label) ?? 0
        return getColorAtIndex(index)
    }
    
    /// 根据索引获取颜色（简化复杂表达式）
    private func getColorAtIndex(_ index: Int) -> Color {
        let colors = getChartColors()
        return colors[index % colors.count]
    }
    
    /// 获取图表颜色数组
    private func getChartColors() -> [Color] {
        return [
            Color.auraBrightBlue,
            Color.auraSkyBlue,
            Color.auraMediumBlue,
            Color.auraYellow,
            Color.auraPurple,
            Color.statusNormal,
            Color.statusWarning
        ]
    }
    
    /// 获取标签的最新值
    private func latestValue(for label: String) -> Double? {
        let filteredPoints = dataPoints.filter { $0.label == label }
        guard !filteredPoints.isEmpty else { return nil }
        let latestPoint = filteredPoints.max { $0.timestamp < $1.timestamp }
        return latestPoint?.value
    }
    
    /// 格式化时间
    private func formatTime(_ date: Date) -> String {
        guard !dataPoints.isEmpty else { return "" }
        
        let timeSpan = calculateTimeSpan()
        let dateFormat = getDateFormat(for: timeSpan)
        
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        return formatter.string(from: date)
    }
    
    /// 计算时间跨度
    private func calculateTimeSpan() -> TimeInterval {
        let maxTimestamp = getMaxTimestamp()
        let minTimestamp = getMinTimestamp()
        return maxTimestamp.timeIntervalSince(minTimestamp)
    }
    
    /// 获取最大时间戳
    private func getMaxTimestamp() -> Date {
        return dataPoints.max { $0.timestamp < $1.timestamp }?.timestamp ?? Date()
    }
    
    /// 获取最小时间戳
    private func getMinTimestamp() -> Date {
        return dataPoints.min { $0.timestamp < $1.timestamp }?.timestamp ?? Date()
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
        guard !dataPoints.isEmpty else { return .minute }
        
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
    
    /// 获取Y轴范围域
    private func getYAxisDomain() -> ClosedRange<Double> {
        // 优先使用提供的范围管理器
        if let rangeManager = rangeManager {
            let (min, max) = rangeManager.getActualRange(for: dataPoints, type: .temperature)
            return min...max
        }
        
        // 其次使用提供的静态范围
        if let yAxisRange = yAxisRange {
            let (min, max) = yAxisRange.getActualRange(for: dataPoints)
            return min...max
        }
        
        // 默认自动计算范围
        let values = dataPoints.map { $0.value }
        guard !values.isEmpty else { return 0...100 }
        
        let dataMin = values.min() ?? 0
        let dataMax = values.max() ?? 100
        let range = dataMax - dataMin
        let padding = range * 0.1
        
        let min = max(0, dataMin - padding)
        let max = dataMax + padding
        
        return min...max
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
struct TemperatureLineChart_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 折线图
                BlurGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("温度趋势 - 折线图")
                            .font(.headline)
                        
                        TemperatureLineChart(
                            dataPoints: ChartDataPoint.temperatureExamples(count: 60, label: "CPU")
                                + ChartDataPoint.temperatureExamples(count: 60, label: "GPU"),
                            displayMode: .line,
                            height: 250
                        )
                    }
                }
                .padding()
                
                // 面积图
                BlurGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("温度趋势 - 面积图")
                            .font(.headline)
                        
                        TemperatureLineChart(
                            dataPoints: ChartDataPoint.temperatureExamples(count: 60, label: "CPU"),
                            displayMode: .area,
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
                        
                        TemperatureLineChart(
                            dataPoints: [],
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