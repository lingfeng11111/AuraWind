//
//  TemperatureChartView.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025-11-16.
//

import SwiftUI

/// 温度图表视图
/// 显示温度传感器的实时和历史数据图表
struct TemperatureChartView: View {
    
    // MARK: - Properties
    
    @ObservedObject var viewModel: TemperatureMonitorViewModel
    @State private var selectedTimeRange: TimeRange = .hour
    @State private var selectedSensor: TemperatureSensor?
    
    // MARK: - Types
    
    enum TimeRange: String, CaseIterable {
        case minute = "1分钟"
        case fiveMinutes = "5分钟"
        case fifteenMinutes = "15分钟"
        case hour = "1小时"
        
        var duration: TimeInterval {
            switch self {
            case .minute: return 60
            case .fiveMinutes: return 300
            case .fifteenMinutes: return 900
            case .hour: return 3600
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 统计信息
                statisticsSection
                
                // 时间范围选择
                timeRangeSelector
                
                // 图表占位
                chartPlaceholder
                
                // 传感器列表
                sensorsSection
            }
            .padding(24)
        }
        .navigationTitle("温度监控")
        .auraBackground()
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
    
    // MARK: - Time Range Selector
    
    private var timeRangeSelector: some View {
        BlurGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("时间范围")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("时间范围", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(16)
        }
    }
    
    // MARK: - Chart Placeholder
    
    private var chartPlaceholder: some View {
        BlurGlassCard {
            VStack(spacing: 16) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 48))
                    .foregroundColor(.auraLogoBlue)
                
                Text("温度趋势图表")
                    .font(.headline)
                
                Text("图表功能将在后续版本实现")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // 简单的数据点显示
                if !viewModel.sensors.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(viewModel.sensors.prefix(3)) { sensor in
                            HStack {
                                Circle()
                                    .fill(sensorColor(for: sensor))
                                    .frame(width: 8, height: 8)
                                
                                Text(sensor.name)
                                    .font(.caption)
                                
                                Spacer()
                                
                                Text("\(sensor.readings.count) 个数据点")
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 300)
            .padding(32)
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