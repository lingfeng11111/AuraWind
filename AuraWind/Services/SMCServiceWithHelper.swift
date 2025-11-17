//
//  SMCServiceWithHelper.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025-11-17.
//

import Foundation

/// SMC服务实现类（使用 Helper Tool）
/// 通过特权助手访问 SMC 硬件
@MainActor
final class SMCServiceWithHelper: SMCServiceProtocol {
    
    // MARK: - Properties
    
    /// Helper Tool 管理器
    private let helperManager = HelperToolManager.shared
    
    /// 是否已连接
    private(set) var isConnected: Bool = false
    
    /// 性能优化器
    private let performanceOptimizer = SMCPerformanceOptimizer()
    
    /// 配置
    private var configuration: SMCService.Configuration = .default
    
    /// 温度缓存
    private var temperatureCache: [String: CachedValue<Double>] = [:]
    
    /// 风扇信息缓存
    private var fanInfoCache: [Int: CachedValue<FanInfoData>] = [:]
    
    /// 缓存值包装器
    private struct CachedValue<T> {
        let value: T
        let timestamp: Date
        
        func isValid(timeout: TimeInterval) -> Bool {
            Date().timeIntervalSince(timestamp) < timeout
        }
    }
    
    // MARK: - Initialization
    
    init() {
        NSLog("[SMCServiceWithHelper] 初始化 SMCServiceWithHelper")
        print("初始化 SMCServiceWithHelper")
    }
    
    // MARK: - ServiceProtocol
    
    func configure(with configuration: SMCService.Configuration) throws {
        self.configuration = configuration
    }
    
    func start() async throws {
        guard !isConnected else { return }
        
        NSLog("[SMCServiceWithHelper] 启动 SMC 服务（使用 Helper Tool）...")
        print("启动 SMC 服务（使用 Helper Tool）...")
        
        do {
            // 连接到 Helper Tool
            NSLog("[SMCServiceWithHelper] 尝试连接到 Helper Tool...")
            try await helperManager.connect()
            NSLog("[SMCServiceWithHelper] ✅ Helper Tool 连接成功")
            
            // 连接到 SMC
            NSLog("[SMCServiceWithHelper] 尝试连接到 SMC...")
            try await helperManager.connectToSMC()
            NSLog("[SMCServiceWithHelper] ✅ SMC 连接成功")
            
            isConnected = true
            NSLog("[SMCServiceWithHelper] ✅ SMC 服务启动成功")
            print("✅ SMC 服务启动成功")
            
        } catch {
            NSLog("[SMCServiceWithHelper] ❌ SMC 服务启动失败: %@", error.localizedDescription)
            print("❌ SMC 服务启动失败: \(error.localizedDescription)")
            throw AuraWindError.smcConnectionFailed
        }
    }
    
    func stop() async {
        guard isConnected else { return }
        
        print("停止 SMC 服务...")
        
        await helperManager.disconnectFromSMC()
        helperManager.disconnect()
        
        isConnected = false
        temperatureCache.removeAll()
        fanInfoCache.removeAll()
        
        print("SMC 服务已停止")
    }
    
    // MARK: - SMCServiceProtocol - Connection
    
    func connect() async throws {
        try await start()
    }
    
    func disconnect() async {
        await stop()
    }
    
    // MARK: - SMCServiceProtocol - Temperature
    
    func readTemperature(sensor: TemperatureSensorType) async throws -> Double {
        guard isConnected else {
            throw AuraWindError.smcNotConnected
        }
        
        // 检查缓存
        let cacheKey = sensor.rawValue
        if let cached = temperatureCache[cacheKey],
           cached.isValid(timeout: configuration.cacheTimeout) {
            return cached.value
        }
        
        // 从 Helper Tool 读取
        do {
            let temperature = try await helperManager.readTemperature(sensorKey: sensor.smcKey)
            
            // 更新缓存
            temperatureCache[cacheKey] = CachedValue(
                value: temperature,
                timestamp: Date()
            )
            
            return temperature
            
        } catch {
            print("读取温度失败: \(error.localizedDescription)")
            throw AuraWindError.smcReadFailed
        }
    }
    
