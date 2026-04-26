//
//  AuraWindApp.swift
//  AuraWind
//
//  Created by 凌峰 on 2025/11/16.
//

import SwiftUI

final class AuraWindAppDelegate: NSObject, NSApplicationDelegate {
    private var workspaceObservers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        registerWorkspacePowerObservers()

        Task { @MainActor in
            AuraWindApp.bootstrapServicesIfNeeded()
        }
    }

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        for observer in workspaceObservers {
            center.removeObserver(observer)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func registerWorkspacePowerObservers() {
        let center = NSWorkspace.shared.notificationCenter

        let willSleepObserver = center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                await AuraWindApp.handleSystemWillSleep()
            }
        }

        let didWakeObserver = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                await AuraWindApp.handleSystemDidWake()
            }
        }

        workspaceObservers = [willSleepObserver, didWakeObserver]
    }
}

@main
struct AuraWindApp: App {
    
    // MARK: - Services (使用 static 共享实例)
    
    private static let sharedSMCService = SMCServiceWithHelper()
    private static let sharedPersistenceService = PersistenceService()
    private static let sharedFanViewModel = FanControlViewModel(
        smcService: sharedSMCService,
        persistenceService: sharedPersistenceService
    )
    private static let sharedTempViewModel = TemperatureMonitorViewModel(
        smcService: sharedSMCService,
        persistenceService: sharedPersistenceService
    )
    @MainActor private static var didBootstrapServices = false
    @MainActor private static var didPauseForSystemSleep = false
    @NSApplicationDelegateAdaptor(AuraWindAppDelegate.self) private var appDelegate
    
    // MARK: - State
    
    @StateObject private var fanViewModel = AuraWindApp.sharedFanViewModel
    
    @StateObject private var tempViewModel = AuraWindApp.sharedTempViewModel
    
    @State private var showPermissionView = false
    @State private var permissionGranted = true
    
    // MARK: - Body
    
    var body: some Scene {
        // 主窗口
        WindowGroup(id: "main") {
            if showPermissionView && !permissionGranted {
                SMCPermissionView {
                    permissionGranted = true
                    showPermissionView = false
                    AuraWindApp.bootstrapServicesIfNeeded()
                }
            } else {
                MainView(
                    fanViewModel: fanViewModel,
                    tempViewModel: tempViewModel
                )
                .onAppear {
                    if !permissionGranted {
                        checkPermissions()
                    }
                }
            }
        }
        .defaultLaunchBehavior(.suppressed)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("关于 AuraWind") {
                    // 显示关于窗口
                }
            }
        }
        
        // 菜单栏图标（仅显示图标，避免文字挤占）
        MenuBarExtra {
            MenuBarView(
                fanViewModel: fanViewModel,
                tempViewModel: tempViewModel
            )
        } label: {
            Label("AuraWind", systemImage: "fanblades.fill")
                .labelStyle(.iconOnly)
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
        AuraWindApp.bootstrapServicesIfNeeded()
    }

    @MainActor
    static func bootstrapServicesIfNeeded() {
        guard !didBootstrapServices else { return }
        didBootstrapServices = true

        Task { @MainActor in
            print("🚀 开始初始化服务...")

            do {
                try await sharedSMCService.start()
                print("✅ SMC 服务已启动")
            } catch {
                print("❌ SMC 服务启动失败: \(error)")
                didBootstrapServices = false
                return
            }

            await sharedTempViewModel.initializeSensors()
            sharedTempViewModel.startMonitoring()

            await sharedFanViewModel.initializeFans()
            sharedFanViewModel.startMonitoring()

            print("✅ 所有服务初始化完成")
        }
    }

    @MainActor
    static func handleSystemWillSleep() async {
        guard didBootstrapServices else { return }
        print("🌙 检测到系统休眠，释放风扇控制权")

        sharedTempViewModel.stopMonitoring()
        await sharedFanViewModel.prepareForSystemSleep()
        didPauseForSystemSleep = true
    }

    @MainActor
    static func handleSystemDidWake() async {
        guard didPauseForSystemSleep else { return }
        print("☀️ 系统唤醒，恢复风扇与温度监控")

        do {
            try await sharedSMCService.connect()
            await sharedTempViewModel.initializeSensors()
            await sharedFanViewModel.initializeFans()
            sharedTempViewModel.startMonitoring()
            sharedFanViewModel.startMonitoring()
        } catch {
            print("❌ 唤醒后恢复监控失败: \(error)")
        }

        didPauseForSystemSleep = false
    }
}

