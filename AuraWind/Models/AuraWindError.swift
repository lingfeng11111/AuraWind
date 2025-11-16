//
//  AuraWindError.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025/11/16.
//

import Foundation

/// AuraWind 应用错误类型
enum AuraWindError: LocalizedError {
    // MARK: - SMC 相关错误
    
    case smcServiceNotFound
    case smcServiceNotAvailable
    case smcConnectionFailed
    case smcNotConnected
    case smcReadFailed
    case smcWriteFailed
    case smcAccessDenied
    
    // MARK: - 风扇相关错误
    
    case fanNotFound(Int)
    case fanControlFailed(Error)
    case invalidSpeed(Int)
    case fanSpeedOutOfRange(Int, Int, Int) // speed, min, max
    case fanIndexOutOfRange
    
    // MARK: - 温度传感器相关错误
    
    case temperatureSensorFailed
    case sensorNotFound(String)
    case invalidTemperature(Double)
    
    // MARK: - 数据持久化错误
    
    case persistenceError(Error)
    case documentDirectoryNotFound
    case fileReadError(Error)
    case fileWriteError(Error)
    case decodingError(Error)
    case encodingError(Error)
    
    // MARK: - 曲线配置错误
    
    case invalidCurveProfile
    case curvePointsInsufficient
    case curvePointsExceeded
    
    // MARK: - 通用错误
    
    case unknownError(Error)
    case invalidConfiguration
    case operationCancelled
    
    // MARK: - LocalizedError 实现
    
    var errorDescription: String? {
        switch self {
        // SMC 错误
        case .smcServiceNotFound:
            return "无法找到 SMC 服务"
        case .smcServiceNotAvailable:
            return "SMC 服务不可用"
        case .smcConnectionFailed:
            return "连接 SMC 失败"
        case .smcNotConnected:
            return "SMC 未连接"
        case .smcReadFailed:
            return "读取 SMC 数据失败"
        case .smcWriteFailed:
            return "写入 SMC 数据失败"
        case .smcAccessDenied:
            return "无法访问 SMC，请检查权限设置"
            
        // 风扇错误
        case .fanNotFound(let index):
            return "未找到风扇设备 (索引: \(index))"
        case .fanControlFailed(let error):
            return "风扇控制失败: \(error.localizedDescription)"
        case .invalidSpeed(let speed):
            return "无效的转速值: \(speed) RPM"
        case .fanSpeedOutOfRange(let speed, let min, let max):
            return "转速 \(speed) RPM 超出范围 (\(min)-\(max) RPM)"
        case .fanIndexOutOfRange:
            return "风扇索引超出范围"
            
        // 温度传感器错误
        case .temperatureSensorFailed:
            return "温度传感器读取失败"
        case .sensorNotFound(let name):
            return "未找到传感器: \(name)"
        case .invalidTemperature(let temp):
            return "无效的温度值: \(temp)°C"
            
        // 持久化错误
        case .persistenceError(let error):
            return "数据持久化失败: \(error.localizedDescription)"
        case .documentDirectoryNotFound:
            return "无法找到文档目录"
        case .fileReadError(let error):
            return "文件读取失败: \(error.localizedDescription)"
        case .fileWriteError(let error):
            return "文件写入失败: \(error.localizedDescription)"
        case .decodingError(let error):
            return "数据解码失败: \(error.localizedDescription)"
        case .encodingError(let error):
            return "数据编码失败: \(error.localizedDescription)"
            
        // 曲线配置错误
        case .invalidCurveProfile:
            return "无效的曲线配置"
        case .curvePointsInsufficient:
            return "曲线点数不足，至少需要 2 个点"
        case .curvePointsExceeded:
            return "曲线点数过多，最多支持 10 个点"
            
        // 通用错误
        case .unknownError(let error):
            return "未知错误: \(error.localizedDescription)"
        case .invalidConfiguration:
            return "无效的配置"
        case .operationCancelled:
            return "操作已取消"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .smcAccessDenied:
            return "应用需要访问系统管理控制器 (SMC) 来读取温度和控制风扇"
        case .fanControlFailed:
            return "可能是由于权限不足或硬件不支持"
        case .temperatureSensorFailed:
            return "可能是由于传感器不存在或硬件故障"
        default:
            return nil
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .smcAccessDenied:
            return "请在系统设置中授予应用必要的权限"
        case .smcConnectionFailed, .smcServiceNotFound:
            return "请重启应用或重启计算机后重试"
        case .fanControlFailed:
            return "请检查风扇连接状态，或尝试重启应用"
        case .temperatureSensorFailed:
            return "请检查硬件连接，或尝试重启应用"
        case .invalidSpeed:
            return "请输入有效的转速值（1000-6000 RPM）"
        case .invalidTemperature:
            return "请检查温度传感器是否正常工作"
        case .persistenceError, .fileReadError, .fileWriteError:
            return "请检查磁盘空间和文件权限"
        case .curvePointsInsufficient:
            return "请至少添加 2 个曲线点"
        case .curvePointsExceeded:
            return "请减少曲线点数至 10 个以内"
        default:
            return "请重试或联系技术支持"
        }
    }
}