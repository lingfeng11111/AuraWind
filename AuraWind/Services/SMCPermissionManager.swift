//
//  SMCPermissionManager.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025-11-17.
//

import Foundation

/// SMC权限管理器
/// 负责处理SMC访问权限和错误恢复
final class SMCPermissionManager {
    
    // MARK: - Properties
    
    /// 权限状态
    private(set) var permissionStatus: PermissionStatus = .unknown
    
    /// 权限检查完成回调
    var onPermissionStatusChanged: ((PermissionStatus) -> Void)?
    
    // MARK: - Types
    
    /// 权限状态
    enum PermissionStatus {
        case unknown
        case granted
        case denied
        case restricted
        case notDetermined
        
        var description: String {
            switch self {
            case .unknown:
                return "未知"
            case .granted:
                return "已授权"
            case .denied:
                return "被拒绝"
            case .restricted:
                return "受限制"
            case .notDetermined:
                return "未确定"
            }
        }
        
        var isAccessible: Bool {
            switch self {
            case .granted:
                return true
            case .denied, .restricted, .notDetermined, .unknown:
                return false
            }
        }
    }
    
    // MARK: - Permission Management
    
    /// 检查SMC访问权限
    func checkPermissions() async -> PermissionStatus {
        do {
            // 尝试连接SMC来检查权限
            let connection = SMCConnection()
            try connection.connect()
            connection.disconnect()
            
            permissionStatus = .granted
            onPermissionStatusChanged?(.granted)
            return .granted
            
        } catch let error as AuraWindError {
            switch error {
            case .smcAccessDenied, .smcConnectionFailed:
                permissionStatus = .denied
                onPermissionStatusChanged?(.denied)
                return .denied
                
            case .smcServiceNotFound:
                permissionStatus = .restricted
                onPermissionStatusChanged?(.restricted)
                return .restricted
                
            default:
                permissionStatus = .unknown
                onPermissionStatusChanged?(.unknown)
                return .unknown
            }
        } catch {
            permissionStatus = .unknown
            onPermissionStatusChanged?(.unknown)
            return .unknown
        }
    }
    
    /// 请求SMC访问权限
    func requestPermissions() async -> PermissionStatus {
        // 在macOS上，SMC访问权限通常需要：
        // 1. 应用签名
        // 2. 特定的entitlements
        // 3. 用户授权
        
        let status = await checkPermissions()
        
        if status == .denied || status == .restricted {
            // 显示权限请求UI
            showPermissionRequestAlert()
        }
        
        return status
    }
    
    /// 显示权限请求提示
    private func showPermissionRequestAlert() {
        // 这里可以集成SwiftUI的Alert或NSAlert
        // 暂时使用日志输出
        print("""
        ⚠️ SMC权限请求
        应用需要访问系统管理控制器(SMC)来读取温度和控制风扇。
        
        请确保：
        1. 应用已正确签名
        2. 具有必要的entitlements
        3. 在系统设置中授予硬件访问权限
        
        重启应用后重试。
        """)
    }
    
    // MARK: - Error Recovery
    
    /// 处理SMC错误并尝试恢复
    func handleSMCError(_ error: Error) -> Bool {
        print("🔄 处理SMC错误: \(error.localizedDescription)")
        
        if let auraError = error as? AuraWindError {
            switch auraError {
            case .smcAccessDenied:
                // 权限被拒绝，尝试重新请求
                Task {
                    _ = await requestPermissions()
                }
                return false
                
            case .smcConnectionFailed, .smcServiceNotFound:
                // 连接失败，等待后重试
                DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                    Task {
                        _ = await self.checkPermissions()
                    }
                }
                return false
                
            case .smcReadFailed, .smcWriteFailed:
                // 读写失败，可能是临时问题
                return true // 可以重试
                
            default:
                return false
            }
        }
        
        return false
    }
    
    /// 获取权限帮助信息
    func getPermissionHelp() -> String {
        return """
        要解决SMC访问权限问题，请尝试以下步骤：
        
        1. 确保应用已正确签名：
           - 使用有效的开发者证书
           - 启用 hardened runtime
        
        2. 添加必要的entitlements：
           - com.apple.security.temporary-exception.sbpl
           - 允许IOKit通信
        
        3. 系统设置：
           - 检查系统完整性保护(SIP)状态
           - 确保没有其他安全软件阻止访问
        
        4. 重启应用和系统服务
        
        5. 如果问题持续，请联系技术支持
        """
    }
    
    // MARK: - Entitlements Management
    
    /// 检查应用entitlements
    func checkEntitlements() -> [String: Any]? {
        // 获取应用路径
        guard let appPath = Bundle.main.executablePath else {
            return nil
        }
        
        // 使用codesign检查entitlements
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        task.arguments = ["-d", "--entitlements", "-", appPath]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let xmlString = String(data: data, encoding: .utf8) {
                // 解析XML格式的entitlements
                return parseEntitlementsXML(xmlString)
            }
        } catch {
            print("检查entitlements失败: \(error)")
        }
        
        return nil
    }
    
    /// 解析entitlements XML
    private func parseEntitlementsXML(_ xml: String) -> [String: Any]? {
        // 简化的XML解析，实际项目中可以使用XMLParser
        var entitlements: [String: Any] = [:]
        
        // 检查关键的SMC相关entitlements
        if xml.contains("com.apple.security.temporary-exception.sbpl") {
            entitlements["hasSBPL"] = true
        }
        
        if xml.contains("com.apple.security.temporary-exception.iokit-user-client-class") {
            entitlements["hasIOKitException"] = true
        }
        
        return entitlements.isEmpty ? nil : entitlements
    }
    
    /// 建议的entitlements列表
    func getRecommendedEntitlements() -> String {
        return """
        建议的entitlements配置：
        
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>com.apple.security.temporary-exception.sbpl</key>
            <array>
                <string>(allow iokit-open (iokit-connection "AppleSMC"))</string>
                <string>(allow iokit-set-properties (iokit-connection "AppleSMC"))</string>
            </array>
        </dict>
        </plist>
        """
    }
}