//
//  HelperToolProtocol.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025-11-17.
//

import Foundation

/// Helper Tool 的 XPC 协议
/// 定义主应用和特权助手之间的通信接口
@objc protocol HelperToolProtocol {
    
    // MARK: - SMC 连接管理
    
    /// 连接到 SMC
    /// - Parameter reply: 回调，返回是否成功和错误信息
    func connectToSMC(reply: @escaping (Bool, String?) -> Void)
    
    /// 断开 SMC 连接
    /// - Parameter reply: 回调
    func disconnectFromSMC(reply: @escaping () -> Void)
    
    // MARK: - SMC 读取操作
    
    /// 读取 SMC 键值
    /// - Parameters:
    ///   - key: SMC 键（4字符）
    ///   - reply: 回调，返回值和错误信息
    func readSMCKey(_ key: String, reply: @escaping (Double, String?) -> Void)
    
    /// 读取温度传感器
    /// - Parameters:
    ///   - sensorKey: 传感器键
    ///   - reply: 回调，返回温度值和错误信息
    func readTemperature(sensorKey: String, reply: @escaping (Double, String?) -> Void)
    
    /// 获取所有可用的温度传感器
    /// - Parameter reply: 回调，返回传感器键数组
    func getAllTemperatureSensors(reply: @escaping ([String], String?) -> Void)
    
    // MARK: - 风扇控制
    
    /// 获取风扇数量
    /// - Parameter reply: 回调，返回风扇数量和错误信息
    func getFanCount(reply: @escaping (Int, String?) -> Void)
    
    /// 读取风扇信息
    /// - Parameters:
    ///   - index: 风扇索引
    ///   - reply: 回调，返回风扇信息字典和错误信息
    func getFanInfo(index: Int, reply: @escaping ([String: Any]?, String?) -> Void)
    
    /// 设置风扇转速
    /// - Parameters:
    ///   - index: 风扇索引
    ///   - rpm: 目标转速
    ///   - reply: 回调，返回是否成功和错误信息
    func setFanSpeed(index: Int, rpm: Int, reply: @escaping (Bool, String?) -> Void)
    
    /// 设置风扇为自动模式
    /// - Parameters:
    ///   - index: 风扇索引
    ///   - reply: 回调，返回是否成功和错误信息
    func setFanAutoMode(index: Int, reply: @escaping (Bool, String?) -> Void)
    
    // MARK: - 系统信息
    
    /// 获取 Helper Tool 版本
    /// - Parameter reply: 回调，返回版本号
    func getVersion(reply: @escaping (String) -> Void)
    
    /// 检查 Helper Tool 状态
    /// - Parameter reply: 回调，返回状态信息
    func checkStatus(reply: @escaping ([String: Any]) -> Void)
}

/// Helper Tool 配置常量
enum HelperToolConstants {
    /// Helper Tool 的 Bundle ID
    static let helperToolBundleID = "com.aurawind.AuraWind.SMCHelper"
    
    /// Helper Tool 的 Mach Service 名称
    static let helperToolMachServiceName = "com.aurawind.AuraWind.SMCHelper"
    
    /// Helper Tool 版本
    static let helperToolVersion = "1.0.0"
    
    /// XPC 错误域
    static let xpcErrorDomain = "com.aurawind.AuraWind.XPCError"
}

/// XPC 错误类型
enum HelperToolError: Int, Error, LocalizedError {
    case connectionFailed = 1000
    case helperNotInstalled = 1001
    case authorizationFailed = 1002
    case smcAccessDenied = 1003
    case invalidParameters = 1004
    case operationFailed = 1005
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "无法连接到 Helper Tool"
        case .helperNotInstalled:
            return "Helper Tool 未安装"
        case .authorizationFailed:
            return "授权失败，需要管理员权限"
        case .smcAccessDenied:
            return "SMC 访问被拒绝"
        case .invalidParameters:
            return "无效的参数"
        case .operationFailed:
            return "操作失败"
        }
    }
}
