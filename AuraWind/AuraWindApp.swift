//
//  AuraWindApp.swift
//  AuraWind
//
//  Created by 凌峰 on 2025/11/16.
//

import SwiftUI

@main
struct AuraWindApp: App {
    
    // MARK: - Services (使用 static 共享实例)
    
    private static let sharedSMCService = SMCServiceWithHelper()
    private static let sharedPersistenceService = PersistenceService()
    
    // MARK: - State
    
    @StateObject private var fanViewModel = FanControlViewModel(
        smcService: AuraWindApp.sharedSMCService,
        persistenceService: AuraWindApp.sharedPersistenceService
    )
    
    @StateObject private var tempViewModel = TemperatureMonitorViewModel(
        smcService: AuraWindApp.sharedSMCService,
        persistenceService: AuraWindApp.sharedPersistenceService
    )
    
    @State private var showPermissionView = false
    @State private var permissionGranted = true
    @State private var debugInfo: String = "等待初始化..."
    
    // MARK: - Body
    
    var body: some Scene {
        // 主窗口
        WindowGroup {
            if showPermissionView && !permissionGranted {
                SMCPermissionView {
                    permissionGranted = true
                    showPermissionView = false
                    initializeServices()
                }
            } else {
                VStack {
                    Text("调试信息：\(debugInfo)")
                        .padding()
                        .background(Color.yellow.opacity(0.3))
                    
                    MainView(
                        fanViewModel: fanViewModel,
                        tempViewModel: tempViewModel
                    )
                }
                .onAppear {
                    // 使用 Helper Tool 时，直接初始化服务
                    debugInfo = "MainView 已出现，开始初始化..."
                    NSLog("[AuraWindApp] MainView appeared, initializing services...")
                    initializeServices()
                    
                    if !permissionGranted {
                        checkPermissions()
                    }
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("关于 AuraWind") {
                    // 显示关于窗口
                }
            }
        }
        
        // 菜单栏图标
        MenuBarExtra("AuraWind", systemImage: "wind") {
            MenuBarView(
                fanViewModel: fanViewModel,
                tempViewModel: tempViewModel
            )
        }
        .menuBarExtraStyle(.window)
    }
    
    // MARK: - Private Methods
    
    /// 检查权限
    private func checkPermissions() {
        Task {
            let manager = SMCPermissionManager()
            let status = await manager.checkPermissions()
            
            if status.isAccessible {
                permissionGranted = true
                showPermissionView = false
                initializeServices()
            } else {
                showPermissionView = true
            }
        }
    }
    
    /// 初始化服务
    private func initializeServices() {
        Task {
            debugInfo = "🚀 开始初始化服务..."
            print("🚀 开始初始化服务...")
            
            // 启动 SMC 服务（使用 Helper Tool）
            do {
                debugInfo = "正在启动 SMC 服务..."
                try await Self.sharedSMCService.start()
                debugInfo = "✅ SMC 服务已启动"
                print("✅ SMC 服务已启动")
            } catch {
                debugInfo = "❌ SMC 服务启动失败: \(error.localizedDescription)"
                print("❌ SMC 服务启动失败: \(error)")
                return // 如果 SMC 启动失败，不继续
            }
            
            // 启动温度监控
            debugInfo = "正在初始化温度传感器..."
            await tempViewModel.initializeSensors()
            tempViewModel.startMonitoring()
            
            // 启动风扇控制
            debugInfo = "正在初始化风扇..."
            await fanViewModel.initializeFans()
            fanViewModel.startMonitoring()
            
            debugInfo = "✅ 所有服务初始化完成"
            print("✅ 所有服务初始化完成")
        }
    }
}

// MARK: - Menu Bar View

struct MenuBarView: View {
    @ObservedObject var fanViewModel: FanControlViewModel
    @ObservedObject var tempViewModel: TemperatureMonitorViewModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 状态信息
            statusSection
            
            Divider()
                .padding(.horizontal, 12)
            
            // 快速控制
            quickControlSection
            
            Divider()
                .padding(.horizontal, 12)
            
