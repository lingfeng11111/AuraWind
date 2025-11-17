//
//  PerformanceMonitorView.swift
//  AuraWind
//
//  Created by AuraWind Development Team on 2025-11-17.
//

import SwiftUI

/// 性能监控视图
/// 显示系统性能指标的完整监控界面
struct PerformanceMonitorView: View {
    
    // MARK: - Properties
    
    @ObservedObject var viewModel: PerformanceMonitorViewModel
    @State private var displayMode: PerformanceChart.DisplayMode = .line
    @State private var showSettings: Bool = false
    
    // 依赖服务
    private let persistenceService = PersistenceService()
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 性能统计卡片
                statisticsSection
                
                // 控制面板
                controlPanel
                
                // 性能图表
                performanceChartSection
                
                // 详细性能数据
                detailedDataSection
            }
            .padding(24)
        }
        .navigationTitle("性能监控")
        .auraBackground()
        .sheet(isPresented: $showSettings) {
            performanceSettingsSheet
        }
        .sheet(isPresented: $viewModel.showRangeEditor) {
            YAxisRangeEditor(
                chartType: .performance,
                rangeManager: viewModel.rangeManager
            )
            .frame(width: 450, height: 600)
        }
    }
    
    // MARK: - Statistics Section
    
    private var statisticsSection: some View {
        let stats = viewModel.getPerformanceStats()
        
        return HStack(spacing: 16) {
            // CPU统计
            PerformanceStatCard(
                title: "CPU使用率",
                current: stats.cpu.formattedCurrent,
                average: stats.cpu.formattedAverage,
                max: stats.cpu.formattedMaximum,
                min: stats.cpu.formattedMinimum,
                icon: "cpu",
                color: .blue,
                isWarning: viewModel.currentCPUUsage > 80
            )
            
            // GPU统计
            PerformanceStatCard(
                title: "GPU使用率",
                current: stats.gpu.formattedCurrent,
                average: stats.gpu.formattedAverage,
                max: stats.gpu.formattedMaximum,
                min: stats.gpu.formattedMinimum,
                icon: "display",
                color: .green,
                isWarning: viewModel.currentGPUUsage > 80
            )
            
            // 内存统计
            PerformanceStatCard(
                title: "内存使用率",
                current: stats.memory.formattedCurrent,
                average: stats.memory.formattedAverage,
                max: stats.memory.formattedMaximum,
                min: stats.memory.formattedMinimum,
                icon: "memorychip",
                color: .orange,
                isWarning: viewModel.currentMemoryUsage > 85
            )
        }
    }
    
    // MARK: - Control Panel
    
    private var controlPanel: some View {
        BlurGlassCard {
            VStack(alignment: .leading, spacing: 16) {
                // 监控状态和控制
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("监控状态")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Circle()
                                .fill(viewModel.isMonitoring ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            
                            Text(viewModel.isMonitoring ? "监控中" : "已停止")
                                .font(.subheadline)
                                .foregroundColor(viewModel.isMonitoring ? .green : .red)
                        }
                    }
                    
                    Spacer()
                    
                    // 控制按钮
                    HStack(spacing: 8) {
                        Button {
                            if viewModel.isMonitoring {
                                viewModel.stopMonitoring()
                            } else {
                                viewModel.startMonitoring()
                            }
                        } label: {
                            Image(systemName: viewModel.isMonitoring ? "stop.fill" : "play.fill")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        
                        Button {
                            viewModel.clearHistory()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .controlSize(.small)
                        
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gear")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                
                Divider()
                
                // 时间范围和显示选项
                HStack {
                    // 时间范围选择
                    Picker("时间范围", selection: $viewModel.selectedTimeRange) {
                        ForEach(ChartDataPoint.TimeRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 120)
                    
                    Spacer()
                    
                    // 显示选项
                    HStack(spacing: 12) {
                        Toggle("CPU", isOn: $viewModel.showCPUChart)
                            .toggleStyle(.button)
                            .tint(.blue)
                        
                        Toggle("GPU", isOn: $viewModel.showGPUChart)
                            .toggleStyle(.button)
                            .tint(.green)
                        
                        Toggle("内存", isOn: $viewModel.showMemoryChart)
                            .toggleStyle(.button)
                            .tint(.orange)
                    }
                }
                
                // 显示模式选择
                HStack {
                    Text("显示模式")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Picker("显示模式", selection: $displayMode) {
                        Text("折线图").tag(PerformanceChart.DisplayMode.line)
                        Text("面积图").tag(PerformanceChart.DisplayMode.area)
                        Text("散点图").tag(PerformanceChart.DisplayMode.point)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - Performance Chart Section
    
    private var performanceChartSection: some View {
        BlurGlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("性能趋势", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.headline)
                    
                    Spacer()
                    
                    // 范围显示和设置
                    HStack(spacing: 12) {
                        if hasPerformanceData {
                            Text(viewModel.rangeManager.getRangeDisplayText(for: .performance))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .help("当前Y轴范围")
                            
                            Button {
                                viewModel.rangeManager.showRangeEditor = true
                            } label: {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 14))
                            }
                            .buttonStyle(.bordered)
                            .tint(.auraMediumBlue)
                            .help("自定义Y轴范围")
                        }
                        
                        // 导出按钮
                        if hasPerformanceData {
                            ChartExportButton(
                                dataPoints: getAllPerformanceData(),
                                chartType: .performance,
                                persistenceService: persistenceService
                            )
                        }
                    }
                }
                
                Divider()
                
                // 性能图表
                let (cpuData, gpuData, memoryData) = viewModel.getCurrentPerformanceData()
                
                if hasPerformanceData {
                    PerformanceChart(
                        cpuData: cpuData,
                        gpuData: gpuData,
                        memoryData: memoryData,
                        displayMode: displayMode,
                        height: 320
                    )
                } else {
                    chartEmptyState
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - Detailed Data Section
    
    private var detailedDataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("详细数据", systemImage: "list.bullet")
                    .font(.headline)
                
                Spacer()
                
                Button("导出数据") {
                    Task {
                        do {
                            let url = try await viewModel.exportPerformanceData()
                            print("性能数据已导出到: \(url.path)")
                        } catch {
                            print("导出失败: \(error)")
                        }
                    }
                }
                .buttonStyle(.bordered)
                .tint(.auraLogoBlue)
            }
            
            // 实时数据表格
            VStack(spacing: 12) {
                if viewModel.showCPUChart {
                    realTimeDataRow(
                        title: "CPU使用率",
                        value: String(format: "%.1f%%", viewModel.currentCPUUsage),
                        icon: "cpu",
                        color: .blue,
                        isWarning: viewModel.currentCPUUsage > 80
                    )
                }
                
                if viewModel.showGPUChart {
                    realTimeDataRow(
                        title: "GPU使用率",
                        value: String(format: "%.1f%%", viewModel.currentGPUUsage),
                        icon: "display",
                        color: .green,
                        isWarning: viewModel.currentGPUUsage > 80
                    )
                }
                
                if viewModel.showMemoryChart {
                    realTimeDataRow(
                        title: "内存使用率",
                        value: String(format: "%.1f%%", viewModel.currentMemoryUsage),
                        icon: "memorychip",
                        color: .orange,
                        isWarning: viewModel.currentMemoryUsage > 85
                    )
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private var chartEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            
            Text("暂无性能数据")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("开始性能监控后将显示系统资源使用情况")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.05))
        )
    }
    
    private var performanceSettingsSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 监控设置
                monitoringSettingsSection
                
                // 警告阈值设置
                warningThresholdsSection
                
                // 数据管理
                dataManagementSection
            }
            .padding()
            .navigationTitle("性能监控设置")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        showSettings = false
                    }
                }
            }
        }
        .frame(width: 450, height: 500)
    }
    
    private var monitoringSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("监控设置")
                .font(.headline)
            
            LabeledContent("监控间隔") {
                HStack {
                    Slider(value: $viewModel.monitoringInterval, in: 1...30, step: 1)
                        .frame(width: 150)
                    Text("\(Int(viewModel.monitoringInterval))秒")
                        .frame(width: 50)
                }
            }
            
            Toggle("自动开始监控", isOn: .constant(false))
                .help("应用启动时自动开始性能监控")
        }
    }
    
    private var warningThresholdsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("警告阈值")
                .font(.headline)
            
            LabeledContent("CPU警告阈值") {
                HStack {
                    Slider(value: .constant(80), in: 50...95, step: 5)
                        .frame(width: 150)
                    Text("80%")
                        .frame(width: 50)
                }
            }
            
            LabeledContent("GPU警告阈值") {
                HStack {
                    Slider(value: .constant(80), in: 50...95, step: 5)
                        .frame(width: 150)
                    Text("80%")
                        .frame(width: 50)
                }
            }
            
            LabeledContent("内存警告阈值") {
                HStack {
                    Slider(value: .constant(85), in: 70...95, step: 5)
                        .frame(width: 150)
                    Text("85%")
                        .frame(width: 50)
                }
            }
        }
    }
    
    private var dataManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("数据管理")
                .font(.headline)
            
            HStack {
                Text("数据保留时长")
                    .font(.subheadline)
                
                Spacer()
                
                Picker("保留时长", selection: .constant(ChartDataPoint.TimeRange.twentyFourHours)) {
                    Text("1小时").tag(ChartDataPoint.TimeRange.oneHour)
                    Text("6小时").tag(ChartDataPoint.TimeRange.sixHours)
                    Text("12小时").tag(ChartDataPoint.TimeRange.twelveHours)
                    Text("24小时").tag(ChartDataPoint.TimeRange.twentyFourHours)
                    Text("7天").tag(ChartDataPoint.TimeRange.sevenDays)
                }
                .pickerStyle(.menu)
                .frame(width: 120)
            }
            
            Button(role: .destructive) {
                viewModel.clearHistory()
            } label: {
                Label("清除所有历史数据", systemImage: "trash")
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Helper Methods
    
    private var hasPerformanceData: Bool {
        let (cpuData, gpuData, memoryData) = viewModel.getCurrentPerformanceData()
        return !cpuData.isEmpty || !gpuData.isEmpty || !memoryData.isEmpty
    }
    
    private func getAllPerformanceData() -> [ChartDataPoint] {
        return viewModel.getAllPerformanceData()
    }
    
    private func realTimeDataRow(title: String, value: String, icon: String, color: Color, isWarning: Bool) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.title3.bold().monospacedDigit())
                    .foregroundColor(isWarning ? .red : color)
            }
            
            Spacer()
            
            if isWarning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Performance Stat Card

private struct PerformanceStatCard: View {
    let title: String
    let current: String
    let average: String
    let max: String
    let min: String
    let icon: String
    let color: Color
    let isWarning: Bool
    
    var body: some View {
        BlurGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(isWarning ? .red : color)
                    
                    Spacer()
                    
                    if isWarning {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(current)
                        .font(.title.bold().monospacedDigit())
                        .foregroundColor(isWarning ? .red : color)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("平均")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(average)
                            .font(.caption2.monospacedDigit())
                    }
                    
                    HStack {
                        Text("最高")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(max)
                            .font(.caption2.monospacedDigit())
                    }
                    
                    HStack {
                        Text("最低")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(min)
                            .font(.caption2.monospacedDigit())
                    }
                }
            }
            .padding(12)
        }
    }
}

// MARK: - Preview

#Preview {
    let smcService = SMCService()
    let persistenceService = PersistenceService()
    
    let viewModel = PerformanceMonitorViewModel(
        smcService: smcService,
        persistenceService: persistenceService
    )
    
    NavigationStack {
        PerformanceMonitorView(viewModel: viewModel)
    }
}