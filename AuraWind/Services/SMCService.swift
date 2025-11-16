//
//  SMCService.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025-11-16.
//

import Foundation
import IOKit

/// SMC服务实现类
/// 负责与macOS System Management Controller通信
@MainActor
final class SMCService: SMCServiceProtocol {
    
    // MARK: - Types
    
    /// SMC配置
    struct Configuration {
        let cacheTimeout: TimeInterval
        let retryCount: Int
        let retryDelay: TimeInterval
        
        static let `default` = Configuration(
            cacheTimeout: 1.0,
            retryCount: 3,
            retryDelay: 0.1
        )
    }
    
    /// 缓存值包装器
    private struct CachedValue<T> {
        let value: T
        let timestamp: Date
        
        func isValid(timeout: TimeInterval) -> Bool {
            Date().timeIntervalSince(timestamp) < timeout
        }
    }
    
    // MARK: - Properties
    
    /// SMC连接句柄
    private var connection: io_connect_t = 0
    
    /// 连接状态
    private(set) var isConnected: Bool = false
    
    /// 配置
    private var configuration: Configuration = .default
    
    /// 串行队列,确保SMC访问线程安全
    private let queue = DispatchQueue(label: "com.aurawind.smc", qos: .userInitiated)
    
    /// 温度缓存
    private var temperatureCache: [String: CachedValue<Double>] = [:]
    
    /// 风扇信息缓存
    private var fanInfoCache: [Int: CachedValue<FanInfo>] = [:]
    
    // MARK: - Initialization
    
    init() {
        // 初始化时不自动连接,等待显式调用start()
    }
    
    deinit {
        // 确保在销毁时关闭连接
        Task { @MainActor in
            await stop()
        }
    }
    
    // MARK: - ServiceProtocol
    
    func configure(with configuration: Configuration) throws {
        self.configuration = configuration
    }
    
    func start() async throws {
        guard !isConnected else { return }
        
        try await openSMCConnection()
        isConnected = true
    }
    
    func stop() async {
        guard isConnected else { return }
        
        await closeSMCConnection()
        isConnected = false
        
        // 清空缓存
        temperatureCache.removeAll()
        fanInfoCache.removeAll()
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
        
        // 读取温度
        let temperature = try await performSMCRead(key: sensor.smcKey, type: .flt)
        
        // 更新缓存
        temperatureCache[cacheKey] = CachedValue(
            value: temperature,
            timestamp: Date()
        )
        
        return temperature
    }
    
    func getAllTemperatures() async throws -> [TemperatureSensor] {
        guard isConnected else {
            throw AuraWindError.smcNotConnected
        }
        
        var sensors: [TemperatureSensor] = []
        
        // 读取常见的温度传感器
        let sensorTypes: [TemperatureSensorType] = [.cpuProximity, .gpuProximity, .ambient]
        
        for type in sensorTypes {
            do {
                let temp = try await readTemperature(sensor: type)
                let sensor = TemperatureSensor(
                    type: TemperatureSensor.SensorType(rawValue: type.rawValue) ?? .cpu,
                    name: type.displayName,
                    currentTemperature: temp,
                    maxTemperature: type.maxTemperature
                )
                sensors.append(sensor)
            } catch {
                // 某些传感器可能不存在,继续尝试其他传感器
                continue
            }
        }
        
        return sensors
    }
    
    // MARK: - SMCServiceProtocol - Fan Control
    
    func getFanCount() async throws -> Int {
        guard isConnected else {
            throw AuraWindError.smcNotConnected
        }
        
        // 读取风扇数量
        let count = try await performSMCRead(key: "FNum", type: .ui8)
        return Int(count)
    }
    
    func getFanInfo(index: Int) async throws -> Fan {
        guard isConnected else {
            throw AuraWindError.smcNotConnected
        }
        
        // 检查缓存
        if let cached = fanInfoCache[index],
           cached.isValid(timeout: configuration.cacheTimeout * 5) { // 风扇信息缓存时间更长
            return cached.value.toFan()
        }
        
        // 读取风扇信息
        let minSpeed = try await performSMCRead(key: "F\(index)Mn", type: .fpe2)
        let maxSpeed = try await performSMCRead(key: "F\(index)Mx", type: .fpe2)
        let currentSpeed = try await performSMCRead(key: "F\(index)Ac", type: .fpe2)
        
        let info = FanInfo(
            index: index,
            name: "Fan \(index)",
            minSpeed: Int(minSpeed),
            maxSpeed: Int(maxSpeed),
            currentSpeed: Int(currentSpeed)
        )
        
        // 更新缓存
        fanInfoCache[index] = CachedValue(value: info, timestamp: Date())
        
        return info.toFan()
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
        
        // 设置目标转速
        try await performSMCWrite(key: "F\(index)Tg", value: Double(rpm), type: .fpe2)
        
        // 清除缓存以强制下次读取最新值
        fanInfoCache.removeValue(forKey: index)
    }
    
    func setFanAutoMode(index: Int) async throws {
        guard isConnected else {
            throw AuraWindError.smcNotConnected
        }
        
        // 设置为自动模式(通常是写入0)
        try await performSMCWrite(key: "F\(index)Md", value: 0, type: .ui8)
        
        // 清除缓存
        fanInfoCache.removeValue(forKey: index)
    }
    
