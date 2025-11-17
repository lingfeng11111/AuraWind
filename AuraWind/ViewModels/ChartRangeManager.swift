//
//  ChartRangeManager.swift
//  AuraWind
//
//  Created by AuraWind Development Team on 2025-11-17.
//

import Foundation
import Combine

/// Y轴范围配置
struct YAxisRange: Codable, Equatable, Hashable {
    var minValue: Double?
    var maxValue: Double?
    var isAutoRange: Bool = true
    var allowZoom: Bool = true
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(minValue)
        hasher.combine(maxValue)
        hasher.combine(isAutoRange)
        hasher.combine(allowZoom)
    }
    
    /// 默认温度范围
    static let defaultTemperatureRange = YAxisRange(
        minValue: 0,
        maxValue: 100,
        isAutoRange: true,
        allowZoom: true
    )
    
    /// 默认风扇转速范围
    static let defaultFanSpeedRange = YAxisRange(
        minValue: 0,
        maxValue: 6000,
        isAutoRange: true,
        allowZoom: true
    )
    
    /// 默认CPU使用率范围
    static let defaultCPUUsageRange = YAxisRange(
        minValue: 0,
        maxValue: 100,
        isAutoRange: true,
        allowZoom: true
    )
    
    /// 验证范围设置
    func validate() -> Bool {
        guard let min = minValue, let max = maxValue else { return true }
        return min < max
    }
    
    /// 获取实际范围值
    func getActualRange(for dataPoints: [ChartDataPoint]) -> (min: Double, max: Double) {
        if isAutoRange {
            // 自动计算范围
            let values = dataPoints.map { $0.value }
            guard !values.isEmpty else { return (0, 100) }
            
            let dataMin = values.min() ?? 0
            let dataMax = values.max() ?? 100
            
            // 添加10%的边距
            let range = dataMax - dataMin
            let padding = range * 0.1
            
            return (max(0, dataMin - padding), dataMax + padding)
        } else {
            // 使用手动设置的范围
            let dataValues = dataPoints.map { $0.value }
            let dataMin = dataValues.min() ?? 0
            let dataMax = dataValues.max() ?? 100
            
            let min = minValue ?? max(0, dataMin)
            let max = maxValue ?? (dataMax + (dataMax * 0.1))
            
            return (min, max)
        }
    }
}

