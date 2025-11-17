//
//  DataAnnotationView.swift
//  AuraWind
//
//  Created by AuraWind Development Team on 2025-11-17.
//

import SwiftUI
import Combine

/// 数据标注显示组件
/// 在图表上显示数据标注和事件标记
struct DataAnnotationView: View {
    
    // MARK: - Properties
    
    /// 数据标注
    let annotations: [DataAnnotation]
    
    /// 事件标记
    let eventMarkers: [EventMarker]
    
    /// 图表数据点（用于坐标计算）
    let dataPoints: [ChartDataPoint]
    
    /// 图表类型
    let chartType: ChartType
    
    /// 是否显示标注
    @State private var showAnnotations: Bool = true
    
    /// 是否显示事件标记
    @State private var showEventMarkers: Bool = true
    
    /// 当前配色方案
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Initialization
    
    init(
        annotations: [DataAnnotation],
        eventMarkers: [EventMarker],
        dataPoints: [ChartDataPoint],
        chartType: ChartType
    ) {
        self.annotations = annotations
        self.eventMarkers = eventMarkers
        self.dataPoints = dataPoints
        self.chartType = chartType
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题和控制
            headerSection
            
            // 标注列表
            if showAnnotations && !visibleAnnotations.isEmpty {
                annotationsSection
            }
            
            // 事件标记列表
            if showEventMarkers && !visibleEventMarkers.isEmpty {
                eventMarkersSection
            }
            
            // 空状态
            if visibleAnnotations.isEmpty && visibleEventMarkers.isEmpty {
                emptyStateSection
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark
                    ? Color.white.opacity(0.05)
                    : Color.black.opacity(0.03))
        )
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        HStack {
            Label("数据标注", systemImage: "pin.fill")
                .font(.headline)
            
            Spacer()
            
            // 显示控制按钮
            HStack(spacing: 8) {
                Button {
                    showAnnotations.toggle()
                } label: {
                    Image(systemName: showAnnotations ? "eye" : "eye.slash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .help(showAnnotations ? "隐藏标注" : "显示标注")
                
                Button {
                    showEventMarkers.toggle()
                } label: {
                    Image(systemName: showEventMarkers ? "flag.fill" : "flag.slash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .help(showEventMarkers ? "隐藏事件" : "显示事件")
            }
        }
    }
    
    private var annotationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("数据标注 (\(visibleAnnotations.count))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("清除") {
                    clearAnnotations()
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(visibleAnnotations) { annotation in
                        AnnotationRow(annotation: annotation)
                    }
                }
            }
            .frame(maxHeight: 150)
        }
    }
    
    private var eventMarkersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("事件标记 (\(visibleEventMarkers.count))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("清除") {
                    clearEventMarkers()
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(visibleEventMarkers) { marker in
                        EventMarkerRow(marker: marker)
                    }
                }
            }
            .frame(maxHeight: 150)
        }
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "pin.slash")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text("暂无标注")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("系统会自动检测数据极值和事件")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // MARK: - Helper Properties
    
    private var visibleAnnotations: [DataAnnotation] {
        annotations.filter { $0.isVisible }
    }
    
    private var visibleEventMarkers: [EventMarker] {
        eventMarkers.filter { $0.isVisible }
    }
    
    // MARK: - Helper Methods
    
    private func clearAnnotations() {
        // 这里可以调用数据管理器来清除标注
        // 由于annotations是let常量，我们需要通过其他方式处理
        // 在实际应用中，这里应该调用数据管理器的方法
    }
    
    private func clearEventMarkers() {
        // 这里可以调用数据管理器来清除事件标记
        // 由于eventMarkers是let常量，我们需要通过其他方式处理
        // 在实际应用中，这里应该调用数据管理器的方法
    }
    
    /// 获取标注在图表上的位置（相对坐标）
    func getAnnotationPosition(_ annotation: DataAnnotation, in geometry: CGSize) -> CGPoint {
        // 简化的位置计算，实际使用时需要更精确的时间到X坐标转换
        let timeRange = getTimeRange()
        let x = getXPosition(for: annotation.timestamp, in: timeRange, width: geometry.width)
        let y = getYPosition(for: annotation.value ?? 0, height: geometry.height)
        
        return CGPoint(x: x, y: y)
    }
    
    /// 获取事件标记在图表上的位置
    func getEventMarkerPosition(_ marker: EventMarker, in geometry: CGSize) -> CGPoint {
        let timeRange = getTimeRange()
        let x = getXPosition(for: marker.timestamp, in: timeRange, width: geometry.width)
        
        return CGPoint(x: x, y: geometry.height * 0.1) // 事件标记显示在顶部
    }
    
    private func getTimeRange() -> ChartDataPoint.TimeRange {
        // 根据数据点自动推断时间范围
        return .oneHour // 默认使用1小时范围
    }
    
    private func getXPosition(for timestamp: Date, in timeRange: ChartDataPoint.TimeRange, width: CGFloat) -> CGFloat {
        let totalDuration = timeRange.interval
        let timeSinceStart = Date().timeIntervalSince(timestamp)
        let progress = min(max(0, timeSinceStart / totalDuration), 1)
        
        return width * (1 - progress) // 时间从右到左
    }
    
    private func getYPosition(for value: Double, height: CGFloat) -> CGFloat {
        // 简化的Y位置计算，实际使用时需要根据具体数值范围
        let normalizedValue = max(0, min(1, value / 100)) // 假设最大值为100
        return height * (1 - normalizedValue) // 数值从下到上
    }
}

