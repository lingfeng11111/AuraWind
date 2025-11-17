//
//  DataAnnotation.swift
//  AuraWind
//
//  Created by AuraWind Development Team on 2025-11-17.
//

import Foundation
import Combine

/// 数据标注类型
enum AnnotationType: String, Codable, CaseIterable {
    /// 最大值标注
    case maximum
    /// 最小值标注
    case minimum
    /// 平均值标注
    case average
    /// 警告阈值标注
    case warning
    /// 危险阈值标注
    case danger
    /// 事件标记
    case event
    /// 自定义标注
    case custom
    
    /// 显示名称
    var displayName: String {
        switch self {
        case .maximum:
            return "最大值"
        case .minimum:
            return "最小值"
        case .average:
            return "平均值"
        case .warning:
            return "警告"
        case .danger:
            return "危险"
        case .event:
            return "事件"
        case .custom:
            return "自定义"
        }
    }
    
    /// 图标名称
    var iconName: String {
        switch self {
        case .maximum:
            return "arrow.up.circle.fill"
        case .minimum:
            return "arrow.down.circle.fill"
        case .average:
            return "equal.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .danger:
            return "xmark.octagon.fill"
        case .event:
            return "flag.fill"
        case .custom:
            return "pencil.circle.fill"
        }
    }
    
    /// 颜色
    var color: String {
        switch self {
        case .maximum:
            return "#FF6B6B"  // 红色
        case .minimum:
            return "#4ECDC4"  // 青色
        case .average:
            return "#45B7D1"  // 蓝色
        case .warning:
            return "#FFA726"  // 橙色
        case .danger:
            return "#EF5350"  // 深红色
        case .event:
            return "#AB47BC"  // 紫色
        case .custom:
            return "#66BB6A"  // 绿色
        }
    }
}

/// 数据标注模型
struct DataAnnotation: Identifiable, Codable, Hashable {
    /// 唯一标识符
    let id: UUID
    
    /// 标注时间戳
    let timestamp: Date
    
    /// 关联的数据标签（传感器名称或风扇名称）
    let dataLabel: String
    
    /// 标注类型
    let type: AnnotationType
    
    /// 数值（如果是数值标注）
    let value: Double?
    
    /// 描述文本
    let description: String?
    
    /// 是否显示
    var isVisible: Bool
    
    /// 创建时间
    let createdAt: Date
    
    /// 初始化方法
    init(
        id: UUID = UUID(),
        timestamp: Date,
        dataLabel: String,
        type: AnnotationType,
        value: Double? = nil,
        description: String? = nil,
        isVisible: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.timestamp = timestamp
        self.dataLabel = dataLabel
        self.type = type
        self.value = value
        self.description = description
        self.isVisible = isVisible
        self.createdAt = createdAt
    }
    
    /// 实现Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(timestamp)
        hasher.combine(dataLabel)
        hasher.combine(type)
        hasher.combine(value)
        hasher.combine(description)
        hasher.combine(isVisible)
    }
}

/// 事件类型
enum EventType: String, Codable, CaseIterable {
    /// 风扇模式切换
    case fanModeChanged
    /// 温度警告触发
    case temperatureWarning
    /// 温度警告解除
    case temperatureWarningCleared
    /// 系统启动
    case systemStarted
    /// 系统关闭
    case systemStopped
    /// 手动控制开始
    case manualControlStarted
    /// 手动控制结束
    case manualControlEnded
    /// 曲线应用
    case curveApplied
    /// 异常事件
    case anomalyDetected
    
    /// 显示名称
    var displayName: String {
        switch self {
        case .fanModeChanged:
            return "风扇模式切换"
        case .temperatureWarning:
            return "温度警告"
        case .temperatureWarningCleared:
            return "温度警告解除"
        case .systemStarted:
            return "系统启动"
        case .systemStopped:
            return "系统关闭"
        case .manualControlStarted:
            return "手动控制开始"
        case .manualControlEnded:
            return "手动控制结束"
        case .curveApplied:
            return "曲线应用"
        case .anomalyDetected:
            return "异常检测"
        }
    }
    
