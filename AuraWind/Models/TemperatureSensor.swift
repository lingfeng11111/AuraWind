//
//  TemperatureSensor.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025/11/16.
//

import Foundation

/// 温度传感器模型
struct TemperatureSensor: Identifiable, Codable, Equatable {
    /// 唯一标识符
    let id: UUID
    
    /// 传感器类型
    var type: SensorType
    
    /// 传感器名称
    var name: String
    
    /// 当前温度 (°C)
    var currentTemperature: Double
    
    /// 最大安全温度 (°C)
    var maxTemperature: Double
    
    /// 历史读数
    var readings: [TemperatureReading]
    
    /// SMC 键名（用于硬件层访问）
    var smcKey: String?
    
    // MARK: - 初始化
    
    init(
        id: UUID = UUID(),
        type: SensorType,
        name: String,
        currentTemperature: Double = 0,
        maxTemperature: Double = 100,
        readings: [TemperatureReading] = [],
        smcKey: String? = nil
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.currentTemperature = currentTemperature
        self.maxTemperature = maxTemperature
        self.readings = readings
        self.smcKey = smcKey
    }
    
    // MARK: - 计算属性
    
    /// 温度百分比 (0-100)
    var temperaturePercentage: Double {
        guard maxTemperature > 0 else { return 0 }
        return (currentTemperature / maxTemperature) * 100
    }
    
    /// 温度状态
    var status: TemperatureStatus {
        let percentage = temperaturePercentage
        if percentage >= 95 {
            return .critical
        } else if percentage >= 85 {
            return .warning
        } else if percentage >= 70 {
            return .elevated
        } else {
            return .normal
        }
    }
    
    /// 是否需要警告
    var isWarning: Bool {
        return currentTemperature > maxTemperature * 0.85
    }
    
    /// 是否危险
    var isCritical: Bool {
        return currentTemperature > maxTemperature * 0.95
    }
    
    // MARK: - 方法
    
    /// 添加温度读数
    /// - Parameter reading: 温度读数
    mutating func addReading(_ reading: TemperatureReading) {
        readings.append(reading)
        // 保持最多 100 条记录
        if readings.count > 100 {
            readings.removeFirst()
        }
    }
    
    /// 添加当前温度读数
    mutating func addCurrentReading() {
        let reading = TemperatureReading(
            timestamp: Date(),
            value: currentTemperature
        )
        addReading(reading)
    }
    
    /// 获取指定时间范围内的读数
    /// - Parameter duration: 时间范围
    /// - Returns: 温度读数数组
    func readings(in duration: TimeInterval) -> [TemperatureReading] {
        let cutoffDate = Date().addingTimeInterval(-duration)
        return readings.filter { $0.timestamp >= cutoffDate }
    }
    
    /// 格式化的温度字符串
    var formattedTemperature: String {
        return String(format: "%.1f°C", currentTemperature)
    }
    
    /// 平均温度
    var averageTemperature: Double {
        guard !readings.isEmpty else { return currentTemperature }
        let sum = readings.reduce(0.0) { $0 + $1.value }
        return sum / Double(readings.count)
    }
}

// MARK: - 传感器类型

extension TemperatureSensor {
    /// 传感器类型枚举
    enum SensorType: String, Codable, CaseIterable {
        case cpu = "CPU"
        case gpu = "GPU"
        case ambient = "环境"
        case proximity = "接近"
        case battery = "电池"
        case ssd = "固态硬盘"
        case thunderbolt = "雷雳接口"
        
        var description: String {
            return rawValue
        }
        
        /// 获取对应的 SF Symbol 图标
        var iconName: String {
            switch self {
            case .cpu:
                return "cpu.fill"
            case .gpu:
                return "sparkles"
            case .ambient:
                return "thermometer"
            case .proximity:
                return "sensor.fill"
            case .battery:
                return "battery.100"
            case .ssd:
                return "internaldrive.fill"
            case .thunderbolt:
                return "bolt.fill"
            }
        }
    }
    
    /// 温度状态
    enum TemperatureStatus: String, Codable {
        case normal = "正常"
        case elevated = "偏高"
        case warning = "警告"
        case critical = "危险"
        
        var description: String {
            return rawValue
        }
    }
}

// MARK: - 温度读数

/// 温度读数
struct TemperatureReading: Identifiable, Codable, Equatable {
    /// 唯一标识符
    let id: UUID
    
    /// 读取时间
    var timestamp: Date
    
    /// 温度值 (°C)
    var value: Double
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        value: Double
    ) {
        self.id = id
        self.timestamp = timestamp
        self.value = value
    }
}

// MARK: - 示例数据

extension TemperatureSensor {
    /// 示例传感器
    static let example = TemperatureSensor(
        type: .cpu,
        name: "CPU 核心温度",
        currentTemperature: 65.5,
        maxTemperature: 100,
        readings: [],
        smcKey: "TC0P"
    )
    
    /// 多个示例传感器
    static let examples = [
        TemperatureSensor(
            type: .cpu,
            name: "CPU 核心温度",
            currentTemperature: 65.5,
            maxTemperature: 100,
            smcKey: "TC0P"
        ),
        TemperatureSensor(
            type: .gpu,
            name: "GPU 核心温度",
            currentTemperature: 72.0,
            maxTemperature: 95,
            smcKey: "TG0P"
        ),
        TemperatureSensor(
            type: .ambient,
            name: "环境温度",
            currentTemperature: 35.2,
            maxTemperature: 50,
            smcKey: "TA0P"
        )
    ]
}