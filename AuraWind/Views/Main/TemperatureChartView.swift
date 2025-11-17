//
//  TemperatureChartView.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025-11-16.
//  Updated: 2025-11-17 - Integrated real chart visualization
//

import SwiftUI

/// 温度图表视图
/// 显示温度传感器的实时和历史数据图表
struct TemperatureChartView: View {
    
    // MARK: - Properties
    
    @ObservedObject var viewModel: TemperatureMonitorViewModel
    @State private var displayMode: TemperatureLineChart.DisplayMode = .area
    @State private var showSensorPicker: Bool = false
    
    // 依赖服务
    private let persistenceService = PersistenceService()
    private let rangeManager = ChartRangeManager(persistenceService: PersistenceService())
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 统计信息
                statisticsSection
                
                // 控制面板
                controlPanel
                
                // 实时温度图表
                chartSection
                
                // 传感器列表
                sensorsSection
            }
            .padding(24)
        }
        .navigationTitle("温度监控")
        .auraBackground()
        .sheet(isPresented: Binding(
            get: { rangeManager.showRangeEditor },
            set: { rangeManager.showRangeEditor = $0 }
        )) {
            YAxisRangeEditor(
                chartType: .temperature,
                rangeManager: rangeManager
            )
            .frame(width: 450, height: 600)
        }
    }
    
    // MARK: - Statistics
    
    private var statisticsSection: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "当前最高",
                value: String(format: "%.1f°C", viewModel.getMaxTemperature()),
                icon: "arrow.up.circle.fill",
                color: .orange
            )
            
            StatCard(
                title: "当前最低",
                value: String(format: "%.1f°C", viewModel.getMinTemperature()),
                icon: "arrow.down.circle.fill",
                color: .auraLogoBlue
            )
            
            StatCard(
                title: "平均温度",
                value: String(format: "%.1f°C", viewModel.getAverageTemperature()),
                icon: "equal.circle.fill",
                color: .auraMediumBlue
            )
        }
    }
    
    // MARK: - Control Panel
    
    private var controlPanel: some View {
        BlurGlassCard {
            VStack(spacing: 16) {
                // 时间范围选择器
                VStack(alignment: .leading, spacing: 8) {
                    Text("时间范围")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("时间范围", selection: $viewModel.selectedTimeRange) {
                        ForEach(ChartDataPoint.TimeRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Divider()
                
                // 显示模式和传感器选择
                HStack {
                    // 显示模式
                    Menu {
                        Button {
                            displayMode = .line
                        } label: {
                            Label("折线图", systemImage: "chart.xyaxis.line")
                        }
                        
                        Button {
                            displayMode = .area
                        } label: {
                            Label("面积图", systemImage: "chart.line.uptrend.xyaxis")
                        }
                        
                        Button {
                            displayMode = .point
                        } label: {
                            Label("散点图", systemImage: "circle.grid.3x3")
                        }
                    } label: {
                        Label("显示模式", systemImage: displayModeIcon)
                    }
                    .buttonStyle(.bordered)
                    .tint(.auraLogoBlue)
                    
                    Spacer()
                    
                    // 传感器选择
                    Button {
                        showSensorPicker.toggle()
                    } label: {
                        Label(
                            "\(viewModel.selectedSensorLabels.isEmpty ? "全部" : "\(viewModel.selectedSensorLabels.count)个")传感器",
                            systemImage: "slider.horizontal.3"
                        )
                    }
                    .buttonStyle(.bordered)
                    .tint(.auraMediumBlue)
                }
                
                // 传感器选择器（展开状态）
                if showSensorPicker {
                    sensorPickerView
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - Sensor Picker
    
    private var sensorPickerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            
            HStack {
                Text("选择传感器")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("全选") {
                    viewModel.selectAllSensors()
                }
                .font(.caption)
                .buttonStyle(.borderless)
                
                Button("清空") {
                    viewModel.deselectAllSensors()
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(viewModel.getAvailableSensorLabels(), id: \.self) { label in
                    Button {
                        viewModel.toggleSensorSelection(label)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: viewModel.selectedSensorLabels.contains(label)
                                ? "checkmark.circle.fill"
                                : "circle")
                            .font(.caption)
                            
                            Text(label)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(viewModel.selectedSensorLabels.contains(label)
                                    ? Color.auraLogoBlue.opacity(0.15)
                                    : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Chart Section
    
    @ViewBuilder
    private var chartSection: some View {
        BlurGlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label {
                        Text("温度趋势")
                    } icon: {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                    }
                    .font(.headline)
                    
                    Spacer()
                    
                    // 数据点统计和控制器
                    HStack(spacing: 12) {
                        // 范围显示
                        if !filteredChartData.isEmpty {
                            Text(rangeManager.getRangeDisplayText(for: .temperature))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .help("当前Y轴范围")
                        }
                        
                        // 范围设置按钮
                        Button {
                            rangeManager.showRangeEditor = true
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.bordered)
                        .tint(.auraMediumBlue)
                        .help("自定义Y轴范围")
                        
                        // 数据点统计
                        if !viewModel.chartData.isEmpty {
                            Text("\(filteredChartData.count) 个数据点")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // 图表导出按钮
                        if !filteredChartData.isEmpty {
                            ChartExportButton(
                                dataPoints: filteredChartData,
                                chartType: .temperature,
                                persistenceService: persistenceService
                            )
                        }
                    }
                }
                
                Divider()
                
                // 实时图表
                TemperatureLineChart(
                    dataPoints: filteredChartData,
                    displayMode: displayMode,
                    showLegend: true,
                    showGrid: true,
                    height: 320,
                    rangeManager: rangeManager
                )
            }
            .padding(20)
        }
        
        // 数据标注面板
        if !viewModel.getVisibleAnnotations().isEmpty || !viewModel.annotationManager.visibleEventMarkers.isEmpty {
            DataAnnotationView(
                annotations: viewModel.getVisibleAnnotations(),
                eventMarkers: viewModel.annotationManager.visibleEventMarkers,
                dataPoints: filteredChartData,
                chartType: .temperature
            )
        }
    }
    
    // MARK: - Computed Properties
    
    /// 过滤后的图表数据
    private var filteredChartData: [ChartDataPoint] {
        viewModel.getCurrentChartData()
    }
    
    /// 显示模式图标
    private var displayModeIcon: String {
        switch displayMode {
        case .line:
            return "chart.xyaxis.line"
        case .area:
            return "chart.line.uptrend.xyaxis"
        case .point:
            return "circle.grid.3x3"
        }
    }
    
    // MARK: - Sensors Section
    
    private var sensorsSection: some View {
        BlurGlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("传感器详情", systemImage: "list.bullet")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button("导出数据") {
                        Task {
                            do {
                                let url = try await viewModel.exportData()
                                print("数据已导出到: \(url.path)")
                            } catch {
                                print("导出失败: \(error)")
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.auraLogoBlue)
                }
                
                Divider()
                
                if viewModel.sensors.isEmpty {
                    Text("暂无传感器数据")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                } else {
                    ForEach(viewModel.sensors) { sensor in
                        SensorDetailRow(sensor: sensor)
                    }
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - Helper Methods
    
    private func sensorColor(for sensor: TemperatureSensor) -> Color {
        switch sensor.type {
        case .cpu:
            return .red
        case .gpu:
            return .orange
        case .ambient:
            return .auraLogoBlue
        case .proximity:
            return .auraSkyBlue
        case .battery:
            return .green
        case .ssd:
            return .purple
        case .thunderbolt:
            return .yellow
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        BlurGlassCard {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(color)
                
                Text(value)
                    .font(.title3.bold().monospacedDigit())
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - Sensor Detail Row

private struct SensorDetailRow: View {
    let sensor: TemperatureSensor
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sensor.name)
                        .font(.subheadline.bold())
                    
                    Text(sensor.type.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(String(format: "%.1f", sensor.currentTemperature))
                            .font(.title3.bold().monospacedDigit())
                            .foregroundColor(temperatureColor)
                        
                        Text("°C")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(Int(sensor.temperaturePercentage))%")
                        .font(.caption)
                        .foregroundColor(temperatureColor)
                }
            }
            
            // 温度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                    
                    // 进度
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [temperatureColor.opacity(0.6), temperatureColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * (sensor.temperaturePercentage / 100))
                }
            }
            .frame(height: 8)
            
            // 历史数据信息
            HStack {
                Text("\(sensor.readings.count) 条记录")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if sensor.isWarning {
                    Label("高温警告", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var temperatureColor: Color {
        if sensor.isWarning {
            return .orange
        } else if sensor.currentTemperature > sensor.maxTemperature * 0.7 {
            return .yellow
        } else {
            return .auraLogoBlue
        }
    }
}

// MARK: - Preview

#Preview {
    let smcService = SMCService()
    let persistenceService = PersistenceService()
    
    let viewModel = TemperatureMonitorViewModel(
        smcService: smcService,
        persistenceService: persistenceService
    )
    
    return NavigationStack {
        TemperatureChartView(viewModel: viewModel)
    }
}