    /// 图标名称
    var iconName: String {
        switch self {
        case .fanModeChanged:
            return "wind"
        case .temperatureWarning, .temperatureWarningCleared:
            return "thermometer"
        case .systemStarted, .systemStopped:
            return "power"
        case .manualControlStarted, .manualControlEnded:
            return "hand.raised"
        case .curveApplied:
            return "chart.xyaxis.line"
        case .anomalyDetected:
            return "exclamationmark.triangle"
        }
    }
}

/// 事件标记模型
struct EventMarker: Identifiable, Codable, Hashable {
    /// 唯一标识符
    let id: UUID
    
    /// 事件时间戳
    let timestamp: Date
    
    /// 事件类型
    let eventType: EventType
    
    /// 事件描述
    let description: String
    
    /// 关联的数据（如风扇索引、温度值等）
    let relatedData: [String: String]?
    
    /// 是否重要事件
    let isImportant: Bool
    
    /// 是否显示
    var isVisible: Bool
    
    /// 创建时间
    let createdAt: Date
    
    /// 初始化方法
    init(
        id: UUID = UUID(),
        timestamp: Date,
        eventType: EventType,
        description: String,
        relatedData: [String: String]? = nil,
        isImportant: Bool = false,
        isVisible: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.description = description
        self.relatedData = relatedData
        self.isImportant = isImportant
        self.isVisible = isVisible
        self.createdAt = createdAt
    }
    
    /// 实现Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(timestamp)
        hasher.combine(eventType)
        hasher.combine(description)
        hasher.combine(isImportant)
        hasher.combine(isVisible)
    }
}

