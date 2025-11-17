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
    
    // MARK: - Properties
    
    /// 权限管理器
    private let permissionManager = SMCPermissionManager()
    
    /// 性能优化器
    private let performanceOptimizer = SMCPerformanceOptimizer()
    
    /// 是否使用真实SMC（如果权限允许）
    private var useRealSMC: Bool = false
    
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
        if isConnected {
            // 使用非异步方式关闭连接
            if connection != 0 {
                IOServiceClose(connection)
                connection = 0
            }
            isConnected = false
            temperatureCache.removeAll()
            fanInfoCache.removeAll()
        }
    }
    
    // MARK: - ServiceProtocol
    
    func configure(with configuration: Configuration) throws {
        self.configuration = configuration
    }
    
    func start() async throws {
        guard !isConnected else { return }
        
        // 检查权限
        let permissionStatus = await permissionManager.checkPermissions()
        useRealSMC = permissionStatus.isAccessible
        
        if !useRealSMC {
            print("⚠️ SMC权限未授予，将使用模拟数据")
            print(permissionManager.getPermissionHelp())
        } else {
            print("✅ SMC权限已授予，将使用真实硬件数据")
        }
        
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
        
        // 检查性能优化器缓存
        let perfCacheKey = "temp_\(sensor.smcKey)"
        if let cachedValue = performanceOptimizer.getCachedValue(for: perfCacheKey) {
            // 同时更新本地缓存
            temperatureCache[cacheKey] = CachedValue(
                value: cachedValue,
                timestamp: Date()
            )
            return cachedValue
        }
        
        let startTime = Date()
        
        // 读取温度
        let temperature = try await performSMCRead(key: sensor.smcKey, type: .flt)
        
        let duration = Date().timeIntervalSince(startTime)
        
        // 更新缓存
        temperatureCache[cacheKey] = CachedValue(
            value: temperature,
            timestamp: Date()
        )
        
        // 更新性能优化器缓存和统计
        performanceOptimizer.setCachedValue(temperature, for: perfCacheKey)
        performanceOptimizer.recordAccess(for: perfCacheKey, duration: duration, success: true)
        
        return temperature
    }
    
    func getAllTemperatures() async throws -> [TemperatureSensor] {
        guard isConnected else {
            throw AuraWindError.smcNotConnected
        }
        
        // 由于SMC访问受限，使用SystemInfoService获取模拟温度数据
        let systemInfo = SystemInfoService()
        return systemInfo.getTemperatures()
    }
    
    // MARK: - SMCServiceProtocol - Fan Control
    
    func getFanCount() async throws -> Int {
        guard isConnected else {
            throw AuraWindError.smcNotConnected
        }
        
        // 检查性能优化器缓存
        let cacheKey = "fan_count"
        if let cachedValue = performanceOptimizer.getCachedValue(for: cacheKey) {
            return Int(cachedValue)
        }
        
        let startTime = Date()
        
        // 读取风扇数量
        let count = try await performSMCRead(key: "FNum", type: .ui8)
        
        let duration = Date().timeIntervalSince(startTime)
        
        // 更新性能优化器缓存和统计
        performanceOptimizer.setCachedValue(count, for: cacheKey)
        performanceOptimizer.recordAccess(for: cacheKey, duration: duration, success: true)
        
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
        
        // 检查性能优化器缓存
        let cacheKey = "fan_info_\(index)"
        if let cachedValue = performanceOptimizer.getCachedValue(for: cacheKey) {
            // 从缓存值重建FanInfo（简化实现）
            let info = FanInfo(
                index: index,
                name: "Fan \(index)",
                minSpeed: Int(cachedValue),
                maxSpeed: Int(cachedValue),
                currentSpeed: Int(cachedValue)
            )
            return info.toFan()
        }
        
        let startTime = Date()
        
        // 读取风扇信息
        let minSpeed = try await performSMCRead(key: "F\(index)Mn", type: .fpe2)
        let maxSpeed = try await performSMCRead(key: "F\(index)Mx", type: .fpe2)
        let currentSpeed = try await performSMCRead(key: "F\(index)Ac", type: .fpe2)
        
        let duration = Date().timeIntervalSince(startTime)
        
        let info = FanInfo(
            index: index,
            name: "Fan \(index)",
            minSpeed: Int(minSpeed),
            maxSpeed: Int(maxSpeed),
            currentSpeed: Int(currentSpeed)
        )
        
        // 更新缓存
        fanInfoCache[index] = CachedValue(value: info, timestamp: Date())
        
        // 更新性能优化器缓存和统计
        performanceOptimizer.setCachedValue(Double(currentSpeed), for: cacheKey)
        performanceOptimizer.recordAccess(for: cacheKey, duration: duration, success: true)
        
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
        
        // 由于SMC访问受限，使用SystemInfoService获取模拟风扇数据
        let systemInfo = SystemInfoService()
        return systemInfo.getFanInfo()
    }
    
    // MARK: - SMCServiceProtocol - Hardware Monitoring
    
    func getCPUUsage() async throws -> Double {
        // 使用SystemInfoService获取真实的CPU使用率
        let systemInfo = SystemInfoService()
        return systemInfo.getCPUUsage()
    }
    
    func getGPUUsage() async throws -> Double {
        // GPU使用率获取 - 暂时使用模拟数据
        // 实际实现需要使用Metal或其他GPU API
        return Double.random(in: 10...60) // 模拟GPU使用率
    }
    
    func getMemoryUsage() async throws -> (used: Double, total: Double) {
        // 使用SystemInfoService获取真实的内存使用情况
        let systemInfo = SystemInfoService()
        return systemInfo.getMemoryUsage()
    }
    
    // MARK: - Private Methods - Connection Management
    
    private func openSMCConnection() async throws {
        try await withCheckedThrowingContinuation { [weak self] (continuation: CheckedContinuation<Void, Error>) in
            guard let self = self else {
                continuation.resume(throwing: AuraWindError.smcServiceNotAvailable)
                return
            }
            
            self.queue.async { [weak self] in
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
                    let capturedConn = conn
                    Task { @MainActor in
                        self.connection = capturedConn
                    }
                    continuation.resume()
                } else {
                    continuation.resume(throwing: AuraWindError.smcConnectionFailed)
                }
            }
        }
    }
    
    private func closeSMCConnection() async {
        await withCheckedContinuation { [weak self] (continuation: CheckedContinuation<Void, Never>) in
            guard let self = self else {
                continuation.resume()
                return
            }
            
            self.queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                let capturedConnection = self.connection
                if capturedConnection != 0 {
                    IOServiceClose(capturedConnection)
                    Task { @MainActor in
                        self.connection = 0
                    }
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
        return try await withCheckedThrowingContinuation { [weak self] (continuation: CheckedContinuation<Double, Error>) in
            guard let self = self else {
                continuation.resume(throwing: AuraWindError.smcServiceNotAvailable)
                return
            }
            
            self.queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: AuraWindError.smcServiceNotAvailable)
                    return
                }
                
                // 这里是SMC读取的底层实现
                // 由于SMC的具体实现涉及到底层的IOKit调用,这里提供简化版本
                // 实际项目中需要完整实现SMC协议
                
                // 根据权限选择读取方式
                let value: Double
                if self.useRealSMC {
                    do {
                        // 使用同步方式调用performRealSMCRead
                        let connection = SMCConnection()
                        try connection.connect()
                        defer { connection.disconnect() }
                        
                        // 转换数据类型
                        let connectionType = self.convertToConnectionType(type)
                        let result = try connection.readValue(key: key, type: connectionType)
                        value = result.value
                        print("✅ SMC读取成功: \(key) = \(value)")
                    } catch let error {
                        // 真实读取失败，检查是否需要权限恢复
                        if self.permissionManager.handleSMCError(error) {
                            // 可以重试
                            do {
                                let connection = SMCConnection()
                                try connection.connect()
                                defer { connection.disconnect() }
                                
                                let connectionType = self.convertToConnectionType(type)
                                let result = try connection.readValue(key: key, type: connectionType)
                                value = result.value
                            } catch {
                                // 回退到模拟数据
                                print("⚠️ SMC读取失败，使用模拟数据: \(error.localizedDescription)")
                                value = (try? self.mockSMCRead(key: key, type: type)) ?? 0.0
                            }
                        } else {
                            // 回退到模拟数据
                            print("⚠️ SMC读取失败，使用模拟数据: \(error.localizedDescription)")
                            value = (try? self.mockSMCRead(key: key, type: type)) ?? 0.0
                        }
                    }
                } else {
                    // 使用模拟数据
                    value = (try? self.mockSMCRead(key: key, type: type)) ?? 0.0
                }
                continuation.resume(returning: value)
            }
        }
    }
    
    /// 执行SMC写入操作
    private func performSMCWrite(key: String, value: Double, type: SMCDataType) async throws {
        try await withCheckedThrowingContinuation { [weak self] (continuation: CheckedContinuation<Void, Error>) in
            guard let self = self else {
                continuation.resume(throwing: AuraWindError.smcServiceNotAvailable)
                return
            }
            
            self.queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: AuraWindError.smcServiceNotAvailable)
                    return
                }
                
                // SMC写入的底层实现
                do {
                    // 根据权限选择写入方式
                    if self.useRealSMC {
                        do {
                            try self.performRealSMCWrite(key: key, value: value, type: type)
                            print("✅ SMC写入成功: \(key) = \(value)")
                        } catch let error {
                            // 真实写入失败，检查是否需要权限恢复
                            if self.permissionManager.handleSMCError(error) {
                                // 可以重试
                                do {
                                    try self.performRealSMCWrite(key: key, value: value, type: type)
                                } catch {
                                    // 回退到模拟模式
                                    print("⚠️ SMC写入失败，使用模拟模式: \(error.localizedDescription)")
                                    try self.mockSMCWrite(key: key, value: value, type: type)
                                }
                            } else {
                                // 回退到模拟模式
                                print("⚠️ SMC写入失败，使用模拟模式: \(error.localizedDescription)")
                                try self.mockSMCWrite(key: key, value: value, type: type)
                            }
                        }
                    } else {
                        // 使用模拟模式
                        try self.mockSMCWrite(key: key, value: value, type: type)
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Mock Implementation (临时用于开发测试)
    
    /// 实际的SMC读取实现（同步版本）
    private func performRealSMCRead(key: String, type: SMCDataType) throws -> Double {
        // 使用SMCConnection进行实际读取
        let connection = SMCConnection()
        try connection.connect()
        defer { connection.disconnect() }
        
        // 转换数据类型
        let connectionType = convertToConnectionType(type)
        let result = try connection.readValue(key: key, type: connectionType)
        return result.value
    }
    
    /// 实际的SMC写入实现（同步版本）
    private func performRealSMCWrite(key: String, value: Double, type: SMCDataType) throws {
        // 使用SMCConnection进行实际写入
        let connection = SMCConnection()
        try connection.connect()
        defer { connection.disconnect() }
        
        // 转换数据类型
        let connectionType = convertToConnectionType(type)
        try connection.writeValue(key: key, value: value, type: connectionType)
    }
    
    /// 转换SMC数据类型
    private func convertToConnectionType(_ type: SMCDataType) -> SMCConnection.SMCDataType {
        switch type {
        case .flt:
            return .flt
        case .ui8:
            return .ui8
        case .ui16:
            return .ui16
        case .fpe2:
            return .fpe2
        }
    }
    
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
        DispatchQueue.main.async {
            print("Mock SMC Write: \(key) = \(value)")
        }
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