// MARK: - Annotation Row

private struct AnnotationRow: View {
    let annotation: DataAnnotation
    
    var body: some View {
        HStack(spacing: 8) {
            // 图标
            Image(systemName: annotation.type.iconName)
                .font(.caption)
                .foregroundColor(Color(hex: annotation.type.color))
                .frame(width: 16, height: 16)
            
            // 内容
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(annotation.type.displayName)
                        .font(.caption.bold())
                    
                    if let value = annotation.value {
                        Text(String(format: "%.1f", value))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(formatTime(annotation.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if let description = annotation.description {
                    Text(description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: annotation.type.color).opacity(0.1))
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - Event Marker Row

private struct EventMarkerRow: View {
    let marker: EventMarker
    
    var body: some View {
        HStack(spacing: 8) {
            // 图标
            Image(systemName: marker.eventType.iconName)
                .font(.caption)
                .foregroundColor(marker.isImportant ? .red : .orange)
                .frame(width: 16, height: 16)
            
            // 内容
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(marker.eventType.displayName)
                        .font(.caption.bold())
                    
                    if marker.isImportant {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                    
                    Text(formatTime(marker.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(marker.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(marker.isImportant ? Color.red.opacity(0.1) : Color.orange.opacity(0.1))
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

#if DEBUG
struct DataAnnotationView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleAnnotations = [
            DataAnnotation(
                timestamp: Date().addingTimeInterval(-300),
                dataLabel: "CPU",
                type: .maximum,
                value: 85.5,
                description: "CPU温度达到最大值"
            ),
            DataAnnotation(
                timestamp: Date().addingTimeInterval(-600),
                dataLabel: "GPU",
                type: .warning,
                value: 80.0,
                description: "GPU温度超过警告阈值"
            )
        ]
        
        let sampleEvents = [
            EventMarker(
                timestamp: Date().addingTimeInterval(-900),
                eventType: .fanModeChanged,
                description: "风扇模式从自动切换到性能模式",
                isImportant: true
            ),
            EventMarker(
                timestamp: Date().addingTimeInterval(-1200),
                eventType: .systemStarted,
                description: "AuraWind系统启动",
                isImportant: false
            )
        ]
        
        let sampleData = ChartDataPoint.temperatureExamples(count: 20, label: "CPU")
        
        VStack(spacing: 20) {
            DataAnnotationView(
                annotations: sampleAnnotations,
                eventMarkers: sampleEvents,
                dataPoints: sampleData,
                chartType: .temperature
            )
            
            DataAnnotationView(
                annotations: [],
                eventMarkers: [],
                dataPoints: [],
                chartType: .temperature
            )
        }
        .padding()
        .auraBackground()
    }
}
#endif