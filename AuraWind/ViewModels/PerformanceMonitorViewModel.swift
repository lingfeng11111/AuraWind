//
//  PerformanceMonitorViewModel.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025-11-17.
//

import Foundation
import Combine

/// 性能监控视图模型
@MainActor
final class PerformanceMonitorViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// CPU使用率
    @Published var cpuUsage: Double = 0.0
    
    /// GPU使用率
    @Published var gpuUsage: Double = 0.0
    
    /// 内存使用率
    @Published var memoryUsage: Double = 0.0
    
    /// SMC访问延迟
    @Published var smcLatency: Double = 0.0
    
    /// 缓存命中率
    @Published var cacheHitRate: Double = 0.0
    
    /// 活跃连接数
    @Published var activeConnections: Int = 0
    
    /// 总连接数
    @Published var totalConnections: Int = 0
    
    /// 连接池利用率
    @Published var connectionPoolUtilization: Double = 0.0
    
    /// 连接池状态
    @Published var connectionPoolStatus: String = "正常"
    
    /// SMC访问统计
    @Published var smcStats: [(String, Int)] = []
    
    /// 总错误数
    @Published var totalErrors: Int = 0
    
    /// 权限错误数
    @Published var permissionErrors: Int = 0
    
    /// 连接错误数
    @Published var connectionErrors: Int = 0
    
    /// 读写错误数
    @Published var readWriteErrors: Int = 0
    
    /// 最近1小时访问数
    @Published var recentAccessCount: Int = 0
    
    /// 平均访问间隔
    @Published var averageAccessInterval: Double = 0.0
    
    /// 优化建议
    @Published var optimizationSuggestions: [OptimizationSuggestion] = []
    
    /// macOS版本
    @Published var macosVersion: String = ""
    
    /// 系统架构
    @Published var systemArchitecture: String = ""
    
    /// CPU核心数
    @Published var cpuCores: Int = 0
    
    /// 总内存
    @Published var totalMemory: Double = 0.0
    
    /// SMC连接状态
    @Published var smcConnectionStatus: String = "未连接"
    
    /// 权限状态
    @Published var permissionStatus: String = "未知"
    
    /// 使用真实SMC
    @Published var useRealSMC: Bool = false
    
    /// 是否有Entitlements
    @Published var hasEntitlements: Bool = false
    
    /// 是否已代码签名
    @Published var isCodeSigned: Bool = false
    
    /// 是否有Hardened Runtime
    @Published var hasHardenedRuntime: Bool = false
    
    // MARK: - 监控相关属性
    
    /// 是否正在监控
    @Published var isMonitoring: Bool = false
    
    /// 监控间隔（秒）
    @Published var monitoringInterval: Double = 2.0
    
    /// 选中的时间范围
    @Published var selectedTimeRange: ChartDataPoint.TimeRange = .twentyFourHours
    
    /// 是否显示CPU图表
    @Published var showCPUChart: Bool = true
    
    /// 是否显示GPU图表
    @Published var showGPUChart: Bool = true
    
    /// 是否显示内存图表
    @Published var showMemoryChart: Bool = true
    
    /// 范围管理器
    @Published var rangeManager: ChartRangeManager
    
    /// 是否显示范围编辑器
    @Published var showRangeEditor: Bool = false
    
    // MARK: - 性能数据存储
    
    /// CPU性能数据
    @Published var cpuPerformanceData: [ChartDataPoint] = []
    
    /// GPU性能数据
    @Published var gpuPerformanceData: [ChartDataPoint] = []
    
    /// 内存性能数据
    @Published var memoryPerformanceData: [ChartDataPoint] = []
    
    // MARK: - Private Properties
    
    private var monitoringTimer: Timer?
    private let updateInterval: TimeInterval = 1.0
    
    /// SMC服务
    private let smcService: SMCServiceProtocol
    
    /// 持久化服务
    private let persistenceService: PersistenceServiceProtocol
    
    // MARK: - Initialization
    
    init(
        smcService: SMCServiceProtocol? = nil,
        persistenceService: PersistenceServiceProtocol? = nil
    ) {
        self.smcService = smcService ?? SMCService()
        self.persistenceService = persistenceService ?? PersistenceService()
        self.rangeManager = ChartRangeManager(persistenceService: self.persistenceService)
        loadSystemInfo()
    }
    
    // MARK: - Public Methods
    
    /// 开始监控
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.updateMetrics()
            }
        }
        
        // 立即更新一次
        Task { @MainActor in
            updateMetrics()
        }
    }
    
    /// 停止监控
    func stopMonitoring() {
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    /// 清除历史数据
    func clearHistory() {
        cpuPerformanceData.removeAll()
        gpuPerformanceData.removeAll()
        memoryPerformanceData.removeAll()
    }
    
    /// 导出性能数据
    func exportPerformanceData() async throws -> URL {
        let exportService = ChartExportService()
        let data = getAllPerformanceData()
        return try await exportService.exportChartData(data, format: .csv, filename: "性能数据")
    }
    
    /// 获取性能统计
    func getPerformanceStats() -> PerformanceStats {
        let cpuStats = calculateStats(for: cpuPerformanceData)
        let gpuStats = calculateStats(for: gpuPerformanceData)
        let memoryStats = calculateStats(for: memoryPerformanceData)
        
        return PerformanceStats(
            cpu: cpuStats,
            gpu: gpuStats,
            memory: memoryStats
        )
    }
    
    /// 获取当前性能数据
    func getCurrentPerformanceData() -> (cpuData: [ChartDataPoint], gpuData: [ChartDataPoint], memoryData: [ChartDataPoint]) {
        let timeRange = selectedTimeRange
        let cpuData = cpuPerformanceData.filtered(by: timeRange)
        let gpuData = gpuPerformanceData.filtered(by: timeRange)
        let memoryData = memoryPerformanceData.filtered(by: timeRange)
        
        return (cpuData, gpuData, memoryData)
    }
    
    /// 获取所有性能数据
    func getAllPerformanceData() -> [ChartDataPoint] {
        return cpuPerformanceData + gpuPerformanceData + memoryPerformanceData
    }
    
    /// 当前CPU使用率
    var currentCPUUsage: Double {
        return cpuUsage
    }
    
    /// 当前GPU使用率
    var currentGPUUsage: Double {
        return gpuUsage
    }
    
    /// 当前内存使用率
    var currentMemoryUsage: Double {
        return memoryUsage
    }
    
    // MARK: - Private Methods
    
    /// 更新指标
    private func updateMetrics() {
        updateSystemMetrics()
        Task { @MainActor in
            updateSMCMetrics()
            updateOptimizationSuggestions()
        }
        updatePerformanceData()
    }
    
    /// 更新性能数据
    @MainActor
    private func updatePerformanceData() {
        let now = Date()
        
        // 更新CPU数据
        if showCPUChart {
            let cpuPoint = ChartDataPoint(
                timestamp: now,
                value: cpuUsage,
                label: "CPU使用率",
                type: .cpuUsage
            )
            cpuPerformanceData.append(cpuPoint)
            
            // 限制数据点数量
            if cpuPerformanceData.count > selectedTimeRange.maxDataPoints {
                cpuPerformanceData.removeFirst()
            }
        }
        
        // 更新GPU数据
        if showGPUChart {
            let gpuPoint = ChartDataPoint(
                timestamp: now,
                value: gpuUsage,
                label: "GPU使用率",
                type: .gpuUsage
            )
            gpuPerformanceData.append(gpuPoint)
            
            // 限制数据点数量
            if gpuPerformanceData.count > selectedTimeRange.maxDataPoints {
                gpuPerformanceData.removeFirst()
            }
        }
        
        // 更新内存数据
        if showMemoryChart {
            let memoryPoint = ChartDataPoint(
                timestamp: now,
                value: memoryUsage,
                label: "内存使用率",
                type: .cpuUsage // 使用cpuUsage类型作为内存使用率
            )
            memoryPerformanceData.append(memoryPoint)
            
            // 限制数据点数量
            if memoryPerformanceData.count > selectedTimeRange.maxDataPoints {
                memoryPerformanceData.removeFirst()
            }
        }
    }
    
    /// 计算统计数据
    private func calculateStats(for data: [ChartDataPoint]) -> StatValues {
        let timeRange = selectedTimeRange
        let filteredData = data.filtered(by: timeRange)
        
        guard !filteredData.isEmpty else {
            return StatValues(current: 0, average: 0, maximum: 0, minimum: 0)
        }
        
        let values = filteredData.map { $0.value }
        
        let current = values.last ?? 0
        let average = values.reduce(0, +) / Double(values.count)
        let maximum = values.max() ?? 0
        let minimum = values.min() ?? 0
        
        return StatValues(
            current: current,
            average: average,
            maximum: maximum,
            minimum: minimum
        )
    }
    
    /// 更新系统指标
    @MainActor
    private func updateSystemMetrics() {
        // 更新CPU使用率
        cpuUsage = getCPUUsage()
        
        // 更新内存使用率
        memoryUsage = getMemoryUsage()
        
        // 更新系统信息
        updateSystemInfo()
    }
    
    /// 更新SMC指标
    @MainActor
    private func updateSMCMetrics() {
        // 获取SMC服务实例
        let smcService = SMCService()
        
        // 更新连接状态
        smcConnectionStatus = smcService.isConnected ? "已连接" : "未连接"
        
        // 更新权限状态
        let permissionManager = SMCPermissionManager()
        Task { @MainActor in
            let status = await permissionManager.checkPermissions()
            permissionStatus = status.description
            useRealSMC = status.isAccessible
            
            // 获取性能报告
            let performanceReport = smcService.getPerformanceReport()
            
            smcLatency = performanceReport.averageDuration
            cacheHitRate = performanceReport.cacheHitRate
            connectionPoolUtilization = performanceReport.connectionPoolUtilization
            activeConnections = performanceReport.activeConnections
            totalConnections = Int(Double(performanceReport.activeConnections) / performanceReport.connectionPoolUtilization)
            
            // 更新连接池状态
            if performanceReport.connectionPoolUtilization > 0.8 {
                connectionPoolStatus = "高负载"
            } else if performanceReport.connectionPoolUtilization > 0.5 {
                connectionPoolStatus = "正常"
            } else {
                connectionPoolStatus = "空闲"
            }
            
            // 更新SMC统计
            updateSMCStats()
            
            // 更新错误统计
            updateErrorStats()
        }
    }
    
    /// 更新优化建议
    @MainActor
    private func updateOptimizationSuggestions() {
        // 使用 SMCService 扩展中的优化建议方法
        let smcService = self.smcService as? SMCService
        optimizationSuggestions = smcService?.getOptimizationSuggestions() ?? []
    }
    
    /// 更新系统信息
    private func loadSystemInfo() {
        // 获取macOS版本
        let version = ProcessInfo.processInfo.operatingSystemVersion
        macosVersion = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        
        // 获取系统架构
        #if arch(x86_64)
        systemArchitecture = "x86_64"
        #elseif arch(arm64)
        systemArchitecture = "arm64"
        #else
        systemArchitecture = "未知"
        #endif
        
        // 获取CPU核心数
        cpuCores = ProcessInfo.processInfo.processorCount
        
        // 获取总内存
        totalMemory = Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)
        
        // 检查权限相关状态
        checkPermissionStatus()
    }
    
    /// 检查权限状态
    private func checkPermissionStatus() {
        // 检查entitlements
        hasEntitlements = checkEntitlements()
        
        // 检查代码签名
        isCodeSigned = checkCodeSigning()
        
        // 检查Hardened Runtime
        hasHardenedRuntime = checkHardenedRuntime()
    }
    
    /// 检查entitlements
    private func checkEntitlements() -> Bool {
        guard let appPath = Bundle.main.executablePath else { return false }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        task.arguments = ["-d", "--entitlements", "-", appPath]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return output.contains("com.apple.security.temporary-exception.sbpl")
            }
        } catch {
            print("检查entitlements失败: \(error)")
        }
        
        return false
    }
    
    /// 检查代码签名
    private func checkCodeSigning() -> Bool {
        guard let appPath = Bundle.main.executablePath else { return false }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        task.arguments = ["-v", appPath]
        
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            print("检查代码签名失败: \(error)")
            return false
        }
    }
    
    /// 检查Hardened Runtime
    private func checkHardenedRuntime() -> Bool {
        guard let appPath = Bundle.main.executablePath else { return false }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        task.arguments = ["-d", "--entitlements", "-", appPath]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return output.contains("com.apple.security.cs.allow-jit") ||
                       output.contains("com.apple.security.cs.allow-unsigned-executable-memory")
            }
        } catch {
            print("检查Hardened Runtime失败: \(error)")
        }
        
        return false
    }
    
    /// 更新系统信息
    private func updateSystemInfo() {
        // 这里可以添加动态系统信息更新
    }
    
    /// 更新SMC统计
    private func updateSMCStats() {
        // 模拟SMC统计数据
        smcStats = [
            ("温度读取", 45),
            ("风扇读取", 32),
            ("风扇写入", 8),
            ("连接建立", 5),
            ("连接断开", 3)
        ]
        
        // 更新访问统计
        recentAccessCount = smcStats.reduce(0) { $0 + $1.1 }
        averageAccessInterval = recentAccessCount > 0 ? 3600.0 / Double(recentAccessCount) : 0.0
    }
    
    /// 更新错误统计
    private func updateErrorStats() {
        // 模拟错误统计
        totalErrors = 12
        permissionErrors = 3
        connectionErrors = 5
        readWriteErrors = 4
    }
    
    /// 获取CPU使用率
    private func getCPUUsage() -> Double {
        // 这里应该实现真实的CPU使用率获取
        // 暂时返回模拟数据
        return Double.random(in: 15...45)
    }
    
    /// 获取内存使用率
    private func getMemoryUsage() -> Double {
        // 这里应该实现真实的内存使用率获取
        // 暂时返回模拟数据
        return Double.random(in: 40...70)
    }
}

