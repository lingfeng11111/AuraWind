//
//  DashboardView.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025-11-16.
//

import SwiftUI

/// 仪表盘视图
/// 显示系统状态概览和快速控制
struct DashboardView: View {
    
    // MARK: - Properties
    
    @ObservedObject var fanViewModel: FanControlViewModel
    @ObservedObject var tempViewModel: TemperatureMonitorViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 顶部统计卡片
                statisticsSection
                
                // 快速控制 - 移到第二排
                quickControlSection
                
                // 温度卡片
                temperatureSection
                
                // 风扇状态卡片
                fanStatusSection
            }
            .padding(24)
        }
        .navigationTitle("仪表盘")
        .auraBackground()
    }
    
    // MARK: - Statistics Section
    
    private var statisticsSection: some View {
        HStack(spacing: 16) {
            // 最高温度
            StatCard(
                title: "最高温度",
                value: String(format: "%.1f°C", tempViewModel.getMaxTemperature()),
                icon: "thermometer.high",
                color: .auraLogoBlue
            )
            
            // 平均温度
            StatCard(
                title: "平均温度",
                value: String(format: "%.1f°C", tempViewModel.getAverageTemperature()),
                icon: "thermometer.medium",
                color: .auraMediumBlue
            )
            
            // 风扇数量
            StatCard(
                title: "风扇数量",
                value: "\(fanViewModel.fans.count)",
                icon: "wind",
                color: .auraSkyBlue
            )
            
            // 控制模式
            StatCard(
                title: "控制模式",
                value: fanViewModel.currentMode.description,
                icon: "gearshape.fill",
                color: .auraSoftBlue
            )
        }
    }
    
    // MARK: - Temperature Section
    
    private var temperatureSection: some View {
        BlurGlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("温度传感器", systemImage: "thermometer")
                        .font(.headline)
                    
                    Spacer()
                    
                    if tempViewModel.hasWarning {
                        Label("警告", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                if tempViewModel.sensors.isEmpty {
                    Text("暂无传感器数据")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                } else {
                    ForEach(tempViewModel.sensors) { sensor in
                        TemperatureSensorRow(sensor: sensor)
                    }
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - Fan Status Section
    
    private var fanStatusSection: some View {
        BlurGlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("风扇状态", systemImage: "wind")
                    .font(.headline)
                
                if fanViewModel.fans.isEmpty {
                    Text("暂无风扇数据")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                } else {
                    ForEach(fanViewModel.fans) { fan in
                        FanStatusRow(fan: fan)
                    }
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - Quick Control Section
    
    private var quickControlSection: some View {
        BlurGlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("快速控制", systemImage: "slider.horizontal.3")
                    .font(.headline)
                
                // 模式切换
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach([
                        FanControlViewModel.FanMode.silent,
                        FanControlViewModel.FanMode.balanced,
                        FanControlViewModel.FanMode.performance
                    ], id: \.self) { mode in
                        ModeButton(
                            mode: mode,
                            isSelected: fanViewModel.currentMode == mode
                        ) {
                            Task {
                                await fanViewModel.changeMode(mode)
                            }
                        }
                    }
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                // 监控控制
                HStack {
                    Text("自动监控")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
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
                    .toggleStyle(.switch)
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        BlurGlassCard(padding: 16) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(spacing: 4) {
                    Text(value)
                        .font(.title3.bold().monospacedDigit())
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                    
                    Text(title)
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }
}

// MARK: - Temperature Sensor Row

private struct TemperatureSensorRow: View {
    let sensor: TemperatureSensor
    
    var body: some View {
        HStack {
            // 传感器图标
            Image(systemName: sensorIcon)
                .font(.title3)
                .foregroundColor(temperatureColor)
                .frame(width: 32)
            
            // 传感器名称
            VStack(alignment: .leading, spacing: 2) {
                Text(sensor.name)
                    .font(.subheadline)
                
                Text(sensor.type.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 温度值
            HStack(spacing: 4) {
                Text(String(format: "%.1f", sensor.currentTemperature))
                    .font(.title3.bold().monospacedDigit())
                    .foregroundColor(temperatureColor)
                
                Text("°C")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 温度进度条
            ProgressView(value: sensor.temperaturePercentage / 100)
                .frame(width: 60)
                .tint(temperatureColor)
        }
        .padding(.vertical, 8)
    }
    
    private var sensorIcon: String {
        switch sensor.type {
        case .cpu:
            return "cpu"
        case .gpu:
            return "sparkles"
        case .ambient:
            return "thermometer.medium"
        case .proximity:
            return "sensor.fill"
        case .battery:
            return "battery.100"
        case .ssd:
            return "internaldrive.fill"
        case .thunderbolt:
            return "bolt.fill"
        }
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

// MARK: - Fan Status Row

private struct FanStatusRow: View {
    let fan: Fan
    
    var body: some View {
        HStack {
            // 风扇图标
            Image(systemName: "wind")
                .font(.title3)
                .foregroundColor(.auraLogoBlue)
                .frame(width: 32)
            
            // 风扇名称
            VStack(alignment: .leading, spacing: 2) {
                Text(fan.name)
                    .font(.subheadline)
                
                Text(fan.isManualControl ? "手动控制" : "自动模式")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 转速
            HStack(spacing: 4) {
                Text("\(fan.currentSpeed)")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundColor(.primary)
                
                Text("RPM")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 转速进度条
            ProgressView(value: fan.speedPercentage / 100)
                .frame(width: 60)
                .tint(.auraLogoBlue)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Mode Button

private struct ModeButton: View {
    let mode: FanControlViewModel.FanMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: modeIcon)
                    .font(.title2)
                
                Text(mode.description)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.auraLogoBlue.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.auraLogoBlue : Color.gray.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private var modeIcon: String {
        switch mode {
        case .silent:
            return "speaker.wave.1"
        case .balanced:
            return "scale.3d"
        case .performance:
            return "bolt.fill"
        case .auto:
            return "wand.and.stars"
        case .manual:
            return "hand.raised.fill"
        case .curve:
            return "chart.line.uptrend.xyaxis"
        }
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
    
    return DashboardView(
        fanViewModel: fanViewModel,
        tempViewModel: tempViewModel
    )
}