//
//  FanControlViewModel.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025-11-16.
//

import Foundation
import Combine

/// 风扇控制视图模型
/// 负责管理风扇状态、监控任务和模式切换
@MainActor
final class FanControlViewModel: BaseViewModel {
    
    // MARK: - Published Properties
    
    /// 风扇列表
    @Published private(set) var fans: [Fan] = []
    
    /// 当前监控状态
    @Published private(set) var isMonitoring: Bool = false
    
    /// 当前控制模式
    @Published private(set) var currentMode: FanMode = .auto
    
    /// 当前激活的曲线配置
    @Published private(set) var activeCurveProfile: CurveProfile?
    
    /// 温度传感器数据(用于曲线控制)
    @Published private(set) var temperatureSensors: [TemperatureSensor] = []
    
    /// 风扇图表数据点
    @Published private(set) var fanChartData: [ChartDataPoint] = []
    
    /// 当前选中的时间范围
    @Published var selectedTimeRange: ChartDataPoint.TimeRange = .oneHour
    
    /// 选中的风扇标签（用于图表过滤）
    @Published var selectedFanLabels: Set<String> = []
    
    // MARK: - Types
    
    /// 风扇控制模式
    enum FanMode: String, Codable, CaseIterable {
        case auto = "自动"
        case manual = "手动"
        case curve = "曲线"
        case silent = "静音"
        case balanced = "平衡"
        case performance = "性能"
        
        var description: String {
            rawValue
        }
    }
    
    // MARK: - Dependencies
    
    private let smcService: SMCServiceProtocol
    private let persistenceService: PersistenceServiceProtocol
    
    // MARK: - Private Properties
    
    /// 监控任务
    private var monitoringTask: Task<Void, Never>?
    
    /// 更新间隔(秒)
    private let updateInterval: TimeInterval = 2.0
    
    /// 最大图表数据点数
    private let maxChartDataPoints: Int = 3000
    
    // MARK: - Initialization
    
    init(
        smcService: SMCServiceProtocol,
        persistenceService: PersistenceServiceProtocol
    ) {
        self.smcService = smcService
        self.persistenceService = persistenceService
        super.init()
        
        setupBindings()
        loadSavedSettings()
    }
    
    // deinit自动取消Task,无需手动处理
    
    // MARK: - Public Methods
    
