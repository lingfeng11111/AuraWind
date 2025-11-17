//
//  TemperatureMonitorViewModel.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025-11-16.
//  Updated: 2025-11-17 - Added ChartDataPoint support
//

import Foundation
import Combine

/// 温度监控视图模型
/// 负责实时监控温度、收集历史数据和生成图表数据
@MainActor
final class TemperatureMonitorViewModel: BaseViewModel {
    
    // MARK: - Published Properties
    
    /// 温度传感器列表
    @Published private(set) var sensors: [TemperatureSensor] = []
    
    /// 是否正在监控
    @Published private(set) var isMonitoring: Bool = false
    
    /// 温度警告阈值(°C)
    @Published var warningThreshold: Double = 85.0
    
    /// 是否显示警告
    @Published private(set) var hasWarning: Bool = false
    
    /// 历史数据保留时长(秒)
    @Published var historyDuration: TimeInterval = 3600 // 默认1小时
    
    // MARK: - Chart Data Properties
    
    /// 图表数据点集合
    @Published private(set) var chartData: [ChartDataPoint] = []
    
    /// 当前选中的时间范围
    @Published var selectedTimeRange: ChartDataPoint.TimeRange = .oneHour
    
    /// 选中的传感器标签（用于图表过滤）
    @Published var selectedSensorLabels: Set<String> = []
    
    /// 数据标注管理器
    @Published private(set) var annotationManager: DataAnnotationManager
    
    // MARK: - Dependencies
    
    private let smcService: SMCServiceProtocol
    private let persistenceService: PersistenceServiceProtocol
    
    // MARK: - Private Properties
    
    /// 监控任务
    private var monitoringTask: Task<Void, Never>?
    
    /// 更新间隔(秒)
    private let updateInterval: TimeInterval = 2.0
    
    /// 最大历史记录数
    private let maxHistoryCount: Int = 1800 // 1小时 * 3600秒 / 2秒
    
    /// 最大图表数据点数
    private let maxChartDataPoints: Int = 3000 // 支持更长时间的数据展示
    
    // MARK: - Initialization
    
    init(
        smcService: SMCServiceProtocol,
        persistenceService: PersistenceServiceProtocol,
        annotationManager: DataAnnotationManager? = nil
    ) {
        self.smcService = smcService
        self.persistenceService = persistenceService
        self.annotationManager = annotationManager ?? DataAnnotationManager()
        super.init()
        
        setupBindings()
        loadSettings()
    }
    
    // deinit自动取消Task,无需手动处理
    
    // MARK: - Public Methods
    