// MARK: - 统计数据结构

struct PerformanceStats {
    let cpu: StatValues
    let gpu: StatValues
    let memory: StatValues
}

struct StatValues {
    let current: Double
    let average: Double
    let maximum: Double
    let minimum: Double
    
    var formattedCurrent: String {
        return String(format: "%.1f%%", current)
    }
    
    var formattedAverage: String {
        return String(format: "%.1f%%", average)
    }
    
    var formattedMaximum: String {
        return String(format: "%.1f%%", maximum)
    }
    
    var formattedMinimum: String {
        return String(format: "%.1f%%", minimum)
    }
}

// MARK: - SMCService扩展

extension SMCService {
    /// 获取性能报告
    func getPerformanceReport() -> PerformanceReport {
        // 这里应该返回真实的性能报告
        // 暂时返回模拟数据
        return PerformanceReport(
            totalAccesses: 100,
            successfulAccesses: 95,
            averageDuration: 0.005,
            cacheHitRate: 0.75,
            connectionPoolUtilization: 0.6,
            cacheSize: 50,
            activeConnections: 2
        )
    }
    
    /// 获取优化建议
    func getOptimizationSuggestions() -> [OptimizationSuggestion] {
        // 这里应该返回真实的优化建议
        // 暂时返回模拟数据
        return [
            OptimizationSuggestion(
                type: .cache,
                priority: .medium,
                description: "缓存命中率良好，但可以进一步优化缓存策略"
            ),
            OptimizationSuggestion(
                type: .performance,
                priority: .low,
                description: "SMC访问延迟在正常范围内"
            )
        ]
    }
}