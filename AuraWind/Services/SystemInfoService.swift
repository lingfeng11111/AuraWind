//
//  SystemInfoService.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025-11-17.
//

import Foundation
import IOKit
import MachO

/// 系统信息服务
/// 提供不依赖SMC的硬件信息获取
@MainActor
final class SystemInfoService {
    
    // MARK: - Properties
    
    /// 是否使用真实硬件数据
    private var useRealHardwareData: Bool = false
    
    /// 系统信息缓存
    private var systemInfoCache: [String: Any] = [:]
    
    // MARK: - Types
    
    struct SystemInfo {
        let cpuCores: Int
        let memoryGB: Double
        let diskSpaceGB: Double
        let osVersion: String
        let hardwareModel: String
    }
    
    // MARK: - Initialization
    
    init() {
        checkHardwareAccess()
    }
    
    // MARK: - Public Methods
    
    /// 获取系统基本信息
    func getSystemInfo() -> SystemInfo {
        let info = SystemInfo(
            cpuCores: ProcessInfo.processInfo.processorCount,
            memoryGB: getMemorySize(),
            diskSpaceGB: getDiskSpace(),
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            hardwareModel: getHardwareModel()
        )
        return info
    }
    
    /// 获取CPU使用率（使用系统API）
    func getCPUUsage() -> Double {
        // 使用host_statistics获取CPU使用率
        var cpuUsage: Double = 0.0
        
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let totalTicks = info.cpu_ticks.0 + info.cpu_ticks.1 + info.cpu_ticks.2 + info.cpu_ticks.3
            let idleTicks = info.cpu_ticks.3
            
            if totalTicks > 0 {
                cpuUsage = Double(totalTicks - idleTicks) / Double(totalTicks) * 100.0
            }
        }
        
        return cpuUsage
    }
    
    /// 获取内存使用情况
    func getMemoryUsage() -> (used: Double, total: Double) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: mach_msg_type_number_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let usedMemory = Double(info.resident_size) / 1024.0 / 1024.0 / 1024.0 // GB
            let totalMemory = getMemorySize()
            return (used: usedMemory, total: totalMemory)
        }
        
        return (used: 0, total: getMemorySize())
    }
    
    /// 获取温度信息（模拟数据）
    func getTemperatures() -> [TemperatureSensor] {
        // 由于SMC访问受限，提供基于CPU负载的模拟温度
        let cpuUsage = getCPUUsage()
        let baseTemp = 45.0
        let loadTemp = cpuUsage * 0.3 // 每1% CPU使用率增加0.3°C
        
        let cpuTemp = baseTemp + loadTemp + Double.random(in: -2...2)
        let ambientTemp = 25.0 + Double.random(in: -1...1)
        
        return [
            TemperatureSensor(
                type: .cpu,
                name: "CPU温度",
                currentTemperature: cpuTemp,
                maxTemperature: 100.0
            ),
            TemperatureSensor(
                type: .ambient,
                name: "环境温度",
                currentTemperature: ambientTemp,
                maxTemperature: 50.0
            )
        ]
    }
    
    /// 获取风扇信息（模拟数据）
    func getFanInfo() -> [Fan] {
        // 基于CPU使用率模拟风扇转速
        let cpuUsage = getCPUUsage()
        let baseSpeed = 1500
        let loadSpeed = Int(cpuUsage * 20) // 每1% CPU使用率增加20 RPM
        let currentSpeed = baseSpeed + loadSpeed + Int.random(in: -50...50)
        
        return [
            Fan(
                id: 0,
                name: "CPU风扇",
                currentSpeed: max(1200, min(6000, currentSpeed)),
                minSpeed: 1200,
                maxSpeed: 6000,
                targetSpeed: currentSpeed
            )
        ]
    }
    
    // MARK: - Private Methods
    
    private func checkHardwareAccess() {
        // 检查是否有硬件访问权限
        // 由于SMC访问受限，这里主要使用模拟数据
        useRealHardwareData = false
    }
    
    private func getMemorySize() -> Double {
        let memory = ProcessInfo.processInfo.physicalMemory
        return Double(memory) / 1024.0 / 1024.0 / 1024.0 // Convert to GB
    }
    
    private func getDiskSpace() -> Double {
        do {
            let fileURL = URL(fileURLWithPath: NSHomeDirectory())
            let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey])
            if let capacity = values.volumeTotalCapacity {
                return Double(capacity) / 1024.0 / 1024.0 / 1024.0 // Convert to GB
            }
        } catch {
            print("获取磁盘空间失败: \(error)")
        }
        return 256.0 // 默认值
    }
    
    private func getHardwareModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        
        return String(cString: model)
    }
}

// MARK: - 扩展现有模型

extension TemperatureSensor {
    init(type: SensorType, name: String, currentTemperature: Double, maxTemperature: Double) {
        self.id = UUID()
        self.type = type
        self.name = name
        self.currentTemperature = currentTemperature
        self.maxTemperature = maxTemperature
        self.readings = []
    }
}

extension Fan {
    init(id: Int, name: String, currentSpeed: Int, minSpeed: Int, maxSpeed: Int, targetSpeed: Int) {
        self.index = id
        self.id = UUID()
        self.name = name
        self.currentSpeed = currentSpeed
        self.minSpeed = minSpeed
        self.maxSpeed = maxSpeed
        self.targetSpeed = targetSpeed
        self.isManualControl = false
    }
}