// MARK: - Menu Bar View

struct MenuBarView: View {
    @ObservedObject var fanViewModel: FanControlViewModel
    @ObservedObject var tempViewModel: TemperatureMonitorViewModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme
    @State private var manualRPMInput = ""
    @State private var manualRPMFeedback: String?
    
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
                manualModeCard("手动模式", "1", "hand.raised.fill")
                modeButton("自动模式", .silent, "2", "arrow.triangle.2.circlepath")
                modeButton("静音模式", .balanced, "3", "speaker.wave.1")
                modeButton("性能模式", .performance, "4", "bolt.fill")
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.bottom, 12)
    }

    private func manualModeCard(_ title: String, _ shortcut: String, _ icon: String) -> some View {
        VStack(spacing: 0) {
            Button {
                Task {
                    await fanViewModel.changeMode(.manual)
                }
            } label: {
                modeRow(title: title, shortcut: shortcut, icon: icon)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .keyboardShortcut(KeyEquivalent(shortcut.first!))

            if fanViewModel.currentMode == .manual {
                Divider()
                    .padding(.horizontal, 12)

                manualRPMEditorSection
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(fanViewModel.currentMode == .manual ?
                    (colorScheme == .dark ? Color.auraLogoBlue.opacity(0.2) : Color.auraLogoBlue.opacity(0.1)) :
                    Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    fanViewModel.currentMode == .manual ?
                    Color.auraLogoBlue.opacity(0.5) :
                    Color.clear,
                    lineWidth: 1
                )
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var manualRPMEditorSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField("输入 RPM（如 3200）", text: $manualRPMInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 130)
                    .onSubmit {
                        applyManualRPMFromInput()
                    }
                    .onChange(of: manualRPMInput) { _ in
                        manualRPMFeedback = nil
                    }

                Button("应用") {
                    applyManualRPMFromInput()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(manualRPMInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()

                if let range = manualRPMRange {
                    Text("\(range.lowerBound)-\(range.upperBound)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            if let manualRPMFeedback {
                Text(manualRPMFeedback)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var manualRPMRange: ClosedRange<Int>? {
        guard !fanViewModel.fans.isEmpty else {
            return nil
        }

        let minAllowed = fanViewModel.fans.map(\.minSpeed).max() ?? 0
        let maxAllowed = fanViewModel.fans.map(\.maxSpeed).min() ?? 0
        guard minAllowed <= maxAllowed else {
            return nil
        }

        return minAllowed ... maxAllowed
    }
    
    private func modeButton(_ title: String, _ mode: FanControlViewModel.FanMode, _ shortcut: String, _ icon: String) -> some View {
        Button {
            Task {
                await fanViewModel.changeMode(mode)
            }
        } label: {
            modeRow(title: title, shortcut: shortcut, icon: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .keyboardShortcut(KeyEquivalent(shortcut.first!))
    }

    private func modeRow(title: String, shortcut: String, icon: String) -> some View {
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var actionSection: some View {
        VStack(spacing: 0) {
            actionButton("打开主窗口", "macwindow", "o") {
                openWindow(id: "main")
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .keyboardShortcut(KeyEquivalent(shortcut.first!))
    }

    private func applyManualRPMFromInput() {
        let input = manualRPMInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rpm = Int(input) else {
            manualRPMFeedback = "请输入有效数字"
            return
        }

        guard !fanViewModel.fans.isEmpty else {
            manualRPMFeedback = "暂无风扇数据"
            return
        }

        Task {
            await fanViewModel.changeMode(.manual)

            var hasClampedFan = false
            for (offset, fan) in fanViewModel.fans.enumerated() {
                let targetRPM = min(max(rpm, fan.minSpeed), fan.maxSpeed)
                hasClampedFan = hasClampedFan || (targetRPM != rpm)
                await fanViewModel.setFanSpeed(fanIndex: offset, rpm: targetRPM)
            }

            if hasClampedFan {
                if let range = manualRPMRange {
                    manualRPMFeedback = "已应用，超出范围时自动限制到 \(range.lowerBound)-\(range.upperBound)"
                } else {
                    manualRPMFeedback = "已应用（部分风扇已按可用范围限制）"
                }
            } else {
                manualRPMFeedback = "已应用到全部风扇"
            }

            manualRPMInput = "\(rpm)"
        }
    }
}