    /// 开始监控
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        monitoringTask = Task {
            await monitorFansAndTemperature()
        }
    }
    
    /// 停止监控
    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
        isMonitoring = false
    }
    
    /// 初始化风扇列表
    func initializeFans() async {
        await performAsyncOperation {
            // 连接SMC服务
            try await self.smcService.connect()
            
            // 获取所有风扇
            let allFans = try await self.smcService.getAllFans()
            self.fans = allFans
        }
    }
    
    /// 设置风扇转速
    /// - Parameters:
    ///   - fanIndex: 风扇索引
    ///   - rpm: 目标转速(RPM)
    func setFanSpeed(fanIndex: Int, rpm: Int) async {
        guard fanIndex < fans.count else {
            error = AuraWindError.fanNotFound(fanIndex)
            return
        }
        
        await performAsyncOperation {
            try await self.smcService.setFanSpeed(index: fanIndex, rpm: rpm)
            
            // 更新本地状态
            self.fans[fanIndex].currentSpeed = rpm
            self.fans[fanIndex].isManualControl = true
        }
    }
    
    /// 切换控制模式
    /// - Parameter mode: 目标模式
    func changeMode(_ mode: FanMode) async {
        currentMode = mode
        
        switch mode {
        case .auto:
            await resetToAuto()
        case .manual:
            // 手动模式不做自动调整
            break
        case .curve:
            // 如果有激活的曲线,应用它
            if let profile = activeCurveProfile {
                await applyCurveProfile(profile)
            }
        case .silent:
            await applyPresetMode(CurveProfile.silent)
        case .balanced:
            await applyPresetMode(CurveProfile.balanced)
        case .performance:
            await applyPresetMode(CurveProfile.performance)
        }
        
        // 保存设置
        saveSettings()
    }
    
    /// 应用曲线配置
    /// - Parameter profile: 曲线配置
    func applyCurveProfile(_ profile: CurveProfile) async {
        activeCurveProfile = profile
        currentMode = .curve
        
        // 根据当前温度应用曲线
        await updateFansBasedOnCurve()
        
        // 保存设置
        saveSettings()
    }
    
    /// 重置为自动模式
    func resetToAuto() async {
        currentMode = .auto
        activeCurveProfile = nil
        
        for (index, _) in fans.enumerated() {
            await performAsyncOperation {
                try await self.smcService.setFanAutoMode(index: index)
                self.fans[index].isManualControl = false
            }
        }
        
        saveSettings()
    }
    
    /// 刷新风扇信息
    func refreshFans() async {
        await performAsyncOperation {
            for (index, _) in self.fans.enumerated() {
                let speed = try await self.smcService.getFanCurrentSpeed(index: index)
                self.fans[index].currentSpeed = speed
            }
        }
    }
    
    /// 刷新温度信息
    func refreshTemperature() async {
        await performAsyncOperation {
            let sensors = try await self.smcService.getAllTemperatures()
            self.temperatureSensors = sensors
        }
    }
    
    // MARK: - Chart Data Methods
    
    /// 获取指定时间范围的图表数据
    /// - Parameter range: 时间范围
    /// - Returns: 过滤后的图表数据点
    func getChartData(for range: ChartDataPoint.TimeRange) -> [ChartDataPoint] {
        fanChartData.filtered(by: range)
    }
    
    /// 获取指定风扇的图表数据
    /// - Parameters:
    ///   - fanLabels: 风扇标签集合
    ///   - range: 时间范围
    /// - Returns: 过滤后的图表数据点
    func getChartData(
        for fanLabels: Set<String>,
        in range: ChartDataPoint.TimeRange
    ) -> [ChartDataPoint] {
        let rangeFiltered = fanChartData.filtered(by: range)
        if fanLabels.isEmpty {
            return rangeFiltered
        }
        return rangeFiltered.filter { fanLabels.contains($0.label) }
    }
    
    /// 获取当前选中范围的图表数据
    /// - Returns: 图表数据点数组
    func getCurrentChartData() -> [ChartDataPoint] {
        getChartData(for: selectedFanLabels, in: selectedTimeRange)
    }
    
    /// 获取所有可用的风扇标签
    /// - Returns: 风扇标签数组
    func getAvailableFanLabels() -> [String] {
        fanChartData.uniqueLabels
    }
    
    /// 切换风扇选择状态
    /// - Parameter label: 风扇标签
    func toggleFanSelection(_ label: String) {
        if selectedFanLabels.contains(label) {
            selectedFanLabels.remove(label)
        } else {
            selectedFanLabels.insert(label)
        }
    }
    
    /// 选择所有风扇
    func selectAllFans() {
        selectedFanLabels = Set(getAvailableFanLabels())
    }
    
    /// 取消选择所有风扇
    func deselectAllFans() {
        selectedFanLabels.removeAll()
    }
    
    /// 获取指定标签的统计信息
    /// - Parameters:
    ///   - label: 风扇标签
    ///   - range: 时间范围
    /// - Returns: (平均值, 最大值, 最小值)
    func getStatistics(
        for label: String,
        in range: ChartDataPoint.TimeRange
    ) -> (average: Double?, max: Double?, min: Double?) {
        let average = fanChartData.average(for: label, in: range)
        let max = fanChartData.maximum(for: label, in: range)
        let min = fanChartData.minimum(for: label, in: range)
        return (average, max, min)
    }
    
    /// 清除图表数据
    func clearChartData() {
        fanChartData.removeAll()
    }
    
    // MARK: - Private Methods
    
    /// 设置数据绑定
    override func setupBindings() {
        super.setupBindings()
        
        // 监控模式变化
        $currentMode
            .sink { mode in
                print("风扇控制模式切换为: \(mode.description)")
            }
            .store(in: &cancellables)
    }
    
    /// 加载保存的设置
    private func loadSavedSettings() {
        // 加载上次的控制模式
        if let modeString: String = try? persistenceService.load(String.self, forKey: "fanControlMode"),
           let mode = FanMode(rawValue: modeString) {
            currentMode = mode
        }
        
        // 加载曲线配置
        if let profileData: Data = try? persistenceService.load(Data.self, forKey: "activeCurveProfile"),
           let profile = try? JSONDecoder().decode(CurveProfile.self, from: profileData) {
            activeCurveProfile = profile
        }
    }
    
    /// 保存设置
    private func saveSettings() {
        try? persistenceService.save(currentMode.rawValue, forKey: "fanControlMode")
        
        if let profile = activeCurveProfile,
           let profileData = try? JSONEncoder().encode(profile) {
            try? persistenceService.save(profileData, forKey: "activeCurveProfile")
        }
    }
    
    /// 监控风扇和温度
    private func monitorFansAndTemperature() async {
        while !Task.isCancelled && isMonitoring {
            // 刷新温度
            await refreshTemperature()
            
            // 刷新风扇状态
            await refreshFans()
            
            // 收集风扇图表数据
            await collectFanChartData()
            
            // 如果是曲线模式,根据温度调整风扇
            if currentMode == .curve || [.silent, .balanced, .performance].contains(currentMode) {
                await updateFansBasedOnCurve()
            }
            
            // 等待下次更新
            try? await Task.sleep(nanoseconds: UInt64(updateInterval * 1_000_000_000))
        }
    }
    
    /// 根据曲线更新风扇转速
    private func updateFansBasedOnCurve() async {
        guard let profile = activeCurveProfile else { return }
        
        // 获取CPU温度作为参考
        guard let cpuSensor = temperatureSensors.first(where: { $0.type == .cpu }) else {
            return
        }
        
        let temperature = cpuSensor.currentTemperature
        let targetSpeed = profile.interpolateFanSpeed(for: temperature)
        
        // 为所有风扇设置相同的转速
        for (index, fan) in fans.enumerated() {
            // 确保转速在有效范围内
            let clampedSpeed = min(max(targetSpeed, fan.minSpeed), fan.maxSpeed)
            
            // 只有转速变化超过阈值才更新(避免频繁调整)
            let speedDiff = abs(fan.currentSpeed - clampedSpeed)
            if speedDiff > 100 {
                await setFanSpeed(fanIndex: index, rpm: clampedSpeed)
            }
        }
    }
    
    /// 应用预设模式
    private func applyPresetMode(_ profile: CurveProfile) async {
        activeCurveProfile = profile
        await updateFansBasedOnCurve()
    }
    
    /// 收集风扇图表数据
    private func collectFanChartData() async {
        for (_, fan) in fans.enumerated() {
            let chartPoint = ChartDataPoint(
                timestamp: Date(),
                value: Double(fan.currentSpeed),
                label: fan.name,
                type: .fanSpeed
            )
            addChartDataPoint(chartPoint)
        }
    }
    
    /// 添加图表数据点
    private func addChartDataPoint(_ point: ChartDataPoint) {
        fanChartData.append(point)
        
        // 限制图表数据点数量
        if fanChartData.count > maxChartDataPoints {
            let data = fanChartData
            fanChartData = Array(data.suffix(maxChartDataPoints))
        }
    }
}