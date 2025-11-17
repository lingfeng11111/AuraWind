//
//  ChartDataPoint.swift
//  AuraWind
//
//  Created by AuraWind Development Team on 2025-11-17.
//

import Foundation

/// 图表数据点模型
/// 用于温度和转速图表的数据可视化
struct ChartDataPoint: Identifiable, Codable {
    /// 唯一标识符
    let id: UUID
    
    /// 时间戳
    let timestamp: Date
    
    /// 数值（温度或转速）
    let value: Double
    
    /// 数据标签（传感器名称或风扇名称）
    let label: String
    
    /// 数据类型
    let type: DataType
    
    /// 初始化方法
    /// - Parameters:
    ///   - timestamp: 时间戳
    ///   - value: 数值
    ///   - label: 数据标签
    ///   - type: 数据类型
    init(
        timestamp: Date = Date(),
        value: Double,
        label: String,
        type: DataType
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.value = value
        self.label = label
        self.type = type
    }
    
    // MARK: - 数据类型枚举
    
    /// 图表数据类型
    enum DataType: String, Codable {
        /// 温度数据（摄氏度）
        case temperature
        /// 风扇转速（RPM）
        case fanSpeed
        /// CPU使用率（百分比）
        case cpuUsage
        /// GPU使用率（百分比）
        case gpuUsage
        
        /// 单位符号
        var unit: String {
            switch self {
            case .temperature:
                return "°C"
            case .fanSpeed:
                return "RPM"
            case .cpuUsage, .gpuUsage:
                return "%"
            }
        }
        
        /// 格式化数值
        /// - Parameter value: 原始数值
        /// - Returns: 格式化后的字符串
        func formatted(_ value: Double) -> String {
            switch self {
            case .temperature:
                return String(format: "%.1f%@", value, unit)
            case .fanSpeed:
                return String(format: "%.0f %@", value, unit)
            case .cpuUsage, .gpuUsage:
                return String(format: "%.1f%@", value, unit)
            }
        }
    }
}

// MARK: - Equatable

extension ChartDataPoint: Equatable {
    static func == (lhs: ChartDataPoint, rhs: ChartDataPoint) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Hashable

extension ChartDataPoint: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - 时间范围扩展

extension ChartDataPoint {
    /// 时间范围枚举
    enum TimeRange: String, CaseIterable, Identifiable, Hashable {
        case oneHour = "1小时"
        case sixHours = "6小时"
        case twelveHours = "12小时"
        case twentyFourHours = "24小时"
        case sevenDays = "7天"
        
        var id: String { self.rawValue }
        
        /// 时间间隔（秒）
        var interval: TimeInterval {
            switch self {
            case .oneHour:
                return 3600
            case .sixHours:
                return 3600 * 6
            case .twelveHours:
                return 3600 * 12
            case .twentyFourHours:
                return 3600 * 24
            case .sevenDays:
                return 3600 * 24 * 7
            }
        }
        
        /// 推荐的数据点间隔（秒）
        var recommendedInterval: TimeInterval {
            switch self {
            case .oneHour:
                return 2  // 每2秒一个点
            case .sixHours:
                return 10  // 每10秒一个点
            case .twelveHours:
                return 20  // 每20秒一个点
            case .twentyFourHours:
                return 30  // 每30秒一个点
            case .sevenDays:
                return 300  // 每5分钟一个点
            }
        }
        
        /// 最大数据点数量
        var maxDataPoints: Int {
            Int(interval / recommendedInterval)
        }
    }
    
    /// 判断数据点是否在指定时间范围内
    /// - Parameter range: 时间范围
    /// - Returns: 是否在范围内
    func isWithin(_ range: TimeRange) -> Bool {
        let cutoffDate = Date().addingTimeInterval(-range.interval)
        return timestamp >= cutoffDate
    }
}

// MARK: - 数组扩展

extension Array where Element == ChartDataPoint {
    /// 过滤指定时间范围内的数据点
    /// - Parameter range: 时间范围
    /// - Returns: 过滤后的数据点数组
    func filtered(by range: ChartDataPoint.TimeRange) -> [ChartDataPoint] {
        filter { $0.isWithin(range) }
    }
    
    /// 过滤指定标签的数据点
    /// - Parameter label: 标签
    /// - Returns: 过滤后的数据点数组
    func filtered(by label: String) -> [ChartDataPoint] {
        filter { $0.label == label }
    }
    
    /// 过滤指定数据类型的数据点
    /// - Parameter type: 数据类型
    /// - Returns: 过滤后的数据点数组
    func filtered(by type: ChartDataPoint.DataType) -> [ChartDataPoint] {
        filter { $0.type == type }
    }
    
    /// 获取所有唯一的标签
    var uniqueLabels: [String] {
        let labelSet = Set<String>(self.map { $0.label })
        return Array<String>(labelSet).sorted()
    }
    
    /// 获取指定标签的最新数据点
    /// - Parameter label: 标签
    /// - Returns: 最新数据点
    func latest(for label: String) -> ChartDataPoint? {
        let filtered = self.filtered(by: label)
        guard !filtered.isEmpty else { return nil }
        return filtered.max { $0.timestamp < $1.timestamp }
    }
    
    /// 获取指定标签在时间范围内的平均值
    /// - Parameters:
    ///   - label: 标签
    ///   - range: 时间范围
    /// - Returns: 平均值
    func average(for label: String, in range: ChartDataPoint.TimeRange) -> Double? {
        let points = self.filtered(by: label).filtered(by: range)
        guard !points.isEmpty else { return nil }
        let values = points.map { $0.value }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
    
    /// 获取指定标签在时间范围内的最大值
    /// - Parameters:
    ///   - label: 标签
    ///   - range: 时间范围
    /// - Returns: 最大值
    func maximum(for label: String, in range: ChartDataPoint.TimeRange) -> Double? {
        let points = self.filtered(by: label).filtered(by: range)
        guard !points.isEmpty else { return nil }
        let values = points.map { $0.value }
        guard !values.isEmpty else { return nil }
        return values.max()
    }
    
    /// 获取指定标签在时间范围内的最小值
    /// - Parameters:
    ///   - label: 标签
    ///   - range: 时间范围
    /// - Returns: 最小值
    func minimum(for label: String, in range: ChartDataPoint.TimeRange) -> Double? {
        let points = self.filtered(by: label).filtered(by: range)
        guard !points.isEmpty else { return nil }
        let values = points.map { $0.value }
        guard !values.isEmpty else { return nil }
        return values.min()
    }
}

// MARK: - 示例数据

#if DEBUG
extension ChartDataPoint {
    /// 生成示例温度数据点
    static func temperatureExamples(
        count: Int = 30,
        label: String = "CPU"
    ) -> [ChartDataPoint] {
        let now = Date()
        return (0..<count).map { index in
            let timestamp = now.addingTimeInterval(-Double(count - index) * 2)
            let baseTemp = 45.0
            let variation = Double.random(in: -5...15)
            return ChartDataPoint(
                timestamp: timestamp,
                value: baseTemp + variation,
                label: label,
                type: .temperature
            )
        }
    }
    
    /// 生成示例风扇转速数据点
    static func fanSpeedExamples(
        count: Int = 30,
        label: String = "风扇1"
    ) -> [ChartDataPoint] {
        let now = Date()
        return (0..<count).map { index in
            let timestamp = now.addingTimeInterval(-Double(count - index) * 2)
            let baseSpeed = 2000.0
            let variation = Double.random(in: -200...500)
            return ChartDataPoint(
                timestamp: timestamp,
                value: baseSpeed + variation,
                label: label,
                type: .fanSpeed
            )
        }
    }
}
#endif