/// 图表范围管理器
/// 管理不同类型图表的Y轴范围设置
@MainActor
class ChartRangeManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 温度图表Y轴范围
    @Published var temperatureRange: YAxisRange = .defaultTemperatureRange
    
    /// 风扇转速图表Y轴范围
    @Published var fanSpeedRange: YAxisRange = .defaultFanSpeedRange
    
    /// CPU使用率图表Y轴范围
    @Published var cpuUsageRange: YAxisRange = .defaultCPUUsageRange
    
    /// GPU使用率图表Y轴范围
    @Published var gpuUsageRange: YAxisRange = .defaultCPUUsageRange
    
    /// 是否显示范围编辑器
    @Published var showRangeEditor: Bool = false
    
    /// 当前编辑的图表类型
    @Published var currentChartType: ChartType = .temperature
    
    // MARK: - Dependencies
    
    private let persistenceService: PersistenceServiceProtocol
    
    // MARK: - Initialization
    
    init(persistenceService: PersistenceServiceProtocol) {
        self.persistenceService = persistenceService
        loadSettings()
    }
    
    // MARK: - Public Methods
    
    /// 获取指定图表类型的范围设置
    /// - Parameter type: 图表类型
    /// - Returns: Y轴范围配置
    func getRange(for type: ChartType) -> YAxisRange {
        switch type {
        case .temperature:
            return temperatureRange
        case .fanSpeed:
            return fanSpeedRange
        case .correlation:
            // 关联图表使用温度范围作为主要参考
            return temperatureRange
        case .performance:
            // 性能图表默认使用CPU范围
            return cpuUsageRange
        }
    }
    
    /// 设置指定图表类型的范围
    /// - Parameters:
    ///   - range: 新的范围设置
    ///   - type: 图表类型
    func setRange(_ range: YAxisRange, for type: ChartType) {
        switch type {
        case .temperature:
            temperatureRange = range
        case .fanSpeed:
            fanSpeedRange = range
        case .correlation:
            temperatureRange = range
        case .performance:
            cpuUsageRange = range
        }
        
        saveSettings()
    }
    
    /// 重置为默认范围
    /// - Parameter type: 图表类型
    func resetToDefault(for type: ChartType) {
        let defaultRange: YAxisRange
        switch type {
        case .temperature, .correlation:
            defaultRange = .defaultTemperatureRange
        case .fanSpeed:
            defaultRange = .defaultFanSpeedRange
        case .performance:
            defaultRange = .defaultCPUUsageRange
        }
        
        setRange(defaultRange, for: type)
    }
    
    /// 切换自动/手动范围模式
    /// - Parameters:
    ///   - isAuto: 是否自动模式
    ///   - type: 图表类型
    func toggleAutoRange(_ isAuto: Bool, for type: ChartType) {
        var range = getRange(for: type)
        range.isAutoRange = isAuto
        setRange(range, for: type)
    }
    
    /// 获取计算后的实际范围值
    /// - Parameters:
    ///   - dataPoints: 数据点
    ///   - type: 图表类型
    /// - Returns: 实际的最小/最大值
    func getActualRange(for dataPoints: [ChartDataPoint], type: ChartType) -> (min: Double, max: Double) {
        let range = getRange(for: type)
        return range.getActualRange(for: dataPoints)
    }
    
    /// 验证当前范围设置
    /// - Parameter type: 图表类型
    /// - Returns: 是否有效
    func validateRange(for type: ChartType) -> Bool {
        let range = getRange(for: type)
        return range.validate()
    }
    
    /// 获取范围预设模板
    /// - Parameter type: 图表类型
    /// - Returns: 预设范围数组
    func getRangePresets(for type: ChartType) -> [YAxisRange] {
        switch type {
        case .temperature:
            return [
                YAxisRange(minValue: 0, maxValue: 50, isAutoRange: false, allowZoom: true),
                YAxisRange(minValue: 0, maxValue: 80, isAutoRange: false, allowZoom: true),
                YAxisRange(minValue: 0, maxValue: 100, isAutoRange: false, allowZoom: true),
                YAxisRange(minValue: 30, maxValue: 70, isAutoRange: false, allowZoom: true)
            ]
        case .fanSpeed:
            return [
                YAxisRange(minValue: 0, maxValue: 2000, isAutoRange: false, allowZoom: true),
                YAxisRange(minValue: 0, maxValue: 4000, isAutoRange: false, allowZoom: true),
                YAxisRange(minValue: 0, maxValue: 6000, isAutoRange: false, allowZoom: true),
                YAxisRange(minValue: 1000, maxValue: 5000, isAutoRange: false, allowZoom: true)
            ]
        case .performance:
            return [
                YAxisRange(minValue: 0, maxValue: 50, isAutoRange: false, allowZoom: true),
                YAxisRange(minValue: 0, maxValue: 80, isAutoRange: false, allowZoom: true),
                YAxisRange(minValue: 0, maxValue: 100, isAutoRange: false, allowZoom: true)
            ]
        case .correlation:
            return getRangePresets(for: .temperature)
        }
    }
    
    // MARK: - Private Methods
    
    /// 加载保存的设置
    private func loadSettings() {
        if let tempRange: YAxisRange = try? persistenceService.load(
            YAxisRange.self,
            forKey: "chartTemperatureRange"
        ) {
            temperatureRange = tempRange
        }
        
        if let fanRange: YAxisRange = try? persistenceService.load(
            YAxisRange.self,
            forKey: "chartFanSpeedRange"
        ) {
            fanSpeedRange = fanRange
        }
        
        if let cpuRange: YAxisRange = try? persistenceService.load(
            YAxisRange.self,
            forKey: "chartCPUUsageRange"
        ) {
            cpuUsageRange = cpuRange
        }
        
        if let gpuRange: YAxisRange = try? persistenceService.load(
            YAxisRange.self,
            forKey: "chartGPUUsageRange"
        ) {
            gpuUsageRange = gpuRange
        }
    }
    
    /// 保存设置
    private func saveSettings() {
        try? persistenceService.save(temperatureRange, forKey: "chartTemperatureRange")
        try? persistenceService.save(fanSpeedRange, forKey: "chartFanSpeedRange")
        try? persistenceService.save(cpuUsageRange, forKey: "chartCPUUsageRange")
        try? persistenceService.save(gpuUsageRange, forKey: "chartGPUUsageRange")
    }
}

// MARK: - Helper Extensions

extension ChartRangeManager {
    /// 获取范围显示文本
    func getRangeDisplayText(for type: ChartType) -> String {
        let range = getRange(for: type)
        
        if range.isAutoRange {
            return "自动范围"
        } else if let min = range.minValue, let max = range.maxValue {
            return String(format: "%.0f - %.0f", min, max)
        } else if let min = range.minValue {
            return String(format: "≥ %.0f", min)
        } else if let max = range.maxValue {
            return String(format: "≤ %.0f", max)
        } else {
            return "自动范围"
        }
    }
    
    /// 检查是否需要显示范围警告
    func shouldShowRangeWarning(for type: ChartType) -> Bool {
        return !validateRange(for: type)
    }
}