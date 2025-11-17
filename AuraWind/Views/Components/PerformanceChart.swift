//
//  PerformanceChart.swift
//  AuraWind
//
//  Created by AuraWind Development Team on 2025-11-17.
//

import SwiftUI
import Charts

/// 性能监控图表组件
/// 显示CPU、GPU、内存使用率的多轴图表
struct PerformanceChart: View {
    
    // MARK: - Properties
    
    /// CPU使用率数据
    let cpuData: [ChartDataPoint]
    
    /// GPU使用率数据
    let gpuData: [ChartDataPoint]
    
    /// 内存使用率数据
    let memoryData: [ChartDataPoint]
    
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
        cpuData: [ChartDataPoint] = [],
        gpuData: [ChartDataPoint] = [],
        memoryData: [ChartDataPoint] = [],
        displayMode: DisplayMode = .line,
        showLegend: Bool = true,
        showGrid: Bool = true,
        height: CGFloat = 300
    ) {
        self.cpuData = cpuData
        self.gpuData = gpuData
        self.memoryData = memoryData
        self.displayMode = displayMode
        self.showLegend = showLegend
        self.showGrid = showGrid
        self.height = height
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showLegend && hasAnyData {
                legendView
            }
            
            chartView
                .frame(height: height)
        }
    }
    
    // MARK: - Chart View
    
    @ViewBuilder
    private var chartView: some View {
        if !hasAnyData {
            emptyStateView
        } else {
            Chart {
                // CPU数据线
                ForEach(cpuData, id: \.id) { point in
                    switch displayMode {
                    case .line:
                        LineMark(
                            x: .value("时间", point.timestamp),
                            y: .value("使用率", point.value)
                        )
                        .foregroundStyle(by: .value("指标", "CPU"))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                        
                    case .area:
                        AreaMark(
                            x: .value("时间", point.timestamp),
                            y: .value("使用率", point.value)
                        )
                        .foregroundStyle(by: .value("指标", "CPU"))
                        .opacity(0.3)
                        .interpolationMethod(.catmullRom)
                        
                        LineMark(
                            x: .value("时间", point.timestamp),
                            y: .value("使用率", point.value)
                        )
                        .foregroundStyle(by: .value("指标", "CPU"))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                        
                    case .point:
                        PointMark(
                            x: .value("时间", point.timestamp),
                            y: .value("使用率", point.value)
                        )
                        .foregroundStyle(by: .value("指标", "CPU"))
                    }
                }
                
                // GPU数据线
                ForEach(gpuData, id: \.id) { point in
                    switch displayMode {
                    case .line:
                        LineMark(
                            x: .value("时间", point.timestamp),
                            y: .value("使用率", point.value)
                        )
                        .foregroundStyle(by: .value("指标", "GPU"))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                        
                    case .area:
                        AreaMark(
                            x: .value("时间", point.timestamp),
                            y: .value("使用率", point.value)
                        )
                        .foregroundStyle(by: .value("指标", "GPU"))
                        .opacity(0.3)
                        .interpolationMethod(.catmullRom)
                        
                        LineMark(
                            x: .value("时间", point.timestamp),
                            y: .value("使用率", point.value)
                        )
                        .foregroundStyle(by: .value("指标", "GPU"))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                        
                    case .point:
                        PointMark(
                            x: .value("时间", point.timestamp),
                            y: .value("使用率", point.value)
                        )
                        .foregroundStyle(by: .value("指标", "GPU"))
                    }
                }
                
                // 内存数据线
                ForEach(memoryData, id: \.id) { point in
                    switch displayMode {
                    case .line:
                        LineMark(
                            x: .value("时间", point.timestamp),
                            y: .value("使用率", point.value)
                        )
                        .foregroundStyle(by: .value("指标", "内存"))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                        
                    case .area:
                        AreaMark(
                            x: .value("时间", point.timestamp),
                            y: .value("使用率", point.value)
                        )
                        .foregroundStyle(by: .value("指标", "内存"))
                        .opacity(0.3)
                        .interpolationMethod(.catmullRom)
                        
                        LineMark(
                            x: .value("时间", point.timestamp),
                            y: .value("使用率", point.value)
                        )
                        .foregroundStyle(by: .value("指标", "内存"))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                        
                    case .point:
                        PointMark(
                            x: .value("时间", point.timestamp),
                            y: .value("使用率", point.value)
                        )
                        .foregroundStyle(by: .value("指标", "内存"))
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
                        if let usage = value.as(Double.self) {
                            Text("\(Int(usage))%")
                                .font(.caption2)
                                .foregroundStyle(labelColor)
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
                // CPU图例
                if !cpuData.isEmpty {
                    legendItem(label: "CPU", color: .blue, data: cpuData)
                }
                
                // GPU图例
                if !gpuData.isEmpty {
                    legendItem(label: "GPU", color: .green, data: gpuData)
                }
                
                // 内存图例
                if !memoryData.isEmpty {
                    legendItem(label: "内存", color: .orange, data: memoryData)
                }
            }
        }
    }
    
    private func legendItem(label: String, color: Color, data: [ChartDataPoint]) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(labelColor)
            
            if let latest = data.last {
                Text(String(format: "%.1f%%", latest.value))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
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
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("暂无性能数据")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("开始性能监控后将显示系统资源使用情况")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Methods
    
    
    /// 获取标签对应的颜色
    private func colorForLabel(_ label: String) -> Color {
        switch label {
        case "CPU":
            return .blue
        case "GPU":
            return .green
        case "内存":
            return .orange
        default:
            return .gray
        }
    }
    
    /// 格式化时间
    private func formatTime(_ date: Date) -> String {
        guard !cpuData.isEmpty || !gpuData.isEmpty || !memoryData.isEmpty else { return "" }
        
        let timeSpan = calculateTimeSpan()
        let dateFormat = getDateFormat(for: timeSpan)
        
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        return formatter.string(from: date)
    }
    
    /// 计算时间跨度
    private func calculateTimeSpan() -> TimeInterval {
        let allData = cpuData + gpuData + memoryData
        guard !allData.isEmpty else { return 3600 } // 默认1小时
        
        let maxTimestamp = allData.max { $0.timestamp < $1.timestamp }?.timestamp ?? Date()
        let minTimestamp = allData.min { $0.timestamp < $1.timestamp }?.timestamp ?? Date()
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
        let allData = cpuData + gpuData + memoryData
        guard !allData.isEmpty else { return .minute }
        
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
    
    // MARK: - Helper Properties
    
    private var hasAnyData: Bool {
        return !cpuData.isEmpty || !gpuData.isEmpty || !memoryData.isEmpty
    }
    
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
struct PerformanceChart_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 完整性能图表
                BlurGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("系统性能监控")
                            .font(.headline)
                        
                        PerformanceChart(
                            cpuData: ChartDataPoint.cpuUsageExamples(count: 60),
                            gpuData: ChartDataPoint.gpuUsageExamples(count: 60),
                            memoryData: ChartDataPoint.memoryUsageExamples(count: 60),
                            displayMode: .line,
                            height: 250
                        )
                    }
                }
                .padding()
                
                // 单独CPU图表
                BlurGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("CPU使用率")
                            .font(.headline)
                        
                        PerformanceChart(
                            cpuData: ChartDataPoint.cpuUsageExamples(count: 60),
                            displayMode: .area,
                            height: 200
                        )
                    }
                }
                .padding()
                
                // 空状态
                BlurGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("空状态")
                            .font(.headline)
                        
                        PerformanceChart()
                    }
                }
                .padding()
            }
        }
        .auraBackground()
    }
}

