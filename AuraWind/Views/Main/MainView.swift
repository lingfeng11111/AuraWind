//
//  MainView.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025-11-16.
//

import SwiftUI

/// 主视图
/// 应用的主窗口界面,包含导航和内容区域
struct MainView: View {
    
    // MARK: - State
    
    @StateObject private var fanViewModel: FanControlViewModel
    @StateObject private var tempViewModel: TemperatureMonitorViewModel
    @State private var selectedTab: String = "dashboard"
    
    // MARK: - Sidebar Items
    
    private var sidebarItems: [SidebarItem] {
        [
            SidebarItem(id: "dashboard", title: "仪表盘", icon: "gauge"),
            SidebarItem(id: "fans", title: "风扇控制", icon: "wind"),
            SidebarItem(id: "temperature", title: "温度监控", icon: "thermometer"),
            SidebarItem(id: "settings", title: "设置", icon: "gearshape")
        ]
    }
    
    // MARK: - Initialization
    
    init(
        fanViewModel: FanControlViewModel,
        tempViewModel: TemperatureMonitorViewModel
    ) {
        _fanViewModel = StateObject(wrappedValue: fanViewModel)
        _tempViewModel = StateObject(wrappedValue: tempViewModel)
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 16) {
            // 侧边栏 - 直接使用CustomSidebar
            CustomSidebar(
                headerTitle: "AuraWind",
                headerIcon: "wind",
                items: sidebarItems,
                selectedItem: $selectedTab
            ) {
                statusSection
            }
            .frame(width: 220)
            .padding(.leading, 16)
            .padding(.top, 4)
            .padding(.bottom, 16)
            
            // 详细内容区域
            detailContent
        }
        .frame(minWidth: 900, minHeight: 600)
        .auraBackground()
        .task {
            await initializeApp()
        }
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            
            // 监控状态
            HStack(spacing: 8) {
                Circle()
                    .fill(fanViewModel.isMonitoring ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                
                Text(fanViewModel.isMonitoring ? "监控中" : "已停止")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 当前温度
            if let maxTemp = tempViewModel.sensors.max(by: { $0.currentTemperature < $1.currentTemperature }) as TemperatureSensor? {
                HStack(spacing: 8) {
                    Image(systemName: "thermometer")
                        .font(.caption)
                    
                    Text("\(String(format: "%.1f", maxTemp.currentTemperature))°C")
                        .font(.caption.monospacedDigit())
                }
                .foregroundColor(maxTemp.isWarning ? .orange : .secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Detail Content
    
    @ViewBuilder
    private var detailContent: some View {
        Group {
            switch selectedTab {
            case "dashboard":
                DashboardView(
                    fanViewModel: fanViewModel,
                    tempViewModel: tempViewModel
                )
            case "fans":
                FanListView(viewModel: fanViewModel)
            case "temperature":
                TemperatureChartView(viewModel: tempViewModel)
            case "settings":
                SettingsView(
                    fanViewModel: fanViewModel,
                    tempViewModel: tempViewModel
                )
            default:
                DashboardView(
                    fanViewModel: fanViewModel,
                    tempViewModel: tempViewModel
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Methods
    
    private func initializeApp() async {
        // 初始化传感器
        await tempViewModel.initializeSensors()
        
        // 初始化风扇
        await fanViewModel.initializeFans()
        
        // 开始监控
        fanViewModel.startMonitoring()
        tempViewModel.startMonitoring()
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
    
    return MainView(
        fanViewModel: fanViewModel,
        tempViewModel: tempViewModel
    )
}