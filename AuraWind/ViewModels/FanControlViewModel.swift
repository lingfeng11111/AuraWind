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
    @Published private(set) var currentMode: FanMode = .balanced
    
    /// 当前激活的温控曲线配置（用于静音/平衡）
    @Published private(set) var activeCurveProfile: CurveProfile?
    
    /// 温度传感器数据(用于温控曲线)
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
        case manual = "手动"
        case silent = "自动"
        case balanced = "静音"
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

    /// 系统休眠前释放风扇控制权，避免休眠期间持续高转速
    func prepareForSystemSleep() async {
        stopMonitoring()
        await releaseAllFansToAutoMode()
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
            self.fans[fanIndex].targetSpeed = rpm
        }
    }
    
    /// 切换控制模式
    /// - Parameter mode: 目标模式
    func changeMode(_ mode: FanMode) async {
        currentMode = mode
        
        switch mode {
        case .manual:
            // 手动模式不做自动温控调整
            activeCurveProfile = nil
        case .silent:
            // 自动模式：交还系统控制，不再下发曲线目标转速。
            activeCurveProfile = nil
            await releaseAllFansToAutoMode()
        case .balanced:
            await applyPresetMode(CurveProfile.balanced)
        case .performance:
            // 性能模式按用户预期直接拉满转速，而不是走温度曲线。
            activeCurveProfile = nil
            await applyMaxPerformanceMode()
        }
        
        // 保存设置
        saveSettings()
    }
    
    /// 应用曲线配置（从设置页调用时默认映射到静音模式）
    /// - Parameter profile: 曲线配置
    func applyCurveProfile(_ profile: CurveProfile) async {
        activeCurveProfile = profile
        currentMode = .balanced
        
        // 根据当前温度应用曲线
        await updateFansBasedOnCurve()
        
        // 保存设置
        saveSettings()
    }
    
    /// 刷新风扇信息
    func refreshFans() async {
        await performAsyncOperation {
            for (index, _) in self.fans.enumerated() {
                let speed = try await self.smcService.getFanCurrentSpeed(index: index)
                // 某些机型手动模式下读取当前转速会返回 0，避免覆盖本地目标导致重复写入。
                if speed > 0 || !self.fans[index].isManualControl {
                    self.fans[index].currentSpeed = speed
                }
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
        if let modeString: String = try? persistenceService.load(String.self, forKey: "fanControlMode") {
            if let mode = FanMode(rawValue: modeString) {
                currentMode = mode
            } else {
                switch modeString {
                case "平衡", "曲线":
                    // 旧版“平衡/曲线”统一迁移到当前静音模式（原平衡逻辑）。
                    currentMode = .balanced
                case "静音":
                    // 旧版静音本质也是温控曲线，迁移到当前静音模式（原平衡逻辑）。
                    currentMode = .balanced
                case "自动":
                    currentMode = .silent
                default:
                    break
                }
            }
        }
        
        // 加载曲线配置
        if let profileData: Data = try? persistenceService.load(Data.self, forKey: "activeCurveProfile"),
           let profile = try? JSONDecoder().decode(CurveProfile.self, from: profileData) {
            activeCurveProfile = profile
        }

        if activeCurveProfile == nil {
            switch currentMode {
            case .balanced:
                activeCurveProfile = .balanced
            case .manual, .silent, .performance:
                break
            }
        } else if currentMode == .silent {
            // 自动模式不应携带任何温控曲线。
            activeCurveProfile = nil
        }
    }
    
    /// 保存设置
    private func saveSettings() {
        try? persistenceService.save(currentMode.rawValue, forKey: "fanControlMode")
        
        if let profile = activeCurveProfile,
           let profileData = try? JSONEncoder().encode(profile) {
            try? persistenceService.save(profileData, forKey: "activeCurveProfile")
        } else {
            persistenceService.delete(forKey: "activeCurveProfile")
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
            
            // 根据当前控制模式持续校正风扇转速
            if currentMode == .performance {
                await applyMaxPerformanceMode()
            } else if currentMode == .balanced {
                await updateFansBasedOnCurve()
            }
            
            // 等待下次更新
            try? await Task.sleep(nanoseconds: UInt64(updateInterval * 1_000_000_000))
        }
    }
    
    /// 根据曲线更新风扇转速
    private func updateFansBasedOnCurve() async {
        guard let profile = activeCurveProfile else { return }
        
        // 优先使用 CPU 传感器；若机型键位无法正确分类，则退化为当前最高温传感器。
        let validSensors = temperatureSensors.filter { $0.currentTemperature > 0 }
        guard let referenceSensor = validSensors.first(where: { $0.type == .cpu })
            ?? validSensors.max(by: { $0.currentTemperature < $1.currentTemperature }) else {
            return
        }
        
        let temperature = referenceSensor.currentTemperature
        let targetSpeed = profile.interpolateFanSpeed(for: temperature)
        
        // 为所有风扇设置相同的转速
        for (index, fan) in fans.enumerated() {
            // 确保转速在有效范围内
            let clampedSpeed = min(max(targetSpeed, fan.minSpeed), fan.maxSpeed)
            
            // 只有转速变化超过阈值才更新(避免频繁调整)
            let referenceSpeed = fan.currentSpeed > 0 ? fan.currentSpeed : (fan.targetSpeed ?? fan.currentSpeed)
            let speedDiff = abs(referenceSpeed - clampedSpeed)
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

    /// 性能模式：直接将所有风扇拉到最大转速
    private func applyMaxPerformanceMode() async {
        for (index, fan) in fans.enumerated() {
            let targetSpeed = fan.maxSpeed
            let referenceSpeed = fan.currentSpeed > 0 ? fan.currentSpeed : (fan.targetSpeed ?? fan.currentSpeed)
            let speedDiff = abs(referenceSpeed - targetSpeed)
            
            // 非手动控制或与目标差距较大时，重新下发目标转速
            if !fan.isManualControl || speedDiff > 80 {
                await setFanSpeed(fanIndex: index, rpm: targetSpeed)
            }
        }
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

    /// 将所有风扇恢复为系统自动调速
    private func releaseAllFansToAutoMode() async {
        let indices: [Int]
        if fans.isEmpty {
            if let fanCount = try? await smcService.getFanCount() {
                indices = Array(0..<fanCount)
            } else {
                return
            }
        } else {
            indices = fans.map(\.index)
        }

        for index in indices {
            do {
                try await smcService.setFanAutoMode(index: index)
            } catch {
                print("⚠️ 设置风扇 \(index) 自动模式失败: \(error)")
            }
        }

        for fanIndex in fans.indices {
            fans[fanIndex].isManualControl = false
            fans[fanIndex].targetSpeed = nil
        }
    }
}