            // 操作按钮
            actionSection
        }
        .frame(width: 280)
        .background(menuBarBackground)
        .cornerRadius(12)
        .overlay(menuBarBorder)
    }
    
    private var menuBarBackground: some View {
        Group {
            if colorScheme == .dark {
                // 深色模式 - 玻璃拟态效果
                LinearGradient(
                    colors: [
                        .auraBrightBlue.opacity(0.08),
                        .auraSkyBlue.opacity(0.05),
                        .auraMediumBlue.opacity(0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                // 浅色模式 - 径向渐变
                RadialGradient(
                    colors: [
                        Color.white,
                        Color(red: 245/255, green: 250/255, blue: 254/255),
                        Color(red: 235/255, green: 245/255, blue: 253/255)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 140
                )
            }
        }
    }
    
    private var menuBarBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(
                LinearGradient(
                    colors: colorScheme == .dark ? [
                        .white.opacity(0.15),
                        .auraBrightBlue.opacity(0.1),
                        .white.opacity(0.05)
                    ] : [
                        .auraSkyBlue.opacity(0.25),
                        .auraMediumBlue.opacity(0.20),
                        .auraSoftBlue.opacity(0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 温度
            if let maxSensor = tempViewModel.sensors.max(by: { $0.currentTemperature < $1.currentTemperature }) as TemperatureSensor? {
                statusRow(
                    icon: "thermometer",
                    text: "最高温度: \(String(format: "%.1f", maxSensor.currentTemperature))°C",
                    color: maxSensor.isWarning ? .orange : .blue
                )
            }
            
            // 风扇
            statusRow(
                icon: "wind",
                text: "风扇: \(fanViewModel.fans.count) 个",
                color: .blue
            )
            
            // 监控状态
            statusRow(
                icon: "circle.fill",
                text: fanViewModel.isMonitoring ? "监控中" : "已停止",
                color: fanViewModel.isMonitoring ? .green : .gray,
                isStatusIndicator: true
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private func statusRow(icon: String, text: String, color: Color, isStatusIndicator: Bool = false) -> some View {
        HStack(spacing: 10) {
            if isStatusIndicator {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                    .frame(width: 16, height: 16)
            }
            
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .primary)
            
            Spacer()
        }
    }
    
    private var quickControlSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("快速模式")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .secondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            
            VStack(spacing: 4) {
                modeButton("静音模式", .silent, "1", "speaker.wave.1")
                modeButton("平衡模式", .balanced, "2", "scale.3d")
                modeButton("性能模式", .performance, "3", "bolt.fill")
            }
            .padding(.horizontal, 12)
        }
        .padding(.bottom, 12)
    }
    
    private func modeButton(_ title: String, _ mode: FanControlViewModel.FanMode, _ shortcut: String, _ icon: String) -> some View {
        Button {
            Task {
                await fanViewModel.changeMode(mode)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 14, height: 14)
                
                Text(title)
                    .font(.system(size: 13))
                
                Spacer()
                
                Text(shortcut)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(fanViewModel.currentMode == mode ?
                        (colorScheme == .dark ? Color.auraLogoBlue.opacity(0.2) : Color.auraLogoBlue.opacity(0.1)) :
                        Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        fanViewModel.currentMode == mode ?
                        Color.auraLogoBlue.opacity(0.5) :
                        Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(shortcut.first!))
    }
    
    private var actionSection: some View {
        VStack(spacing: 0) {
            actionButton("打开主窗口", "macwindow", "o") {
                NSApp.activate(ignoringOtherApps: true)
            }
            
            Divider()
                .padding(.horizontal, 12)
            
            actionButton("退出 AuraWind", "power", "q") {
                NSApplication.shared.terminate(nil)
            }
            .foregroundColor(.red)
        }
        .padding(.vertical, 8)
    }
    
    private func actionButton(_ title: String, _ icon: String, _ shortcut: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 14, height: 14)
                
                Text(title)
                    .font(.system(size: 13))
                
                Spacer()
                
                Text(shortcut)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(shortcut.first!))
    }
}
