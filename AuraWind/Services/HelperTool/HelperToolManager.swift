//
//  HelperToolManager.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025-11-17.
//

import Foundation
import ServiceManagement
import Security

/// Helper Tool 管理器
/// 负责安装、连接和管理特权助手工具
@MainActor
final class HelperToolManager {
    
    // MARK: - Singleton
    
    static let shared = HelperToolManager()
    
    // MARK: - Properties
    
    /// XPC 连接
    private var connection: NSXPCConnection?
    
    /// 是否已安装
    private(set) var isInstalled: Bool = false
    
    /// 是否已连接
    private(set) var isConnected: Bool = false
    
    /// Helper Tool 代理
    private var helperProxy: HelperToolProtocol?
    
    // MARK: - Initialization
    
    private init() {
        checkInstallation()
    }
    
    deinit {
        connection?.invalidate()
        connection = nil
    }
    
    // MARK: - Installation
    
    /// 检查 Helper Tool 是否已安装
    func checkInstallation() {
        // 尝试连接来检查是否已安装
        let testConnection = NSXPCConnection(machServiceName: HelperToolConstants.helperToolMachServiceName, options: .privileged)
        testConnection.remoteObjectInterface = NSXPCInterface(with: HelperToolProtocol.self)
        testConnection.resume()
        
        let proxy = testConnection.remoteObjectProxyWithErrorHandler { error in
            print("Helper Tool 未安装或无法连接: \(error)")
        } as? HelperToolProtocol
        
        proxy?.getVersion { version in
            print("Helper Tool 已安装，版本: \(version)")
            Task { @MainActor in
                self.isInstalled = true
            }
        }
        
        // 短暂延迟后关闭测试连接
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            testConnection.invalidate()
        }
    }
    
    /// 安装 Helper Tool
    /// - Throws: 安装错误
    func install() async throws {
        print("🔍 开始安装 Helper Tool...")
        
        // 检查 Helper Tool 是否在应用包中
        let helperPath = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/LaunchServices/\(HelperToolConstants.helperToolBundleID)")
        
        print("🔍 Helper Tool 路径: \(helperPath.path)")
        print("🔍 Helper Tool 存在: \(FileManager.default.fileExists(atPath: helperPath.path))")
        
        // 检查 Launchd.plist
        let launchdPath = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/LaunchServices/Launchd.plist")
        print("🔍 Launchd.plist 存在: \(FileManager.default.fileExists(atPath: launchdPath.path))")
        
        // 使用 SMJobBless 安装
        var authRef: AuthorizationRef?
        var authItem = AuthorizationItem(
            name: kSMRightBlessPrivilegedHelper,
            valueLength: 0,
            value: nil,
            flags: 0
        )
        
        var authRights = AuthorizationRights(count: 1, items: &authItem)
        let authFlags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]
        
        let status = AuthorizationCreate(&authRights, nil, authFlags, &authRef)
        
        guard status == errAuthorizationSuccess, let authRef = authRef else {
            throw HelperToolError.authorizationFailed
        }
        
        defer {
            AuthorizationFree(authRef, [])
        }
        
        // 执行 bless 操作
        var error: Unmanaged<CFError>?
        let success = SMJobBless(
            kSMDomainSystemLaunchd,
            HelperToolConstants.helperToolBundleID as CFString,
            authRef,
            &error
        )
        
        if let error = error?.takeRetainedValue() {
            print("安装失败: \(error)")
            throw error
        }
        
        guard success else {
            throw HelperToolError.helperNotInstalled
        }
        
        print("✅ Helper Tool 安装成功")
        isInstalled = true
        
        // 等待一下让 launchd 启动 helper
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }
    
    /// 卸载 Helper Tool（需要管理员权限）
    func uninstall() async throws {
        print("卸载 Helper Tool...")
        
        // 注意：SMJobBless 没有提供官方的卸载 API
        // 需要手动删除 /Library/PrivilegedHelperTools/ 下的文件
        // 这里提供一个简化的实现
        
        let helperPath = "/Library/PrivilegedHelperTools/\(HelperToolConstants.helperToolBundleID)"
        let launchPlistPath = "/Library/LaunchDaemons/\(HelperToolConstants.helperToolBundleID).plist"
        
        // 使用 shell 命令删除（需要 sudo）
        let script = """
        do shell script "launchctl unload '\(launchPlistPath)'" with administrator privileges
        do shell script "rm '\(helperPath)'" with administrator privileges
        do shell script "rm '\(launchPlistPath)'" with administrator privileges
        """
        
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            
            if let error = error {
                print("卸载失败: \(error)")
                throw HelperToolError.operationFailed
            }
        }
        
        isInstalled = false
        print("✅ Helper Tool 已卸载")
    }
    
    // MARK: - Connection Management
    
    /// 连接到 Helper Tool
    func connect() async throws {
        if !isInstalled {
            // 如果未安装，尝试安装
            try await install()
        }
        
        guard !isConnected else {
            print("已连接到 Helper Tool")
            return
        }
        
        print("连接到 Helper Tool...")
        
        // 创建 XPC 连接
        let newConnection = NSXPCConnection(
            machServiceName: HelperToolConstants.helperToolMachServiceName,
            options: .privileged
        )
        
        newConnection.remoteObjectInterface = NSXPCInterface(with: HelperToolProtocol.self)
        
        newConnection.interruptionHandler = { [weak self] in
            print("XPC 连接中断")
            Task { @MainActor in
                self?.isConnected = false
                self?.helperProxy = nil
            }
        }
        
        newConnection.invalidationHandler = { [weak self] in
            print("XPC 连接失效")
            Task { @MainActor in
                self?.isConnected = false
                self?.helperProxy = nil
                self?.connection = nil
            }
        }
        
        newConnection.resume()
        
        connection = newConnection
        helperProxy = newConnection.remoteObjectProxyWithErrorHandler { error in
            print("XPC 代理错误: \(error)")
        } as? HelperToolProtocol
        
        // 验证连接
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            helperProxy?.getVersion { version in
                print("✅ 已连接到 Helper Tool，版本: \(version)")
                Task { @MainActor in
                    self.isConnected = true
                }
                continuation.resume()
            }
        }
    }
    
    /// 断开连接
    func disconnect() {
        print("断开 Helper Tool 连接...")
        
        connection?.invalidate()
        connection = nil
        helperProxy = nil
        isConnected = false
    }
    
    // MARK: - SMC Operations
    
    /// 连接到 SMC
    func connectToSMC() async throws {
        guard isConnected, let proxy = helperProxy else {
            throw HelperToolError.connectionFailed
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            proxy.connectToSMC { success, errorMessage in
                if success {
                    continuation.resume()
                } else {
                    let error = NSError(
                        domain: HelperToolConstants.xpcErrorDomain,
                        code: HelperToolError.smcAccessDenied.rawValue,
                        userInfo: [NSLocalizedDescriptionKey: errorMessage ?? "未知错误"]
                    )
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 断开 SMC 连接
    func disconnectFromSMC() async {
        guard isConnected, let proxy = helperProxy else { return }
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            proxy.disconnectFromSMC {
                continuation.resume()
            }
        }
    }
    
    /// 读取 SMC 键值
    func readSMCKey(_ key: String) async throws -> Double {
        guard isConnected, let proxy = helperProxy else {
            throw HelperToolError.connectionFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            proxy.readSMCKey(key) { value, errorMessage in
                if let errorMessage = errorMessage {
                    let error = NSError(
                        domain: HelperToolConstants.xpcErrorDomain,
                        code: HelperToolError.operationFailed.rawValue,
                        userInfo: [NSLocalizedDescriptionKey: errorMessage]
                    )
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: value)
                }
            }
        }
    }
    
    /// 读取温度
    func readTemperature(sensorKey: String) async throws -> Double {
        guard isConnected, let proxy = helperProxy else {
            throw HelperToolError.connectionFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            proxy.readTemperature(sensorKey: sensorKey) { value, errorMessage in
                if let errorMessage = errorMessage {
                    let error = NSError(
                        domain: HelperToolConstants.xpcErrorDomain,
                        code: HelperToolError.operationFailed.rawValue,
                        userInfo: [NSLocalizedDescriptionKey: errorMessage]
                    )
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: value)
                }
            }
        }
    }
    
    /// 获取所有温度传感器
    func getAllTemperatureSensors() async throws -> [String] {
        guard isConnected, let proxy = helperProxy else {
            throw HelperToolError.connectionFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            proxy.getAllTemperatureSensors { sensors, errorMessage in
                if let errorMessage = errorMessage {
                    let error = NSError(
                        domain: HelperToolConstants.xpcErrorDomain,
                        code: HelperToolError.operationFailed.rawValue,
                        userInfo: [NSLocalizedDescriptionKey: errorMessage]
                    )
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: sensors)
                }
            }
        }
    }
    
    /// 获取风扇数量
    func getFanCount() async throws -> Int {
        guard isConnected, let proxy = helperProxy else {
            throw HelperToolError.connectionFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            proxy.getFanCount { count, errorMessage in
                if let errorMessage = errorMessage {
                    let error = NSError(
                        domain: HelperToolConstants.xpcErrorDomain,
                        code: HelperToolError.operationFailed.rawValue,
                        userInfo: [NSLocalizedDescriptionKey: errorMessage]
                    )
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: count)
                }
            }
        }
    }
    
    /// 获取风扇信息
    func getFanInfo(index: Int) async throws -> [String: Any] {
        guard isConnected, let proxy = helperProxy else {
            throw HelperToolError.connectionFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            proxy.getFanInfo(index: index) { info, errorMessage in
                if let errorMessage = errorMessage {
                    let error = NSError(
                        domain: HelperToolConstants.xpcErrorDomain,
                        code: HelperToolError.operationFailed.rawValue,
                        userInfo: [NSLocalizedDescriptionKey: errorMessage]
                    )
                    continuation.resume(throwing: error)
                } else if let info = info {
                    continuation.resume(returning: info)
                } else {
                    let error = NSError(
                        domain: HelperToolConstants.xpcErrorDomain,
                        code: HelperToolError.operationFailed.rawValue,
                        userInfo: [NSLocalizedDescriptionKey: "无法获取风扇信息"]
                    )
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 设置风扇转速
    func setFanSpeed(index: Int, rpm: Int) async throws {
        guard isConnected, let proxy = helperProxy else {
            throw HelperToolError.connectionFailed
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            proxy.setFanSpeed(index: index, rpm: rpm) { success, errorMessage in
                if success {
                    continuation.resume()
                } else {
                    let error = NSError(
                        domain: HelperToolConstants.xpcErrorDomain,
                        code: HelperToolError.operationFailed.rawValue,
                        userInfo: [NSLocalizedDescriptionKey: errorMessage ?? "设置风扇转速失败"]
                    )
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 设置风扇为自动模式
    func setFanAutoMode(index: Int) async throws {
        guard isConnected, let proxy = helperProxy else {
            throw HelperToolError.connectionFailed
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            proxy.setFanAutoMode(index: index) { success, errorMessage in
                if success {
                    continuation.resume()
                } else {
                    let error = NSError(
                        domain: HelperToolConstants.xpcErrorDomain,
                        code: HelperToolError.operationFailed.rawValue,
                        userInfo: [NSLocalizedDescriptionKey: errorMessage ?? "设置自动模式失败"]
                    )
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 检查 Helper Tool 状态
    func checkStatus() async throws -> [String: Any] {
        guard isConnected, let proxy = helperProxy else {
            throw HelperToolError.connectionFailed
        }
        
        return await withCheckedContinuation { continuation in
            proxy.checkStatus { status in
                continuation.resume(returning: status)
            }
        }
    }
}