    func getFanCurrentSpeed(index: Int) async throws -> Int {
        guard isConnected else {
            throw AuraWindError.smcNotConnected
        }
        
        let speed = try await performSMCRead(key: "F\(index)Ac", type: .fpe2)
        return Int(speed)
    }
    
    func getAllFans() async throws -> [Fan] {
        guard isConnected else {
            throw AuraWindError.smcNotConnected
        }
        
        let fanCount = try await getFanCount()
        var fans: [Fan] = []
        
        for index in 0..<fanCount {
            let fan = try await getFanInfo(index: index)
            fans.append(fan)
        }
        
        return fans
    }
    
    // MARK: - SMCServiceProtocol - Hardware Monitoring
    
    func getCPUUsage() async throws -> Double {
        // 这里使用系统API获取CPU使用率,而不是SMC
        // 因为SMC主要用于温度和风扇控制
        // 实际实现需要使用host_statistics等系统API
        return 0.0 // 占位实现
    }
    
    func getGPUUsage() async throws -> Double {
        // GPU使用率获取
        // 实际实现需要使用Metal或其他GPU API
        return 0.0 // 占位实现
    }
    
    func getMemoryUsage() async throws -> (used: Double, total: Double) {
        // 内存使用情况获取
        // 实际实现需要使用mach API
        return (used: 8.0, total: 16.0) // 占位实现
    }
    
    // MARK: - Private Methods - Connection Management
    
    private func openSMCConnection() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: AuraWindError.smcServiceNotAvailable)
                    return
                }
                
                // 获取SMC服务
                let service = IOServiceGetMatchingService(
                    kIOMainPortDefault,
                    IOServiceMatching("AppleSMC")
                )
                
                guard service != 0 else {
                    continuation.resume(throwing: AuraWindError.smcServiceNotFound)
                    return
                }
                
                // 打开服务连接
                var conn: io_connect_t = 0
                let result = IOServiceOpen(service, mach_task_self_, 0, &conn)
                
                IOObjectRelease(service)
                
                if result == kIOReturnSuccess {
                    Task { @MainActor in
                        self.connection = conn
                    }
                    continuation.resume()
                } else {
                    continuation.resume(throwing: AuraWindError.smcConnectionFailed)
                }
            }
        }
    }
    
    private func closeSMCConnection() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async { [weak self] in
                guard let self = self, self.connection != 0 else {
                    continuation.resume()
                    return
                }
                
                IOServiceClose(self.connection)
                Task { @MainActor in
                    self.connection = 0
                }
                continuation.resume()
            }
        }
    }
    
    // MARK: - Private Methods - SMC Operations
    
    /// SMC数据类型
    private enum SMCDataType: String {
        case flt = "flt "  // 浮点数
        case ui8 = "ui8 "  // 8位无符号整数
        case ui16 = "ui16"  // 16位无符号整数
        case fpe2 = "fpe2"  // 定点数(14.2格式)
        
        var fourCharCode: UInt32 {
            rawValue.fourCharCode
        }
    }
    
    /// 执行SMC读取操作
    private func performSMCRead(key: String, type: SMCDataType) async throws -> Double {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double, Error>) in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: AuraWindError.smcServiceNotAvailable)
                    return
                }
                
                // 这里是SMC读取的底层实现
                // 由于SMC的具体实现涉及到底层的IOKit调用,这里提供简化版本
                // 实际项目中需要完整实现SMC协议
                
                do {
                    // 占位实现:返回模拟数据
                    // 实际需要调用IOKit的SMC读取函数
                    let value = try self.mockSMCRead(key: key, type: type)
                    continuation.resume(returning: value)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 执行SMC写入操作
    private func performSMCWrite(key: String, value: Double, type: SMCDataType) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: AuraWindError.smcServiceNotAvailable)
                    return
                }
                
                // SMC写入的底层实现
                // 占位实现
                do {
                    try self.mockSMCWrite(key: key, value: value, type: type)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Mock Implementation (临时用于开发测试)
    
    /// 模拟SMC读取(开发阶段使用)
    private func mockSMCRead(key: String, type: SMCDataType) throws -> Double {
        // 模拟温度读取
        if key.starts(with: "T") {
            return Double.random(in: 40...75)
        }
        
        // 模拟风扇数量
        if key == "FNum" {
            return 2.0
        }
        
        // 模拟风扇转速
        if key.contains("Ac") {
            return Double.random(in: 1500...3000)
        }
        
        // 模拟最小转速
        if key.contains("Mn") {
            return 1200.0
        }
        
        // 模拟最大转速
        if key.contains("Mx") {
            return 6000.0
        }
        
        return 0.0
    }
    
    /// 模拟SMC写入(开发阶段使用)
    private func mockSMCWrite(key: String, value: Double, type: SMCDataType) throws {
        // 开发阶段的模拟实现
        print("Mock SMC Write: \(key) = \(value)")
    }
}

// MARK: - String Extension

private extension String {
    /// 将4字符字符串转换为FourCharCode
    var fourCharCode: UInt32 {
        var code: UInt32 = 0
        for char in self.utf8.prefix(4) {
            code = code << 8 + UInt32(char)
        }
        return code
    }
}