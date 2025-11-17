//
//  PerformanceMonitor.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025-11-17.
//

import SwiftUI

/// 性能监控视图
struct PerformanceMonitor: View {
    
    // MARK: - Properties
    
    @StateObject private var viewModel = PerformanceMonitorViewModel()
    @State private var selectedTab = 0
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // 标签页选择器
            tabSelector
            
            // 内容区域
            contentArea
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }
    
    // MARK: - Subviews
    
    private var tabSelector: some View {
        Picker("监控类型", selection: $selectedTab) {
            Text("实时性能").tag(0)
            Text("SMC统计").tag(1)
            Text("优化建议").tag(2)
            Text("系统信息").tag(3)
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
    }
    
    private var contentArea: some View {
        Group {
            switch selectedTab {
            case 0:
                realTimePerformanceView
            case 1:
                smcStatisticsView
            case 2:
                optimizationSuggestionsView
            case 3:
                systemInfoView
            default:
                EmptyView()
            }
        }
    }
    
    private var realTimePerformanceView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // CPU使用率
                performanceMetricCard(
                    title: "CPU使用率",
                    value: "\(String(format: "%.1f", viewModel.cpuUsage))%",
                    color: .blue,
                    icon: "cpu"
                )
                
                // 内存使用率
                performanceMetricCard(
                    title: "内存使用率",
                    value: "\(String(format: "%.1f", viewModel.memoryUsage))%",
                    color: .green,
                    icon: "memorychip"
                )
                
                // SMC访问延迟
                performanceMetricCard(
                    title: "SMC访问延迟",
                    value: "\(String(format: "%.3f", viewModel.smcLatency))秒",
                    color: .orange,
                    icon: "speedometer"
                )
                
                // 缓存命中率
                performanceMetricCard(
                    title: "缓存命中率",
                    value: "\(String(format: "%.1f", viewModel.cacheHitRate * 100))%",
                    color: .purple,
                    icon: "checkmark.circle"
                )
                
                // 连接池状态
                connectionPoolStatusCard
            }
            .padding()
        }
    }
    
    private var smcStatisticsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // SMC访问统计
                statisticsCard(
                    title: "SMC访问统计",
                    stats: viewModel.smcStats
                )
                
                // 错误统计
                errorStatisticsCard
                
                // 访问频率图表
                accessFrequencyChart
            }
            .padding()
        }
    }
    
    private var optimizationSuggestionsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                if viewModel.optimizationSuggestions.isEmpty {
                    Text("暂无优化建议")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(viewModel.optimizationSuggestions, id: \.description) { suggestion in
                        optimizationSuggestionCard(suggestion)
                    }
                }
            }
            .padding()
        }
    }
    
    private var systemInfoView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 系统信息
                systemInfoCard
                
                // SMC连接信息
                smcConnectionInfoCard
                
                // 权限状态
                permissionStatusCard
            }
            .padding()
        }
    }
    
    // MARK: - Helper Views
    
    private func performanceMetricCard(title: String, value: String, color: Color, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            
            Spacer()
            
            // 趋势指示器
            trendIndicator(for: title)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var connectionPoolStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "network")
                    .foregroundColor(.blue)
                Text("连接池状态")
                    .font(.headline)
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("活跃连接: \(viewModel.activeConnections)")
                        .font(.subheadline)
                    Text("总连接数: \(viewModel.totalConnections)")
                        .font(.subheadline)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("利用率: \(String(format: "%.1f", viewModel.connectionPoolUtilization * 100))%")
                        .font(.subheadline)
                    Text("状态: \(viewModel.connectionPoolStatus)")
                        .font(.subheadline)
                        .foregroundColor(viewModel.connectionPoolStatus == "正常" ? .green : .orange)
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func statisticsCard(title: String, stats: [(String, Int)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "chart.bar")
                    .foregroundColor(.green)
                Text(title)
                    .font(.headline)
            }
            
            ForEach(stats, id: \.0) { stat in
                HStack {
                    Text(stat.0)
                        .font(.subheadline)
                    Spacer()
                    Text("\(stat.1)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var errorStatisticsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
                Text("错误统计")
                    .font(.headline)
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("总错误数: \(viewModel.totalErrors)")
                        .font(.subheadline)
                    Text("权限错误: \(viewModel.permissionErrors)")
                        .font(.subheadline)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("连接错误: \(viewModel.connectionErrors)")
                        .font(.subheadline)
                    Text("读写错误: \(viewModel.readWriteErrors)")
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var accessFrequencyChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.purple)
                Text("访问频率")
                    .font(.headline)
            }
            
            // 这里可以集成真正的图表组件
            Text("最近1小时访问: \(viewModel.recentAccessCount)次")
                .font(.subheadline)
            Text("平均访问间隔: \(String(format: "%.1f", viewModel.averageAccessInterval))秒")
                .font(.subheadline)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func optimizationSuggestionCard(_ suggestion: OptimizationSuggestion) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // 优先级指示器
            Circle()
                .fill(priorityColor(suggestion.priority))
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(suggestionTypeText(suggestion.type))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(priorityText(suggestion.priority))
                        .font(.caption)
                        .foregroundColor(priorityColor(suggestion.priority))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(priorityColor(suggestion.priority).opacity(0.1))
                        .cornerRadius(8)
                }
                
                Text(suggestion.description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(priorityColor(suggestion.priority).opacity(0.3), lineWidth: 1)
        )
    }
    
    private var systemInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "desktopcomputer")
                    .foregroundColor(.blue)
                Text("系统信息")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("macOS版本: \(viewModel.macosVersion)")
                    .font(.subheadline)
                Text("系统架构: \(viewModel.systemArchitecture)")
                    .font(.subheadline)
                Text("CPU核心数: \(viewModel.cpuCores)")
                    .font(.subheadline)
                Text("总内存: \(viewModel.totalMemory)GB")
                    .font(.subheadline)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var smcConnectionInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "link")
                    .foregroundColor(.green)
                Text("SMC连接信息")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("连接状态: \(viewModel.smcConnectionStatus)")
                    .font(.subheadline)
                    .foregroundColor(viewModel.smcConnectionStatus == "已连接" ? .green : .red)
                Text("权限状态: \(viewModel.permissionStatus)")
                    .font(.subheadline)
                    .foregroundColor(viewModel.permissionStatus == "已授权" ? .green : .orange)
                Text("使用真实SMC: \(viewModel.useRealSMC ? "是" : "否")")
                    .font(.subheadline)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var permissionStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "shield.checkered")
                    .foregroundColor(.orange)
                Text("权限详情")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Entitlements: \(viewModel.hasEntitlements ? "已配置" : "未配置")")
                    .font(.subheadline)
                    .foregroundColor(viewModel.hasEntitlements ? .green : .red)
                Text("代码签名: \(viewModel.isCodeSigned ? "已签名" : "未签名")")
                    .font(.subheadline)
                    .foregroundColor(viewModel.isCodeSigned ? .green : .red)
                Text("Hardened Runtime: \(viewModel.hasHardenedRuntime ? "已启用" : "未启用")")
                    .font(.subheadline)
                    .foregroundColor(viewModel.hasHardenedRuntime ? .green : .red)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func trendIndicator(for metric: String) -> some View {
        Image(systemName: "arrow.up.right")
            .foregroundColor(.green)
            .font(.caption)
    }
    
    // MARK: - Helper Functions
    
    private func priorityColor(_ priority: OptimizationPriority) -> Color {
        switch priority {
        case .low:
            return .green
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }
    
    private func priorityText(_ priority: OptimizationPriority) -> String {
        switch priority {
        case .low:
            return "低"
        case .medium:
            return "中"
        case .high:
            return "高"
        }
    }
    
    private func suggestionTypeText(_ type: OptimizationSuggestionType) -> String {
        switch type {
        case .cache:
            return "缓存优化"
        case .connectionPool:
            return "连接池"
        case .performance:
            return "性能优化"
        case .configuration:
            return "配置优化"
        }
    }
}

// MARK: - Preview

#Preview {
    PerformanceMonitor()
}