/// 数据标注管理器
class DataAnnotationManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 所有标注
    @Published private(set) var annotations: [DataAnnotation] = []
    
    /// 所有事件标记
    @Published private(set) var eventMarkers: [EventMarker] = []
    
    /// 可见的标注
    @Published private(set) var visibleAnnotations: [DataAnnotation] = []
    
    /// 可见的事件标记
    @Published private(set) var visibleEventMarkers: [EventMarker] = []
    
    /// 自动标注功能是否启用
    @Published var isAutoAnnotationEnabled: Bool = true
    
    /// 事件标记功能是否启用
    @Published var isEventMarkingEnabled: Bool = true
    
    // MARK: - Initialization
    
    init() {
        // 初始化时更新可见列表
        updateVisibleAnnotations()
        updateVisibleEventMarkers()
    }
    
    // MARK: - Public Methods
    
    /// 添加数据标注
    func addAnnotation(_ annotation: DataAnnotation) {
        annotations.append(annotation)
        updateVisibleAnnotations()
    }
    
    /// 添加事件标记
    func addEventMarker(_ marker: EventMarker) {
        eventMarkers.append(marker)
        updateVisibleEventMarkers()
    }
    
    /// 自动检测并添加标注
    func autoDetectAnnotations(for dataPoints: [ChartDataPoint], type: ChartDataPoint.DataType) {
        guard isAutoAnnotationEnabled else { return }
        
        // 按标签分组数据
        let groupedData = Dictionary(grouping: dataPoints) { $0.label }
        
        for (label, points) in groupedData {
            guard !points.isEmpty else { continue }
            
            let values = points.map { $0.value }
            
            // 检测最大值
            if let maxValue = values.max(),
               let maxPoint = points.first(where: { $0.value == maxValue }) {
                let annotation = DataAnnotation(
                    timestamp: maxPoint.timestamp,
                    dataLabel: label,
                    type: .maximum,
                    value: maxValue,
                    description: "\(label) 达到最大值 \(String(format: "%.1f", maxValue))\(type.unit)"
                )
                addAnnotation(annotation)
            }
            
            // 检测最小值
            if let minValue = values.min(),
               let minPoint = points.first(where: { $0.value == minValue }) {
                let annotation = DataAnnotation(
                    timestamp: minPoint.timestamp,
                    dataLabel: label,
                    type: .minimum,
                    value: minValue,
                    description: "\(label) 达到最小值 \(String(format: "%.1f", minValue))\(type.unit)"
                )
                addAnnotation(annotation)
            }
            
            // 检测平均值
            let average = values.reduce(0, +) / Double(values.count)
            let annotation = DataAnnotation(
                timestamp: Date(), // 使用当前时间
                dataLabel: label,
                type: .average,
                value: average,
                description: "\(label) 平均值 \(String(format: "%.1f", average))\(type.unit)"
            )
            addAnnotation(annotation)
        }
    }
    
    /// 获取指定时间范围内的标注
    func getAnnotations(in timeRange: ChartDataPoint.TimeRange) -> [DataAnnotation] {
        let cutoffDate = Date().addingTimeInterval(-timeRange.interval)
        return visibleAnnotations.filter { $0.timestamp >= cutoffDate }
    }
    
    /// 获取指定时间范围内的事件标记
    func getEventMarkers(in timeRange: ChartDataPoint.TimeRange) -> [EventMarker] {
        let cutoffDate = Date().addingTimeInterval(-timeRange.interval)
        return visibleEventMarkers.filter { $0.timestamp >= cutoffDate }
    }
    
    /// 切换标注可见性
    func toggleAnnotationVisibility(_ annotation: DataAnnotation) {
        if let index = annotations.firstIndex(where: { $0.id == annotation.id }) {
            annotations[index].isVisible.toggle()
            updateVisibleAnnotations()
        }
    }
    
    /// 切换事件标记可见性
    func toggleEventMarkerVisibility(_ marker: EventMarker) {
        if let index = eventMarkers.firstIndex(where: { $0.id == marker.id }) {
            eventMarkers[index].isVisible.toggle()
            updateVisibleEventMarkers()
        }
    }
    
    /// 清除所有标注
    func clearAllAnnotations() {
        annotations.removeAll()
        visibleAnnotations.removeAll()
    }
    
    /// 清除所有事件标记
    func clearAllEventMarkers() {
        eventMarkers.removeAll()
        visibleEventMarkers.removeAll()
    }
    
    /// 清除指定时间范围内的标注
    func clearAnnotations(in timeRange: ChartDataPoint.TimeRange) {
        let cutoffDate = Date().addingTimeInterval(-timeRange.interval)
        annotations.removeAll { $0.timestamp < cutoffDate }
        updateVisibleAnnotations()
    }
    
    // MARK: - Private Methods
    
    private func updateVisibleAnnotations() {
        visibleAnnotations = annotations.filter { $0.isVisible }
    }
    
    private func updateVisibleEventMarkers() {
        visibleEventMarkers = eventMarkers.filter { $0.isVisible }
    }
}

// MARK: - Helper Extensions

extension DataAnnotationManager {
    /// 添加风扇模式切换事件
    func addFanModeChangeEvent(from oldMode: String, to newMode: String) {
        let marker = EventMarker(
            timestamp: Date(),
            eventType: .fanModeChanged,
            description: "风扇模式从 \(oldMode) 切换到 \(newMode)",
            relatedData: ["oldMode": oldMode, "newMode": newMode],
            isImportant: true
        )
        addEventMarker(marker)
    }
    
    /// 添加温度警告事件
    func addTemperatureWarningEvent(sensor: String, temperature: Double) {
        let marker = EventMarker(
            timestamp: Date(),
            eventType: .temperatureWarning,
            description: "\(sensor) 温度过高: \(String(format: "%.1f", temperature))°C",
            relatedData: ["sensor": sensor, "temperature": String(temperature)],
            isImportant: true
        )
        addEventMarker(marker)
    }
    
    /// 添加温度警告解除事件
    func addTemperatureWarningClearedEvent(sensor: String, temperature: Double) {
        let marker = EventMarker(
            timestamp: Date(),
            eventType: .temperatureWarningCleared,
            description: "\(sensor) 温度恢复正常: \(String(format: "%.1f", temperature))°C",
            relatedData: ["sensor": sensor, "temperature": String(temperature)],
            isImportant: false
        )
        addEventMarker(marker)
    }
}