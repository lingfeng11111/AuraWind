//
//  CustomSidebar.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025-11-16.
//  自定义侧边栏组件 - 匹配主题风格
//

import SwiftUI

/// 自定义侧边栏项
struct SidebarItem: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    
    init(id: String, title: String, icon: String) {
        self.id = id
        self.title = title
        self.icon = icon
    }
}

/// 自定义侧边栏组件
struct CustomSidebar<Content: View>: View {
    
    // MARK: - Properties
    
    let headerTitle: String
    let headerIcon: String
    let items: [SidebarItem]
    @Binding var selectedItem: String
    let statusContent: Content?
    
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Initialization
    
    init(
        headerTitle: String,
        headerIcon: String,
        items: [SidebarItem],
        selectedItem: Binding<String>,
        @ViewBuilder statusContent: () -> Content
    ) {
        self.headerTitle = headerTitle
        self.headerIcon = headerIcon
        self.items = items
        self._selectedItem = selectedItem
        self.statusContent = statusContent()
    }
    
    init(
        headerTitle: String,
        headerIcon: String,
        items: [SidebarItem],
        selectedItem: Binding<String>
    ) where Content == EmptyView {
        self.headerTitle = headerTitle
        self.headerIcon = headerIcon
        self.items = items
        self._selectedItem = selectedItem
        self.statusContent = nil
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // 头部区域
            headerSection
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 16)
            
            Divider()
                .padding(.horizontal, 12)
            
            // 导航项列表
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(items) { item in
                        sidebarButton(for: item)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
            
            Spacer()
            
            // 状态区域（如果有）- 移除重复的Divider
            if let statusContent = statusContent {
                statusContent
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
        }
        .frame(width: 220)
        .background(sidebarBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(sidebarBorder)
    }
    
    // MARK: - Background & Border
    
    /// 侧边栏背景 - 完全透明，只有边框和光晕
    @ViewBuilder
    private var sidebarBackground: some View {
        if colorScheme == .dark {
            // 深色模式 - 完全透明 + 淡淡蓝色光晕
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
    
    /// 侧边栏边框
    private var sidebarBorder: some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(
                borderGradient,
                lineWidth: 1
            )
    }
    
    /// 边框渐变
    private var borderGradient: LinearGradient {
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
        )
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Logo图标 - 使用彩色SVG
            Image("ColorfulIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
            
            // 标题
            Text(headerTitle)
                .font(.title3.bold())
                .foregroundColor(colorScheme == .dark ? .white : .primary)
        }
    }
    
    // MARK: - Sidebar Button
    
    private func sidebarButton(for item: SidebarItem) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedItem = item.id
            }
        } label: {
            HStack(spacing: 12) {
                // 图标
                Image(systemName: item.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(buttonForegroundColor(for: item))
                    .frame(width: 24, height: 24)
                
                // 标题
                Text(item.title)
                    .font(.system(size: 14, weight: selectedItem == item.id ? .semibold : .regular))
                    .foregroundColor(buttonForegroundColor(for: item))
                
                Spacer()
                
                // 选中指示器
                if selectedItem == item.id {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.auraBrightBlue, .auraSkyBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 6, height: 6)
                        .shadow(color: .auraBrightBlue.opacity(0.5), radius: 3)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(buttonBackground(for: item))
            .cornerRadius(10)
            .contentShape(Rectangle())  // 让整个区域都可点击
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Styling Helpers
    
    private func buttonForegroundColor(for item: SidebarItem) -> Color {
        if selectedItem == item.id {
            return colorScheme == .dark ? .white : .auraBrightBlue
        } else {
            return colorScheme == .dark ? .white.opacity(0.7) : Color.primary.opacity(0.7)
        }
    }
    
    private func buttonBackground(for item: SidebarItem) -> some View {
        Group {
            if selectedItem == item.id {
                // 选中状态背景
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
                // 未选中状态背景
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.clear)
            }
        }
    }
    
}

// MARK: - Preview

#Preview("Light Mode") {
    CustomSidebar(
        headerTitle: "AuraWind",
        headerIcon: "wind",
        items: [
            SidebarItem(id: "dashboard", title: "仪表盘", icon: "gauge"),
            SidebarItem(id: "fans", title: "风扇控制", icon: "wind"),
            SidebarItem(id: "temperature", title: "温度监控", icon: "thermometer"),
            SidebarItem(id: "settings", title: "设置", icon: "gearshape")
        ],
        selectedItem: .constant("dashboard")
    ) {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                
                Text("监控中")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 8) {
                Image(systemName: "thermometer")
                    .font(.caption)
                
                Text("65.0°C")
                    .font(.caption.monospacedDigit())
            }
            .foregroundColor(.secondary)
        }
    }
    .frame(height: 600)
    .auraBackground()
}

#Preview("Dark Mode") {
    CustomSidebar(
        headerTitle: "AuraWind",
        headerIcon: "wind",
        items: [
            SidebarItem(id: "dashboard", title: "仪表盘", icon: "gauge"),
            SidebarItem(id: "fans", title: "风扇控制", icon: "wind"),
            SidebarItem(id: "temperature", title: "温度监控", icon: "thermometer"),
            SidebarItem(id: "settings", title: "设置", icon: "gearshape")
        ],
        selectedItem: .constant("fans")
    ) {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                
                Text("监控中")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 8) {
                Image(systemName: "thermometer")
                    .font(.caption)
                
                Text("82.0°C")
                    .font(.caption.monospacedDigit())
            }
            .foregroundColor(.orange)
        }
    }
    .frame(height: 600)
    .preferredColorScheme(.dark)
    .auraBackground()
}