    /// 开始监控
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        monitoringTask = Task {
            await monitorTemperature()
        }
    }
    
    /// 停止监控
    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
        isMonitoring = false
    }
    
    /// 初始化传感器
    func initializeSensors() async {
        await performAsyncOperation {
            // 连接SMC
            try await self.smcService.connect()
            
            // 获取所有温度传感器
            let allSensors = try await self.smcService.getAllTemperatures()
            self.sensors = allSensors
        }
    }
    
    /// 刷新温度数据
    func refreshTemperature() async {
        await performAsyncOperation {
            for (index, sensor) in self.sensors.enumerated() {
                let sensorType = TemperatureSensorType(
                    rawValue: sensor.type.rawValue
                ) ?? .cpuProximity
                
                let temp = try await self.smcService.readTemperature(sensor: sensorType)
                
                // 更新传感器温度
                self.sensors[index].currentTemperature = temp
                
                // 添加历史记录
                let reading = TemperatureReading(
                    timestamp: Date(),
                    value: temp
                )
                self.sensors[index].addReading(reading)
                
                // 添加到图表数据
                let chartPoint = ChartDataPoint(
                    timestamp: reading.timestamp,
                    value: temp,
                    label: sensor.name,
                    type: .temperature
                )
                self.addChartDataPoint(chartPoint)
                
                // 限制历史记录数量
                self.limitHistorySize(sensorIndex: index)
            }
            
            // 检查是否需要显示警告
            self.checkTemperatureWarning()
            
            // 自动检测数据标注
            self.autoDetectAnnotations()
        }
    }
    
    /// 获取指定时长的历史数据
    /// - Parameter duration: 时长(秒)
    /// - Returns: 历史温度读数
    func getHistoricalData(duration: TimeInterval) -> [TemperatureSensor] {
        let cutoffDate = Date().addingTimeInterval(-duration)
        
        return sensors.map { sensor in
            var filteredSensor = sensor
            filteredSensor.readings = sensor.readings.filter { reading in
                reading.timestamp >= cutoffDate
            }
            return filteredSensor
        }
    }
    
    /// 获取指定传感器的历史数据
    /// - Parameters:
    ///   - sensorType: 传感器类型
    ///   - duration: 时长(秒)
    /// - Returns: 温度读数数组
    func getSensorHistory(
        type sensorType: TemperatureSensor.SensorType,
        duration: TimeInterval
    ) -> [TemperatureReading] {
        guard let sensor = sensors.first(where: { $0.type == sensorType }) else {
            return []
        }
        
        let cutoffDate = Date().addingTimeInterval(-duration)
        return sensor.readings.filter { $0.timestamp >= cutoffDate }
    }
    
    /// 导出温度数据为CSV
    /// - Returns: CSV文件URL
    func exportData() async throws -> URL {
        let csv = generateCSV()
        
        // 创建临时文件
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "AuraWind_Temperature_\(Date().ISO8601Format()).csv"
        let fileURL = tempDir.appendingPathComponent(filename)
        
        // 写入文件
        try csv.write(to: fileURL, atomically: true, encoding: .utf8)
        
        return fileURL
    }
    
    /// 清除历史数据
    func clearHistory() {
        for index in sensors.indices {
            sensors[index].readings = []
        }
    }
    
    /// 获取平均温度
    /// - Parameter duration: 时长(秒)
    /// - Returns: 平均温度(°C)
    func getAverageTemperature(duration: TimeInterval = 60) -> Double {
        let historicalData = getHistoricalData(duration: duration)
        guard !historicalData.isEmpty else { return 0 }
        
        let allTemps = historicalData.flatMap { sensor in
            sensor.readings.map { $0.value }
        }
        
        guard !allTemps.isEmpty else { return 0 }
        
        return allTemps.reduce(0, +) / Double(allTemps.count)
    }
    
    /// 获取最高温度
    /// - Returns: 最高温度(°C)
    func getMaxTemperature() -> Double {
        guard !sensors.isEmpty else { return 0 }
        let temps = sensors.map { $0.currentTemperature }
        guard !temps.isEmpty else { return 0 }
        return temps.max() ?? 0
    }
    
    /// 获取最低温度
    /// - Returns: 最低温度(°C)
    func getMinTemperature() -> Double {
        guard !sensors.isEmpty else { return 0 }
        let temps = sensors.map { $0.currentTemperature }
        guard !temps.isEmpty else { return 0 }
        return temps.min() ?? 0
    }
    
    // MARK: - Chart Data Methods
    
    /// 获取指定时间范围的图表数据
    /// - Parameter range: 时间范围
    /// - Returns: 过滤后的图表数据点
    func getChartData(for range: ChartDataPoint.TimeRange) -> [ChartDataPoint] {
        chartData.filtered(by: range)
    }
    
    /// 获取指定传感器的图表数据
    /// - Parameters:
    ///   - sensorLabels: 传感器标签集合
    ///   - range: 时间范围
    /// - Returns: 过滤后的图表数据点
    func getChartData(
        for sensorLabels: Set<String>,
        in range: ChartDataPoint.TimeRange
    ) -> [ChartDataPoint] {
        let rangeFiltered = chartData.filtered(by: range)
        if sensorLabels.isEmpty {
            return rangeFiltered
        }
        return rangeFiltered.filter { sensorLabels.contains($0.label) }
    }
    
    /// 获取当前选中范围的图表数据
    /// - Returns: 图表数据点数组
    func getCurrentChartData() -> [ChartDataPoint] {
        getChartData(for: selectedSensorLabels, in: selectedTimeRange)
    }
    
    /// 获取所有可用的传感器标签
    /// - Returns: 传感器标签数组
    func getAvailableSensorLabels() -> [String] {
        chartData.uniqueLabels
    }
    
    /// 切换传感器选择状态
    /// - Parameter label: 传感器标签
    func toggleSensorSelection(_ label: String) {
        if selectedSensorLabels.contains(label) {
            selectedSensorLabels.remove(label)
        } else {
            selectedSensorLabels.insert(label)
        }
    }
    
    /// 选择所有传感器
    func selectAllSensors() {
        selectedSensorLabels = Set(getAvailableSensorLabels())
    }
    
    /// 取消选择所有传感器
    func deselectAllSensors() {
        selectedSensorLabels.removeAll()
    }
    
    /// 获取指定标签的统计信息
    /// - Parameters:
    ///   - label: 传感器标签
    ///   - range: 时间范围
    /// - Returns: (平均值, 最大值, 最小值)
    func getStatistics(
        for label: String,
        in range: ChartDataPoint.TimeRange
    ) -> (average: Double?, max: Double?, min: Double?) {
        let average = chartData.average(for: label, in: range)
        let max = chartData.maximum(for: label, in: range)
        let min = chartData.minimum(for: label, in: range)
        return (average, max, min)
    }
    
    // MARK: - Private Methods
    
    /// 设置数据绑定
    override func setupBindings() {
        super.setupBindings()
        
        // 监控警告阈值变化
        $warningThreshold
            .sink { [weak self] threshold in
                self?.saveSettings()
                self?.checkTemperatureWarning()
            }
            .store(in: &cancellables)
        
        // 监控历史保留时长变化
        $historyDuration
            .sink { [weak self] _ in
                self?.saveSettings()
            }
            .store(in: &cancellables)
        
        // 监控时间范围变化
        $selectedTimeRange
            .sink { [weak self] _ in
                self?.saveSettings()
            }
            .store(in: &cancellables)
    }
    
    /// 加载设置
    private func loadSettings() {
        if let threshold: Double = try? persistenceService.load(
            Double.self,
            forKey: "temperatureWarningThreshold"
        ) {
            warningThreshold = threshold
        }
        
        if let duration: TimeInterval = try? persistenceService.load(
            TimeInterval.self,
            forKey: "temperatureHistoryDuration"
        ) {
            historyDuration = duration
        }
        
        if let rangeRaw: String = try? persistenceService.load(
            String.self,
            forKey: "selectedTimeRange"
        ), let range = ChartDataPoint.TimeRange(rawValue: rangeRaw) {
            selectedTimeRange = range
        }
    }
    
    /// 保存设置
    private func saveSettings() {
        try? persistenceService.save(warningThreshold, forKey: "temperatureWarningThreshold")
        try? persistenceService.save(historyDuration, forKey: "temperatureHistoryDuration")
        try? persistenceService.save(selectedTimeRange.rawValue, forKey: "selectedTimeRange")
    }
    
    /// 添加图表数据点
    private func addChartDataPoint(_ point: ChartDataPoint) {
        chartData.append(point)
        
        // 限制图表数据点数量
        if chartData.count > maxChartDataPoints {
            let data = chartData
            chartData = Array(data.suffix(maxChartDataPoints))
        }
    }
    
    /// 监控温度
    private func monitorTemperature() async {
        while !Task.isCancelled && isMonitoring {
            await refreshTemperature()
            
            // 等待下次更新
            try? await Task.sleep(nanoseconds: UInt64(updateInterval * 1_000_000_000))
        }
    }
    
    /// 限制历史数据大小
    private func limitHistorySize(sensorIndex: Int) {
        guard sensorIndex < sensors.count else { return }
        
        if sensors[sensorIndex].readings.count > maxHistoryCount {
            // 保留最新的记录
            let readings = sensors[sensorIndex].readings
            sensors[sensorIndex].readings = Array(readings.suffix(maxHistoryCount))
        }
    }
    
    /// 检查温度警告
    private func checkTemperatureWarning() {
        let maxTemp = getMaxTemperature()
        hasWarning = maxTemp > warningThreshold
        
        if hasWarning {
            // 触发通知(如果需要)
            notifyHighTemperature(temperature: maxTemp)
        }
    }
    
    /// 发送高温通知
    private func notifyHighTemperature(temperature: Double) {
        // 这里可以集成系统通知
        print("⚠️ 警告: 温度过高 \(String(format: "%.1f", temperature))°C")
    }
    
    /// 生成CSV数据
    private func generateCSV() -> String {
        var csv = "Timestamp,Sensor,Temperature(°C)\n"
        
        for sensor in sensors {
            for reading in sensor.readings {
                let timestamp = reading.timestamp.ISO8601Format()
                let sensorName = sensor.name
                let temp = String(format: "%.2f", reading.value)
                csv += "\(timestamp),\(sensorName),\(temp)\n"
            }
        }
        
        return csv
    }
    
    // MARK: - Data Annotation Methods
    
    /// 自动检测数据标注
    private func autoDetectAnnotations() {
        let currentData = getCurrentChartData()
        guard !currentData.isEmpty else { return }
        
        annotationManager.autoDetectAnnotations(for: currentData, type: .temperature)
    }
    
    /// 获取当前可见的标注
    func getVisibleAnnotations() -> [DataAnnotation] {
        return annotationManager.visibleAnnotations
    }
    
    /// 添加自定义标注
    func addCustomAnnotation(
        timestamp: Date,
        sensorLabel: String,
        type: AnnotationType,
        value: Double?,
        description: String?
    ) {
        let annotation = DataAnnotation(
            timestamp: timestamp,
            dataLabel: sensorLabel,
            type: type,
            value: value,
            description: description
        )
        annotationManager.addAnnotation(annotation)
    }
    
    /// 清除所有标注
    func clearAllAnnotations() {
        annotationManager.clearAllAnnotations()
    }
    
    /// 切换自动标注功能
    func toggleAutoAnnotation() {
        annotationManager.isAutoAnnotationEnabled.toggle()
    }
}

// MARK: - Date Extension

private extension Date {
    func ISO8601Format() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}