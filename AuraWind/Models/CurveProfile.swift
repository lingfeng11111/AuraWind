//
//  CurveProfile.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025/11/16.
//

import Foundation

/// 温度-转速曲线配置
struct CurveProfile: Identifiable, Codable, Equatable {
    /// 唯一标识符
    let id: UUID
    
    /// 曲线名称
    var name: String
    
    /// 曲线点集合
    var points: [CurvePoint]
    
    /// 是否激活
    var isActive: Bool
    
    /// 创建时间
    var createdAt: Date
    
    /// 更新时间
    var updatedAt: Date
    
    /// 曲线描述
    var description: String?
    
    // MARK: - 初始化
    
    init(
        id: UUID = UUID(),
        name: String,
        points: [CurvePoint],
        isActive: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        description: String? = nil
    ) {
        self.id = id
        self.name = name
        self.points = points
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.description = description
    }
    
    // MARK: - 曲线点
    
    /// 曲线点
    struct CurvePoint: Codable, Equatable, Identifiable {
        let id: UUID
        
        /// 温度 (°C)
        var temperature: Double
        
        /// 风扇转速 (RPM)
        var fanSpeed: Int
        
        init(
            id: UUID = UUID(),
            temperature: Double,
            fanSpeed: Int
        ) {
            self.id = id
            self.temperature = temperature
            self.fanSpeed = fanSpeed
        }
    }
    
    // MARK: - 插值算法
    
    /// 根据温度插值计算风扇转速
    /// - Parameter temperature: 当前温度
    /// - Returns: 计算得到的转速
    func interpolateFanSpeed(for temperature: Double) -> Int {
        // 确保点按温度排序
        let sortedPoints = points.sorted { $0.temperature < $1.temperature }
        
        // 边界情况处理
        guard let first = sortedPoints.first,
              let last = sortedPoints.last else {
            return Constants.Fan.defaultSpeed
        }
        
        // 低于最低温度，返回最低转速
        if temperature <= first.temperature {
            return first.fanSpeed
        }
        
        // 高于最高温度，返回最高转速
        if temperature >= last.temperature {
            return last.fanSpeed
        }
        
        // 线性插值
        for i in 0..<(sortedPoints.count - 1) {
            let p1 = sortedPoints[i]
            let p2 = sortedPoints[i + 1]
            
            if temperature >= p1.temperature && temperature <= p2.temperature {
                let ratio = (temperature - p1.temperature) / (p2.temperature - p1.temperature)
                let speedDiff = Double(p2.fanSpeed - p1.fanSpeed)
                let interpolatedSpeed = Double(p1.fanSpeed) + (speedDiff * ratio)
                return Int(interpolatedSpeed.rounded())
            }
        }
        
        return Constants.Fan.defaultSpeed
    }
    
    // MARK: - 验证
    
    /// 验证曲线配置的有效性
    /// - Returns: 验证结果
    func validate() -> Result<Void, CurveValidationError> {
        // 检查点数
        guard points.count >= 2 else {
            return .failure(.tooFewPoints)
        }
        
        guard points.count <= 10 else {
            return .failure(.tooManyPoints)
        }
        
        // 检查每个点的有效性
        for point in points {
            // 温度范围检查
            if point.temperature < Constants.Temperature.minValue ||
               point.temperature > Constants.Temperature.maxValue {
                return .failure(.invalidTemperature(point.temperature))
            }
            
            // 转速检查
            if point.fanSpeed < 0 {
                return .failure(.invalidSpeed(point.fanSpeed))
            }
        }
        
        // 检查是否有重复的温度点
        let temperatures = points.map { $0.temperature }
        let uniqueTemperatures = Set(temperatures)
        if temperatures.count != uniqueTemperatures.count {
            return .failure(.duplicateTemperature)
        }
        
        return .success(())
    }
    
    /// 是否有效
    var isValid: Bool {
        switch validate() {
        case .success:
            return true
        case .failure:
            return false
        }
    }
    
    // MARK: - 辅助方法
    
    /// 添加曲线点
    /// - Parameter point: 曲线点
    mutating func addPoint(_ point: CurvePoint) {
        points.append(point)
        updatedAt = Date()
    }
    
    /// 移除曲线点
    /// - Parameter id: 点的 ID
    mutating func removePoint(withId id: UUID) {
        points.removeAll { $0.id == id }
        updatedAt = Date()
    }
    
    /// 更新曲线点
    /// - Parameters:
    ///   - id: 点的 ID
    ///   - temperature: 新温度
    ///   - fanSpeed: 新转速
    mutating func updatePoint(withId id: UUID, temperature: Double, fanSpeed: Int) {
        if let index = points.firstIndex(where: { $0.id == id }) {
            points[index].temperature = temperature
            points[index].fanSpeed = fanSpeed
            updatedAt = Date()
        }
    }
    
    /// 排序后的点集合
    var sortedPoints: [CurvePoint] {
        return points.sorted { $0.temperature < $1.temperature }
    }
}

// MARK: - 曲线验证错误

enum CurveValidationError: LocalizedError {
    case tooFewPoints
    case tooManyPoints
    case invalidTemperature(Double)
    case invalidSpeed(Int)
    case duplicateTemperature
    
    var errorDescription: String? {
        switch self {
        case .tooFewPoints:
            return "曲线至少需要 2 个点"
        case .tooManyPoints:
            return "曲线最多支持 10 个点"
        case .invalidTemperature(let temp):
            return "无效的温度值: \(temp)°C"
        case .invalidSpeed(let speed):
            return "无效的转速值: \(speed) RPM"
        case .duplicateTemperature:
            return "存在重复的温度点"
        }
    }
}

// MARK: - 预设曲线

extension CurveProfile {
    /// 静音模式曲线
    static let silent = CurveProfile(
        name: "静音模式",
        points: [
            CurvePoint(temperature: 40, fanSpeed: 1200),
            CurvePoint(temperature: 60, fanSpeed: 1800),
            CurvePoint(temperature: 80, fanSpeed: 2500),
            CurvePoint(temperature: 90, fanSpeed: 3200)
        ],
        description: "优先降低噪音，适合办公和日常使用"
    )
    
    /// 平衡模式曲线
    static let balanced = CurveProfile(
        name: "平衡模式",
        points: [
            CurvePoint(temperature: 40, fanSpeed: 1500),
            CurvePoint(temperature: 60, fanSpeed: 2500),
            CurvePoint(temperature: 75, fanSpeed: 3500),
            CurvePoint(temperature: 85, fanSpeed: 4500)
        ],
        description: "平衡性能和噪音，适合大多数场景"
    )
    
    /// 性能模式曲线
    static let performance = CurveProfile(
        name: "性能模式",
        points: [
            CurvePoint(temperature: 40, fanSpeed: 2000),
            CurvePoint(temperature: 55, fanSpeed: 3000),
            CurvePoint(temperature: 70, fanSpeed: 4500),
            CurvePoint(temperature: 80, fanSpeed: 5500)
        ],
        description: "优先散热性能，适合高负载工作"
    )
    
    /// 示例曲线
    static let example = balanced
    
    /// 所有预设曲线
    static let presets = [silent, balanced, performance]
}