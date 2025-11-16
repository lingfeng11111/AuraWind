//
//  AuraWindApp.swift
//  AuraWind
//
//  Created by 凌峰 on 2025/11/16.
//

import SwiftUI

@main
struct AuraWindApp: App {
    
    // MARK: - Services
    
    private let smcService = SMCService()
    private let persistenceService = PersistenceService()
    
    // MARK: - State
    
    @StateObject private var fanViewModel: FanControlViewModel
    @StateObject private var tempViewModel: TemperatureMonitorViewModel
    
    init() {
        let smc = SMCService()
        let persistence = PersistenceService()
        
        _fanViewModel = StateObject(wrappedValue: FanControlViewModel(
            smcService: smc,
            persistenceService: persistence
        ))
        
        _tempViewModel = StateObject(wrappedValue: TemperatureMonitorViewModel(
            smcService: smc,
            persistenceService: persistence
        ))
    }
    
    // MARK: - Body
    
    var body: some Scene {
        // 主窗口
        WindowGroup {
            MainView(
                fanViewModel: fanViewModel,
                tempViewModel: tempViewModel
            )
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
}

// MARK: - Menu Bar View

struct MenuBarView: View {
    @ObservedObject var fanViewModel: FanControlViewModel
    @ObservedObject var tempViewModel: TemperatureMonitorViewModel
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 状态信息
            statusSection
            
            Divider()
            
            // 快速控制
            quickControlSection
            
            Divider()
            
            // 操作按钮
            actionSection
        }
        .frame(width: 280)
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 温度
            if let maxSensor = tempViewModel.sensors.max(by: { $0.currentTemperature < $1.currentTemperature }) {
                HStack {
                    Image(systemName: "thermometer")
                        .foregroundColor(maxSensor.isWarning ? .orange : .blue)
                    Text("最高温度: \(String(format: "%.1f", maxSensor.currentTemperature))°C")
                    Spacer()
                }
            }
            
            // 风扇
            HStack {
                Image(systemName: "wind")
                    .foregroundColor(.blue)
                Text("风扇: \(fanViewModel.fans.count) 个")
                Spacer()
            }
            
            // 监控状态
            HStack {
                Circle()
                    .fill(fanViewModel.isMonitoring ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(fanViewModel.isMonitoring ? "监控中" : "已停止")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private var quickControlSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("快速模式")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
            
            Button("静音模式") {
                Task {
                    await fanViewModel.changeMode(.silent)
                }
            }
            .keyboardShortcut("1")
            
            Button("平衡模式") {
                Task {
                    await fanViewModel.changeMode(.balanced)
                }
            }
            .keyboardShortcut("2")
            
            Button("性能模式") {
                Task {
                    await fanViewModel.changeMode(.performance)
                }
            }
            .keyboardShortcut("3")
        }
        .padding(.bottom, 8)
    }
    
    private var actionSection: some View {
        VStack(spacing: 0) {
            Button("打开主窗口") {
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("o")
            
            Divider()
            
            Button("退出 AuraWind") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