    func getAllTemperatures() async throws -> [TemperatureSensor] {
        NSLog("[SMCServiceWithHelper] getAllTemperatures 被调用")
        guard isConnected else {
            NSLog("[SMCServiceWithHelper] ❌ SMC 未连接")
            throw AuraWindError.smcNotConnected
        }
        
        do {
            // 获取所有可用的传感器
            NSLog("[SMCServiceWithHelper] 正在获取传感器列表...")
            let sensorKeys = try await helperManager.getAllTemperatureSensors()
            NSLog("[SMCServiceWithHelper] 获取到 \(sensorKeys.count) 个传感器: \(sensorKeys)")
            
            var sensors: [TemperatureSensor] = []
            
            for key in sensorKeys {
                do {
                    let temperature = try await helperManager.readTemperature(sensorKey: key)
                    NSLog("[SMCServiceWithHelper] 传感器 \(key) 温度: \(temperature)°C")
                    
                    let sensor = TemperatureSensor(
                        id: UUID(),
                        type: inferSensorType(from: key),
                        name: getSensorName(for: key),
                        currentTemperature: temperature,
                        maxTemperature: 100.0,
                        readings: []
                    )
                    
                    sensors.append(sensor)
                } catch {
                    NSLog("[SMCServiceWithHelper] ❌ 读取传感器 \(key) 失败: \(error)")
                    continue
                }
            }
            
            NSLog("[SMCServiceWithHelper] 返回 \(sensors.count) 个传感器")
            return sensors
            
        } catch {
            NSLog("[SMCServiceWithHelper] ❌ 获取温度列表失败: \(error.localizedDescription)")
            print("获取温度列表失败: \(error.localizedDescription)")
            throw AuraWindError.temperatureSensorFailed
        }
    }
    
    // MARK: - SMCServiceProtocol - Fan Control
    
    func getFanCount() async throws -> Int {
        guard isConnected else {
            throw AuraWindError.smcNotConnected
        }
        
        do {
            return try await helperManager.getFanCount()
        } catch {
            print("获取风扇数量失败: \(error.localizedDescription)")
            throw AuraWindError.smcReadFailed
        }
    }
    
    func getFanInfo(index: Int) async throws -> Fan {
        guard isConnected else {
            throw AuraWindError.smcNotConnected
        }
        
        // 检查缓存
        if let cached = fanInfoCache[index],
           cached.isValid(timeout: configuration.cacheTimeout * 5) {
            return cached.value.toFan()
        }
        
        do {
            let info = try await helperManager.getFanInfo(index: index)
            
            let fanInfo = FanInfoData(
                index: index,
                name: info["name"] as? String ?? "Fan \(index)",
                minSpeed: info["minSpeed"] as? Int ?? 1200,
                maxSpeed: info["maxSpeed"] as? Int ?? 6000,
                currentSpeed: info["currentSpeed"] as? Int ?? 2000
            )
            
            // 更新缓存
            fanInfoCache[index] = CachedValue(value: fanInfo, timestamp: Date())
            
            return fanInfo.toFan()
            
        } catch {
            print("获取风扇信息失败: \(error.localizedDescription)")
            throw AuraWindError.smcReadFailed
        }
    }
    
    func setFanSpeed(index: Int, rpm: Int) async throws {
        guard isConnected else {
            throw AuraWindError.smcNotConnected
        }
        
        // 验证转速范围
        let info = try await getFanInfo(index: index)
        guard rpm >= info.minSpeed && rpm <= info.maxSpeed else {
            throw AuraWindError.fanSpeedOutOfRange(rpm, info.minSpeed, info.maxSpeed)
        }
        
        do {
            try await helperManager.setFanSpeed(index: index, rpm: rpm)
            
            // 清除缓存
            fanInfoCache.removeValue(forKey: index)
            
            print("✅ 风扇 \(index) 转速已设置为 \(rpm) RPM")
            
        } catch {
            print("设置风扇转速失败: \(error.localizedDescription)")
            throw AuraWindError.smcWriteFailed
        }
    }
    
