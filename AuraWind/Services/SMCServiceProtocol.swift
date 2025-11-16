//
//  SMCServiceProtocol.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025/11/16.
//

import Foundation

/// SMC 服务协议
protocol SMCServiceProtocol {
    // MARK: - 连接管理
    
    /// 连接到 SMC
    func connect() async throws
    
    /// 断开 SMC 连接
    func disconnect() async
    
    /// 是否已连接
    var isConnected: Bool { get }
    
    // MARK: - 温度监控
    
    /// 读取指定传感器的温度
    /// - Parameter sensor: 传感器类型
    /// - Returns: 温度值 (°C)
    func readTemperature(sensor: TemperatureSensorType) async throws -> Double
    
    /// 读取所有可用温度传感器
    /// - Returns: 温度传感器数组
    func getAllTemperatures() async throws -> [TemperatureSensor]
    
    // MARK: - 风扇控制
    
    /// 获取风扇数量
    /// - Returns: 风扇数量
    func getFanCount() async throws -> Int
    
    /// 获取风扇信息
    /// - Parameter index: 风扇索引
    /// - Returns: 风扇信息
    func getFanInfo(index: Int) async throws -> Fan
    
    /// 获取所有风扇信息
    /// - Returns: 风扇数组
    func getAllFans() async throws -> [Fan]
    
    /// 设置风扇转速
    /// - Parameters:
    ///   - index: 风扇索引
    ///   - rpm: 转速 (RPM)
    func setFanSpeed(index: Int, rpm: Int) async throws
    
    /// 设置风扇为自动模式
    /// - Parameter index: 风扇索引
    func setFanAutoMode(index: Int) async throws
    
    /// 获取风扇当前转速
    /// - Parameter index: 风扇索引
    /// - Returns: 当前转速 (RPM)
    func getFanCurrentSpeed(index: Int) async throws -> Int
    
    // MARK: - 硬件监控
    
    /// 获取 CPU 使用率
    /// - Returns: CPU 使用率 (0-100)
    func getCPUUsage() async throws -> Double
    
    /// 获取 GPU 使用率
    /// - Returns: GPU 使用率 (0-100)
    func getGPUUsage() async throws -> Double
    
    /// 获取内存使用情况
    /// - Returns: (已使用, 总容量) 单位 GB
    func getMemoryUsage() async throws -> (used: Double, total: Double)
}

// MARK: - 温度传感器类型

/// 温度传感器类型
enum TemperatureSensorType: String, CaseIterable {
    case cpuProximity = "TC0P"      // CPU 接近传感器
    case cpuDie = "TC0D"            // CPU 核心温度
    case cpuCore1 = "TC1C"          // CPU 核心 1
    case cpuCore2 = "TC2C"          // CPU 核心 2
    case gpuProximity = "TG0P"      // GPU 接近传感器
    case gpuDie = "TG0D"            // GPU 核心温度
    case ambient = "TA0P"           // 环境温度
    case palmRest = "Ts0P"          // 掌托温度
    case battery = "TB0T"           // 电池温度
    
    var smcKey: String {
        return rawValue
    }
    
    var displayName: String {
        switch self {
        case .cpuProximity:
            return "CPU 接近温度"
        case .cpuDie:
            return "CPU 核心温度"
        case .cpuCore1:
            return "CPU 核心 1"
        case .cpuCore2:
            return "CPU 核心 2"
        case .gpuProximity:
            return "GPU 接近温度"
        case .gpuDie:
            return "GPU 核心温度"
        case .ambient:
            return "环境温度"
        case .palmRest:
            return "掌托温度"
        case .battery:
            return "电池温度"
        }
    }
    
    var sensorType: TemperatureSensor.SensorType {
        switch self {
        case .cpuProximity, .cpuDie, .cpuCore1, .cpuCore2:
            return .cpu
        case .gpuProximity, .gpuDie:
            return .gpu
        case .ambient:
            return .ambient
        case .palmRest:
            return .proximity
        case .battery:
            return .cpu // 暂时归类为cpu
        }
    }
    
    var maxTemperature: Double {
        switch self {
        case .cpuProximity, .cpuDie, .cpuCore1, .cpuCore2:
            return 100.0
        case .gpuProximity, .gpuDie:
            return 100.0
        case .ambient:
            return 50.0
        case .palmRest:
            return 45.0
        case .battery:
            return 50.0
        }
    }
}

// MARK: - 风扇信息

/// 风扇基础信息（从硬件读取）
struct FanInfo {
    let index: Int
    let name: String
    let minSpeed: Int
    let maxSpeed: Int
    let currentSpeed: Int
    
    /// 转换为 Fan 模型
    func toFan() -> Fan {
        return Fan(
            index: index,
            name: name,
            currentSpeed: currentSpeed,
            minSpeed: minSpeed,
            maxSpeed: maxSpeed
        )
    }
}