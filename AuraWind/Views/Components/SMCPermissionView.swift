//
//  SMCPermissionView.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025-11-17.
//

import SwiftUI

/// SMC权限请求视图
struct SMCPermissionView: View {
    
    // MARK: - Properties
    
    @State private var permissionStatus: SMCPermissionManager.PermissionStatus = .unknown
    @State private var isCheckingPermissions = false
    @State private var showDetails = false
    
    let onPermissionGranted: (() -> Void)?
    
    // MARK: - Initialization
    
    init(onPermissionGranted: (() -> Void)? = nil) {
        self.onPermissionGranted = onPermissionGranted
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 20) {
            // 图标
            Image(systemName: "lock.shield")
                .font(.system(size: 64))
                .foregroundColor(permissionStatus.isAccessible ? .green : .orange)
                .symbolEffect(.pulse)
            
            // 标题
            Text("需要硬件访问权限")
                .font(.title2)
                .fontWeight(.bold)
            
            // 描述
            Text("AuraWind需要访问系统管理控制器(SMC)来读取温度传感器和控制风扇转速。这是确保系统正常运行的必要权限。")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            // 权限状态
            HStack {
                Image(systemName: permissionStatusIcon)
                    .foregroundColor(permissionStatusColor)
                
                Text("权限状态: \(permissionStatus.description)")
                    .font(.subheadline)
                
                if isCheckingPermissions {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.leading, 8)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            // 详细信息
            if showDetails {
                VStack(alignment: .leading, spacing: 8) {
                    Text("权限详情")
                        .font(.headline)
                    
                    Text(getPermissionDetails())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
            }
            
            // 按钮
            HStack(spacing: 12) {
                // 检查权限按钮
                Button(action: {
                    Task {
                        await checkPermissions()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("检查权限")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isCheckingPermissions)
                
                // 详细信息按钮
                Button(action: { showDetails.toggle() }) {
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                    Text(showDetails ? "隐藏详情" : "显示详情")
                }
                .buttonStyle(.bordered)
                
                // 继续按钮（如果权限已授予）
                if permissionStatus.isAccessible {
                    Button(action: continueToApp) {
                        HStack {
                            Text("继续")
                            Image(systemName: "arrow.right")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            Spacer()
            
            // 帮助信息
            Text("如果权限检查失败，请确保应用已正确签名并具有必要的entitlements。")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: 500)
        .onAppear {
            checkPermissionsOnAppear()
        }
    }
    
    // MARK: - Computed Properties
    
    private var permissionStatusIcon: String {
        switch permissionStatus {
        case .granted:
            return "checkmark.circle.fill"
        case .denied, .restricted:
            return "xmark.circle.fill"
        case .notDetermined, .unknown:
            return "questionmark.circle.fill"
        }
    }
    
    private var permissionStatusColor: Color {
        switch permissionStatus {
        case .granted:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined, .unknown:
            return .orange
        }
    }
    
    // MARK: - Methods
    
    private func checkPermissionsOnAppear() {
        Task {
            await checkPermissions()
        }
    }
    
    private func checkPermissions() async {
        isCheckingPermissions = true
        defer { isCheckingPermissions = false }
        
        let manager = SMCPermissionManager()
        permissionStatus = await manager.checkPermissions()
        
        if permissionStatus.isAccessible {
            // 延迟一下让用户看到成功状态
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            continueToApp()
        }
    }
    
    private func continueToApp() {
        onPermissionGranted?()
    }
    
    private func getPermissionDetails() -> String {
        switch permissionStatus {
        case .granted:
            return "✅ 应用已成功获得SMC访问权限，可以读取硬件传感器数据和控制风扇。"
            
        case .denied:
            return "❌ 权限被拒绝。请检查应用签名和entitlements配置，确保包含必要的SMC访问权限。"
            
        case .restricted:
            return "⚠️ 系统限制了对SMC的访问。这可能是由于系统策略或安全设置导致的。"
            
        case .notDetermined:
            return "❓ 权限状态未确定。请点击'检查权限'按钮来获取最新的权限状态。"
            
        case .unknown:
            return "❓ 无法确定权限状态。请确保应用已正确安装并具有必要的系统权限。"
        }
    }
}

// MARK: - Preview

#Preview {
    SMCPermissionView { 
        print("权限已授予，继续到应用")
    }
}