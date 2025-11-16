//
//  Fan.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025/11/16.
//

import Foundation

/// 风扇模型
struct Fan: Identifiable, Codable, Equatable {
    /// 唯一标识符
    let id: UUID
    
    /// 风扇索引（硬件层标识）
    var index: Int
    
    /// 风扇名称
    var name: String
    
    /// 当前转速 (RPM)
    var currentSpeed: Int
    
    /// 最小转速 (RPM)
    var minSpeed: Int
    
    /// 最大转速 (RPM)
    var maxSpeed: Int
    
    /// 是否手动控制模式
    var isManualControl: Bool
    
    /// 目标转速 (RPM，仅在手动模式下使用)
    var targetSpeed: Int?
    
    // MARK: - 初始化
    
    init(
        id: UUID = UUID(),
        index: Int,
        name: String,
        currentSpeed: Int = 0,
        minSpeed: Int = Constants.Fan.minSpeed,
        maxSpeed: Int = Constants.Fan.maxSpeed,
        isManualControl: Bool = false,
        targetSpeed: Int? = nil
    ) {
        self.id = id
        self.index = index
        self.name = name
        self.currentSpeed = currentSpeed
        self.minSpeed = minSpeed
        self.maxSpeed = maxSpeed
        self.isManualControl = isManualControl
        self.targetSpeed = targetSpeed
    }
    
    // MARK: - 计算属性
    
    /// 转速百分比 (0-100)
    var speedPercentage: Double {
        let range = Double(maxSpeed - minSpeed)
        guard range > 0 else { return 0 }
        let current = Double(currentSpeed - minSpeed)
        return (current / range) * 100
    }
    
    /// 风扇状态
    var status: FanStatus {
        if currentSpeed == 0 {
            return .stopped
        } else if currentSpeed < minSpeed + (maxSpeed - minSpeed) / 3 {
            return .low
        } else if currentSpeed < minSpeed + (maxSpeed - minSpeed) * 2 / 3 {
            return .medium
        } else {
            return .high
        }
    }
    
    // MARK: - 方法
    
    /// 检查转速是否在有效范围内
    /// - Parameter speed: 转速值
    /// - Returns: 是否有效
    func isSpeedInRange(_ speed: Int) -> Bool {
        return speed >= minSpeed && speed <= maxSpeed
    }
    
    /// 格式化的转速字符串
    var formattedSpeed: String {
        return "\(currentSpeed) RPM"
    }
    
    /// 格式化的转速百分比字符串
    var formattedPercentage: String {
        return String(format: "%.0f%%", speedPercentage)
    }
}

// MARK: - 风扇状态枚举

extension Fan {
    /// 风扇运行状态
    enum FanStatus: String, Codable {
        case stopped = "停止"
        case low = "低速"
        case medium = "中速"
        case high = "高速"
        
        var description: String {
            return rawValue
        }
    }
}

// MARK: - 示例数据

extension Fan {
    /// 示例风扇数据（用于预览和测试）
    static let example = Fan(
        id: UUID(),
        index: 0,
        name: "CPU 风扇",
        currentSpeed: 2500,
        minSpeed: 1000,
        maxSpeed: 6000,
        isManualControl: false
    )
    
    /// 多个示例风扇
    static let examples = [
        Fan(index: 0, name: "CPU 风扇", currentSpeed: 2500),
        Fan(index: 1, name: "GPU 风扇", currentSpeed: 3000),
        Fan(index: 2, name: "系统风扇", currentSpeed: 2000)
    ]
}