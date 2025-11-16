//
//  SettingsView.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025-11-16.
//

import SwiftUI

/// 设置视图
/// 应用的设置和配置界面
struct SettingsView: View {
    
    // MARK: - Properties
    
    @ObservedObject var fanViewModel: FanControlViewModel
    @ObservedObject var tempViewModel: TemperatureMonitorViewModel
    @State private var selectedTab: String = "general"
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Tab Items
    
    private let tabItems = [
        ("general", "通用", "gearshape"),
        ("curves", "曲线配置", "chart.xyaxis.line"),
        ("notifications", "通知", "bell"),
        ("advanced", "高级", "slider.horizontal.3")
    ]
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 16) {
            // 顶部切换栏 - 卡片式设计
            topTabBar
                .padding(.horizontal, 16)
                .padding(.top, 16)
            
            // 内容区
            detailContent
        }
        .navigationTitle("设置")
        .auraBackground()
    }
    
    // MARK: - Top Tab Bar
    
    private var topTabBar: some View {
        HStack(spacing: 12) {
            ForEach(tabItems, id: \.0) { item in
                tabButton(id: item.0, title: item.1, icon: item.2)
            }
        }
        .padding(12)
        .background(tabBarBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(tabBarBorder)
    }
    
    /// Tab Bar背景
    @ViewBuilder
    private var tabBarBackground: some View {
        if colorScheme == .dark {
            // 深色模式 - 淡蓝色光晕
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
            // 白天模式 - 径向渐变
            GeometryReader { geometry in
                RadialGradient(
                    colors: [
                        Color.white,
                        Color(red: 245/255, green: 250/255, blue: 254/255),
                        Color(red: 235/255, green: 245/255, blue: 253/255)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: max(geometry.size.width, geometry.size.height) * 0.7
                )
            }
        }
    }
    
    /// Tab Bar边框
    private var tabBarBorder: some View {
        RoundedRectangle(cornerRadius: 16)
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
    
    private func tabButton(id: String, title: String, icon: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = id
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                
                Text(title)
                    .font(.system(size: 12, weight: selectedTab == id ? .semibold : .regular))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .foregroundColor(buttonForegroundColor(for: id))
            .background(buttonBackground(for: id))
            .cornerRadius(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func buttonForegroundColor(for id: String) -> Color {
        if selectedTab == id {
            return colorScheme == .dark ? .white : .auraBrightBlue
        } else {
            return colorScheme == .dark ? .white.opacity(0.7) : Color.primary.opacity(0.7)
        }
    }
    
    private func buttonBackground(for id: String) -> some View {
        Group {
            if selectedTab == id {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        colorScheme == .dark
                            ? Color.auraBrightBlue.opacity(0.2)
                            : Color.auraBrightBlue.opacity(0.1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .auraBrightBlue.opacity(0.4),
                                        .auraSkyBlue.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.clear)
            }
        }
    }
    
    // MARK: - Detail Content
    
    @ViewBuilder
    private var detailContent: some View {
        ScrollView {
            Group {
                switch selectedTab {
                case "general":
                    GeneralSettingsView(
                        fanViewModel: fanViewModel,
                        tempViewModel: tempViewModel
                    )
                case "curves":
                    CurveSettingsView(viewModel: fanViewModel)
                case "notifications":
                    NotificationSettingsView(viewModel: tempViewModel)
                case "advanced":
                    AdvancedSettingsView(
                        fanViewModel: fanViewModel,
                        tempViewModel: tempViewModel
                    )
                default:
                    GeneralSettingsView(
                        fanViewModel: fanViewModel,
                        tempViewModel: tempViewModel
                    )
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - General Settings

private struct GeneralSettingsView: View {
    @ObservedObject var fanViewModel: FanControlViewModel
    @ObservedObject var tempViewModel: TemperatureMonitorViewModel
    
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @AppStorage("minimizeToMenuBar") private var minimizeToMenuBar = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("通用设置")
                .font(.title2.bold())
            
            // 启动和界面合并到一张卡片
            BlurGlassCard {
                VStack(alignment: .leading, spacing: 20) {
                    // 启动设置
                    VStack(alignment: .leading, spacing: 12) {
                        Text("启动")
                            .font(.headline)
                        Toggle("开机时启动", isOn: $launchAtLogin)
                        Toggle("启动时最小化", isOn: $minimizeToMenuBar)
                    }
                    
                    Divider()
                    
                    // 界面设置
                    VStack(alignment: .leading, spacing: 12) {
                        Text("界面")
                            .font(.headline)
                        Toggle("显示菜单栏图标", isOn: $showMenuBarIcon)
                        Toggle("最小化到菜单栏", isOn: $minimizeToMenuBar)
                    }
                }
                .padding(20)
            }
            
            // 监控设置
            settingsGroup(title: "监控") {
                HStack {
                    Text("更新间隔")
                    Spacer()
                    Text("2秒")
                        .foregroundColor(.secondary)
                }
                
                Toggle("自动监控", isOn: Binding(
                    get: { fanViewModel.isMonitoring },
                    set: { newValue in
                        if newValue {
                            fanViewModel.startMonitoring()
                            tempViewModel.startMonitoring()
                        } else {
                            fanViewModel.stopMonitoring()
                            tempViewModel.stopMonitoring()
                        }
                    }
                ))
            }
        }
    }
    
    private func settingsGroup<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        BlurGlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 12) {
                    content()
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Curve Settings

private struct CurveSettingsView: View {
    @ObservedObject var viewModel: FanControlViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("曲线配置")
                .font(.title2.bold())
            
            BlurGlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("预设曲线")
                        .font(.headline)
                    
                    VStack(spacing: 12) {
                        curveOption(
                            name: "静音模式",
                            description: "低转速,静音运行",
                            profile: .silent
                        )
                        
                        curveOption(
                            name: "平衡模式",
                            description: "平衡性能与噪音",
                            profile: .balanced
                        )
                        
                        curveOption(
                            name: "性能模式",
                            description: "高转速,最佳散热",
                            profile: .performance
                        )
                    }
                }
                .padding(20)
            }
            
            BlurGlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("自定义曲线")
                        .font(.headline)
                    
                    Text("自定义曲线编辑器将在后续版本提供")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                }
                .padding(20)
            }
            
            Spacer()
        }
    }
    
    private func curveOption(
        name: String,
        description: String,
        profile: CurveProfile
    ) -> some View {
        Button {
            Task {
                await viewModel.applyCurveProfile(profile)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.subheadline.bold())
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if viewModel.activeCurveProfile?.name == profile.name {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.auraLogoBlue)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(viewModel.activeCurveProfile?.name == profile.name ?
                          Color.auraLogoBlue.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Notification Settings

private struct NotificationSettingsView: View {
    @ObservedObject var viewModel: TemperatureMonitorViewModel
    
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("enableSound") private var enableSound = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("通知设置")
                .font(.title2.bold())
            
            BlurGlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("温度警告")
                        .font(.headline)
                    
                    Toggle("启用通知", isOn: $enableNotifications)
                    
                    Toggle("启用声音", isOn: $enableSound)
                        .disabled(!enableNotifications)
                    
                    Divider()
                    
                    HStack {
                        Text("警告阈值")
                        
                        Spacer()
                        
                        Text("\(Int(viewModel.warningThreshold))°C")
                            .foregroundColor(.auraLogoBlue)
                    }
                    
                    Slider(
                        value: $viewModel.warningThreshold,
                        in: 60...100,
                        step: 5
                    ) {
                        Text("阈值")
                    }
                    .tint(.auraLogoBlue)
                }
                .padding(20)
            }
            
            Spacer()
        }
    }
}

// MARK: - Advanced Settings

private struct AdvancedSettingsView: View {
    @ObservedObject var fanViewModel: FanControlViewModel
    @ObservedObject var tempViewModel: TemperatureMonitorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("高级设置")
                .font(.title2.bold())
            
            // 数据管理和诊断信息合并到一张卡片
            BlurGlassCard {
                VStack(alignment: .leading, spacing: 20) {
                    // 数据管理
                    VStack(alignment: .leading, spacing: 12) {
                        Text("数据管理")
                            .font(.headline)
                        
                        Button("清除历史数据") {
                            tempViewModel.clearHistory()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("导出温度数据") {
                            Task {
                                _ = try? await tempViewModel.exportData()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Divider()
                    
                    // 诊断信息
                    VStack(alignment: .leading, spacing: 12) {
                        Text("诊断信息")
                            .font(.headline)
                        
                        InfoRow(label: "风扇数量", value: "\(fanViewModel.fans.count)")
                        InfoRow(label: "传感器数量", value: "\(tempViewModel.sensors.count)")
                        InfoRow(label: "监控状态", value: fanViewModel.isMonitoring ? "运行中" : "已停止")
                        InfoRow(label: "版本", value: "0.1.0 Alpha")
                    }
                }
                .padding(20)
            }
        }
    }
}

// MARK: - Info Row

private struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.primary)
        }
        .font(.subheadline)
    }
}

// MARK: - Preview

#Preview {
    let smcService = SMCService()
    let persistenceService = PersistenceService()
    
    let fanViewModel = FanControlViewModel(
        smcService: smcService,
        persistenceService: persistenceService
    )
    
    let tempViewModel = TemperatureMonitorViewModel(
        smcService: smcService,
        persistenceService: persistenceService
    )
    
    return NavigationStack {
        SettingsView(
            fanViewModel: fanViewModel,
            tempViewModel: tempViewModel
        )
    }
}