// 扩展示例数据生成
extension ChartDataPoint {
    static func cpuUsageExamples(count: Int = 30) -> [ChartDataPoint] {
        let now = Date()
        return (0..<count).map { index in
            let timestamp = now.addingTimeInterval(-Double(count - index) * 5)
            let baseUsage = 25.0
            let variation = Double.random(in: -15...60)
            return ChartDataPoint(
                timestamp: timestamp,
                value: max(0, min(100, baseUsage + variation)),
                label: "CPU使用率",
                type: .cpuUsage
            )
        }
    }
    
    static func gpuUsageExamples(count: Int = 30) -> [ChartDataPoint] {
        let now = Date()
        return (0..<count).map { index in
            let timestamp = now.addingTimeInterval(-Double(count - index) * 5)
            let baseUsage = 15.0
            let variation = Double.random(in: -10...40)
            return ChartDataPoint(
                timestamp: timestamp,
                value: max(0, min(100, baseUsage + variation)),
                label: "GPU使用率",
                type: .gpuUsage
            )
        }
    }
    
    static func memoryUsageExamples(count: Int = 30) -> [ChartDataPoint] {
        let now = Date()
        return (0..<count).map { index in
            let timestamp = now.addingTimeInterval(-Double(count - index) * 5)
            let baseUsage = 45.0
            let variation = Double.random(in: -5...20)
            return ChartDataPoint(
                timestamp: timestamp,
                value: max(0, min(100, baseUsage + variation)),
                label: "内存使用率",
                type: .cpuUsage // 使用CPU类型作为内存的替代
            )
        }
    }
}
#endif