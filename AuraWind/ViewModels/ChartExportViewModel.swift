//
//  ChartExportViewModel.swift
//  AuraWind
//
//  Created by AuraWind Development Team on 2025-11-17.
//

import Foundation
import SwiftUI
import Combine

/// 图表导出视图模型
/// 管理图表导出功能和用户交互
@MainActor
final class ChartExportViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 是否正在导出
    @Published private(set) var isExporting: Bool = false
    
    /// 导出进度 (0.0 - 1.0)
    @Published private(set) var exportProgress: Double = 0.0
    
    /// 最后导出的文件URL
    @Published private(set) var lastExportedFile: URL?
    
    /// 导出错误
    @Published private(set) var exportError: ChartExportError?
    
    /// 选中的导出格式
    @Published var selectedFormat: ChartExportFormat = .png
    
    /// 是否显示导出设置
    @Published var showExportSettings: Bool = false
    
    /// 导出文件名
    @Published var exportFilename: String = "AuraWind_Chart"
    
    /// 是否包含图例
    @Published var includeLegend: Bool = true
    
    /// 是否包含网格
    @Published var includeGrid: Bool = true
    
    /// 图像宽度（PNG/SVG）
    @Published var imageWidth: Double = 1200
    
    /// 图像高度（PNG/SVG）
    @Published var imageHeight: Double = 600
    
    // MARK: - Dependencies
    
    private let exportService: ChartExportService
    private let persistenceService: PersistenceServiceProtocol
    
    // MARK: - Private Properties
    
    private var exportTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(
        exportService: ChartExportService? = nil,
        persistenceService: PersistenceServiceProtocol
    ) {
        self.exportService = exportService ?? ChartExportService()
        self.persistenceService = persistenceService
        loadSettings()
    }
    
    deinit {
        exportTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// 导出单个图表
    /// - Parameter dataPoints: 图表数据点
    func exportChart(_ dataPoints: [ChartDataPoint]) {
        guard !isExporting else { return }
        
        exportTask = Task { @MainActor in
            await performExport(dataPoints: dataPoints)
        }
    }
    
    /// 批量导出多个图表
    /// - Parameter dataGroups: 数据组 [(名称, 数据点)]
    func exportMultipleCharts(_ dataGroups: [(String, [ChartDataPoint])]) {
        guard !isExporting else { return }
        
        exportTask = Task {
            await performBatchExport(dataGroups: dataGroups)
        }
    }
    
    /// 导出温度图表
    /// - Parameters:
    ///   - temperatureData: 温度数据
    ///   - timeRange: 时间范围
    func exportTemperatureChart(
        _ temperatureData: [ChartDataPoint],
        timeRange: ChartDataPoint.TimeRange
    ) {
        let filename = "Temperature_\(timeRange.rawValue)_\(getCurrentTimestamp())"
        exportFilename = filename
        exportChart(temperatureData)
    }
    
    /// 导出风扇转速图表
    /// - Parameters:
    ///   - fanSpeedData: 风扇转速数据
    ///   - timeRange: 时间范围
    func exportFanSpeedChart(
        _ fanSpeedData: [ChartDataPoint],
        timeRange: ChartDataPoint.TimeRange
    ) {
        let filename = "FanSpeed_\(timeRange.rawValue)_\(getCurrentTimestamp())"
        exportFilename = filename
        exportChart(fanSpeedData)
    }
    
    /// 导出关联图表
    /// - Parameters:
    ///   - temperatureData: 温度数据
    ///   - fanSpeedData: 风扇转速数据
    ///   - timeRange: 时间范围
    func exportCorrelationChart(
        temperatureData: [ChartDataPoint],
        fanSpeedData: [ChartDataPoint],
        timeRange: ChartDataPoint.TimeRange
    ) {
        let filename = "Correlation_\(timeRange.rawValue)_\(getCurrentTimestamp())"
        exportFilename = filename
        
        // 合并数据用于导出
        let combinedData = temperatureData + fanSpeedData
        exportChart(combinedData)
    }
    
    /// 打开最后导出的文件
    func openLastExportedFile() {
        guard let fileURL = lastExportedFile else { return }
        
        // 使用系统默认应用打开文件
        NSWorkspace.shared.open(fileURL)
    }
    
    /// 在Finder中显示最后导出的文件
    func revealLastExportedFile() {
        guard let fileURL = lastExportedFile else { return }
        
        // 在Finder中显示文件
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }
    
    /// 清除导出错误
    func clearError() {
        exportError = nil
    }
    
    /// 重置导出设置
    func resetSettings() {
        selectedFormat = .png
        exportFilename = "AuraWind_Chart"
        includeLegend = true
        includeGrid = true
        imageWidth = 1200
        imageHeight = 600
    }
    
    // MARK: - Private Methods
    
    /// 执行导出操作
    private func performExport(dataPoints: [ChartDataPoint]) async {
        guard !dataPoints.isEmpty else {
            exportError = .invalidData
            return
        }
        
        isExporting = true
        exportProgress = 0.0
        exportError = nil
        
        do {
            // 模拟导出进度
            try await simulateProgress()
            
            // 执行导出
            let fileURL = try await exportService.exportChartData(
                dataPoints,
                format: selectedFormat,
                filename: exportFilename
            )
            
            // 更新状态
            lastExportedFile = fileURL
            exportProgress = 1.0
            
            // 保存设置
            saveSettings()
            
        } catch let error as ChartExportError {
            exportError = error
        } catch {
            exportError = .fileWriteFailed
        }
        
        isExporting = false
        
        // 延迟后重置进度
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        exportProgress = 0.0
    }
    
    /// 执行批量导出
    private func performBatchExport(dataGroups: [(String, [ChartDataPoint])]) async {
        guard !dataGroups.isEmpty else {
            exportError = .invalidData
            return
        }
        
        isExporting = true
        exportProgress = 0.0
        exportError = nil
        
        do {
            let totalGroups = dataGroups.count
            
            for (index, (groupName, dataPoints)) in dataGroups.enumerated() {
                guard !dataPoints.isEmpty else { continue }
                
                // 更新进度
                exportProgress = Double(index) / Double(totalGroups)
                
                // 导出当前组
                let filename = "\(exportFilename)_\(groupName)"
                _ = try await exportService.exportChartData(
                    dataPoints,
                    format: selectedFormat,
                    filename: filename
                )
                
                // 检查任务是否被取消
                if Task.isCancelled { break }
            }
            
            exportProgress = 1.0
            
        } catch let error as ChartExportError {
            exportError = error
        } catch {
            exportError = .fileWriteFailed
        }
        
        isExporting = false
        
        // 延迟后重置进度
        try? await Task.sleep(nanoseconds: 500_000_000)
        exportProgress = 0.0
    }
    
    /// 模拟导出进度
    private func simulateProgress() async throws {
        let steps = 10
        for step in 0...steps {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            exportProgress = Double(step) / Double(steps)
        }
    }
    
    /// 获取当前时间戳
    private func getCurrentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
    
    /// 加载设置
    private func loadSettings() {
        if let formatRaw: String = try? persistenceService.load(String.self, forKey: "chartExportFormat"),
           let format = ChartExportFormat(rawValue: formatRaw) {
            selectedFormat = format
        }
        
        if let filename: String = try? persistenceService.load(String.self, forKey: "chartExportFilename") {
            exportFilename = filename
        }
        
        if let includeLegend: Bool = try? persistenceService.load(Bool.self, forKey: "chartExportIncludeLegend") {
            self.includeLegend = includeLegend
        }
        
        if let includeGrid: Bool = try? persistenceService.load(Bool.self, forKey: "chartExportIncludeGrid") {
            self.includeGrid = includeGrid
        }
        
        if let width: Double = try? persistenceService.load(Double.self, forKey: "chartExportImageWidth") {
            imageWidth = width
        }
        
        if let height: Double = try? persistenceService.load(Double.self, forKey: "chartExportImageHeight") {
            imageHeight = height
        }
    }
    
    /// 保存设置
    private func saveSettings() {
        try? persistenceService.save(selectedFormat.rawValue, forKey: "chartExportFormat")
        try? persistenceService.save(exportFilename, forKey: "chartExportFilename")
        try? persistenceService.save(includeLegend, forKey: "chartExportIncludeLegend")
        try? persistenceService.save(includeGrid, forKey: "chartExportIncludeGrid")
        try? persistenceService.save(imageWidth, forKey: "chartExportImageWidth")
        try? persistenceService.save(imageHeight, forKey: "chartExportImageHeight")
    }
}

// MARK: - Helper Extensions

extension ChartExportViewModel {
    /// 获取导出格式的显示名称
    func getFormatDisplayName(_ format: ChartExportFormat) -> String {
        return format.description
    }
    
    /// 检查是否可以导出
    var canExport: Bool {
        return !isExporting && !exportFilename.isEmpty
    }
    
    /// 获取导出进度百分比
    var exportProgressPercentage: Int {
        return Int(exportProgress * 100)
    }
    
    /// 是否显示进度指示器
    var shouldShowProgress: Bool {
        return isExporting && exportProgress > 0
    }
}