    func setFanAutoMode(index: Int) async throws {
        guard isConnected else {
            throw AuraWindError.smcNotConnected
        }
        
        do {
            try await helperManager.setFanAutoMode(index: index)
            
            // 清除缓存
            fanInfoCache.removeValue(forKey: index)
            
            print("✅ 风扇 \(index) 已设置为自动模式")
            
        } catch {
            print("设置自动模式失败: \(error.localizedDescription)")
            throw AuraWindError.smcWriteFailed
        }
    }
    
    func getFanCurrentSpeed(index: Int) async throws -> Int {
        guard isConnected else {
            throw AuraWindError.smcNotConnected
        }
        
        let fan = try await getFanInfo(index: index)
        return fan.currentSpeed
    }
    
    func getAllFans() async throws -> [Fan] {
        guard isConnected else {
            throw AuraWindError.smcNotConnected
        }
        
        do {
            let count = try await getFanCount()
            var fans: [Fan] = []
            
            for index in 0..<count {
                do {
                    let fan = try await getFanInfo(index: index)
                    fans.append(fan)
                } catch {
                    print("获取风扇 \(index) 信息失败，跳过")
                    continue
                }
            }
            
            return fans
            
        } catch {
            print("获取风扇列表失败: \(error.localizedDescription)")
            throw AuraWindError.smcReadFailed
        }
    }
    
    // MARK: - SMCServiceProtocol - Hardware Monitoring
    
    func getCPUUsage() async throws -> Double {
        // 使用SystemInfoService获取真实的CPU使用率
        let systemInfo = SystemInfoService()
        return systemInfo.getCPUUsage()
    }
    
    func getGPUUsage() async throws -> Double {
        // GPU使用率获取 - 暂时使用模拟数据
        return Double.random(in: 10...60)
    }
    
    func getMemoryUsage() async throws -> (used: Double, total: Double) {
        // 使用SystemInfoService获取真实的内存使用情况
        let systemInfo = SystemInfoService()
        return systemInfo.getMemoryUsage()
    }
    
    // MARK: - Private Methods
    
    /// 根据 SMC 键推断传感器类型
    private func inferSensorType(from key: String) -> TemperatureSensor.SensorType {
        if key.starts(with: "TC") {
            return .cpu
        } else if key.starts(with: "TG") {
            return .gpu
        } else if key.starts(with: "Th") {
            return .ssd
        } else if key.starts(with: "TA") {
            return .ambient
        } else if key.starts(with: "TB") {
            return .battery
        } else {
            return .proximity
        }
    }
    
    /// 获取传感器名称
    private func getSensorName(for key: String) -> String {
        let sensorNames: [String: String] = [
            "TC0P": "CPU 接近传感器",
            "TC0D": "CPU 芯片温度",
            "TC0E": "CPU 核心 1",
            "TC0F": "CPU 核心 2",
            "TG0P": "GPU 接近传感器",
            "TG0D": "GPU 芯片温度",
            "Th0H": "硬盘温度",
            "Tm0P": "主板温度",
            "TN0P": "北桥温度",
            "TA0P": "环境温度",
            "TB0T": "电池温度",
        ]
        
        return sensorNames[key] ?? key
    }
}

// MARK: - FanInfoData Helper

private struct FanInfoData {
    let index: Int
    let name: String
    let minSpeed: Int
    let maxSpeed: Int
    let currentSpeed: Int
    
    func toFan() -> Fan {
        return Fan(
            id: UUID(),
            index: index,
            name: name,
            currentSpeed: currentSpeed,
            minSpeed: minSpeed,
            maxSpeed: maxSpeed,
            isManualControl: false,
            targetSpeed: currentSpeed
        )
    }
}
