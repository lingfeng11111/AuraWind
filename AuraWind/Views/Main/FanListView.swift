//
//  FanListView.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025-11-16.
//

import SwiftUI

/// 风扇列表视图
/// 显示所有风扇的详细信息和控制选项
struct FanListView: View {
    
    // MARK: - Properties
    
    @ObservedObject var viewModel: FanControlViewModel
    
    // 依赖服务
    private let persistenceService = PersistenceService()
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 控制模式选择
                modeSelectionSection
                
                // 风扇转速图表
                fanChartSection
                
                // 风扇列表
                fanListSection
            }
            .padding(24)
        }
        .navigationTitle("风扇控制")
        .auraBackground()
    }
    
    // MARK: - Mode Selection
    
    private var modeSelectionSection: some View {
        BlurGlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Label {
                    Text("控制模式")
                } icon: {
                    Image(systemName: "slider.horizontal.3")
                }
                .font(.headline)
                
                Picker("控制模式", selection: Binding(
                    get: { viewModel.currentMode },
                    set: { newMode in
                        Task {
                            await viewModel.changeMode(newMode)
                        }
                    }
                )) {
                    ForEach(FanControlViewModel.FanMode.allCases, id: \.self) { mode in
                        Text(mode.description).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                
                if viewModel.currentMode == .curve,
                   let profile = viewModel.activeCurveProfile {
                    Text("当前曲线: \(profile.name)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - Fan Chart Section
    
    private var fanChartSection: some View {
        BlurGlassCard {
            VStack(alignment: .leading, spacing: 16) {
                // 标题和控制器
                HStack {
                    Label {
                        Text("风扇转速趋势")
                    } icon: {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                    }
                    .font(.headline)
                    
                    Spacer()
                    
                    // 数据点统计
                    if !viewModel.getCurrentChartData().isEmpty {
                        Text("\(viewModel.getCurrentChartData().count) 个数据点")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // 图表导出按钮
                    if !viewModel.getCurrentChartData().isEmpty {
                        ChartExportButton(
                            dataPoints: viewModel.getCurrentChartData(),
                            chartType: .fanSpeed,
                            persistenceService: persistenceService
                        )
                    }
                    
                    // 时间范围选择器
                    timeRangePicker
                }
                
                // 风扇选择器
                fanSelector
                
                // 图表显示
                if !viewModel.getCurrentChartData().isEmpty {
                    FanSpeedChart(
                        dataPoints: viewModel.getCurrentChartData(),
                        displayMode: .line,
                        height: 250
                    )
                } else {
                    chartEmptyState
                }
            }
            .padding(20)
        }
    }
    
    private var timeRangePicker: some View {
        Picker("时间范围", selection: $viewModel.selectedTimeRange) {
            ForEach(ChartDataPoint.TimeRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
    }
    
    private var fanSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("选择风扇")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // 快速选择按钮
                HStack(spacing: 8) {
                    Button("全选") {
                        viewModel.selectAllFans()
                    }
                    .font(.caption)
                    
                    Button("清空") {
                        viewModel.deselectAllFans()
                    }
                    .font(.caption)
                }
            }
            
            // 风扇标签网格
            if !viewModel.getAvailableFanLabels().isEmpty {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 80))
                ], spacing: 8) {
                    ForEach(viewModel.getAvailableFanLabels(), id: \.self) { label in
                        FanLabelButton(
                            label: label,
                            isSelected: viewModel.selectedFanLabels.contains(label)
                        ) {
                            viewModel.toggleFanSelection(label)
                        }
                    }
                }
            }
        }
    }
    
    private var chartEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "fan.slash")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            
            Text("暂无风扇数据")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("开始监控后将显示风扇转速趋势")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.05))
        )
    }
    
    // MARK: - Fan Label Button
    
    private struct FanLabelButton: View {
        let label: String
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Text(label)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSelected ? Color.auraLogoBlue.opacity(0.2) : Color.clear)
                            .stroke(
                                isSelected ? Color.auraLogoBlue : Color.secondary.opacity(0.3),
                                lineWidth: 1
                            )
                    )
                    .foregroundColor(isSelected ? .auraLogoBlue : .secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Fan List
    
    private var fanListSection: some View {
        VStack(spacing: 16) {
            if viewModel.fans.isEmpty {
                emptyStateView
            } else {
                ForEach(Array(viewModel.fans.enumerated()), id: \.element.id) { index, fan in
                    FanControlCard(
                        fan: fan,
                        isManualMode: viewModel.currentMode == .manual
                    ) { newSpeed in
                        Task {
                            await viewModel.setFanSpeed(fanIndex: index, rpm: newSpeed)
                        }
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        BlurGlassCard {
            VStack(spacing: 16) {
                Image(systemName: "wind.slash")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                
                Text("未检测到风扇")
                    .font(.headline)
                
                Text("请确保SMC服务已连接")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(40)
        }
    }
}

// MARK: - Fan Control Card

private struct FanControlCard: View {
    let fan: Fan
    let isManualMode: Bool
    let onSpeedChange: (Int) -> Void
    
    @State private var targetSpeed: Double
    
    init(fan: Fan, isManualMode: Bool, onSpeedChange: @escaping (Int) -> Void) {
        self.fan = fan
        self.isManualMode = isManualMode
        self.onSpeedChange = onSpeedChange
        _targetSpeed = State(initialValue: Double(fan.currentSpeed))
    }
    
    var body: some View {
        BlurGlassCard {
            VStack(alignment: .leading, spacing: 20) {
                // 标题栏
                header
                
                Divider()
                
                // 转速信息
                speedInfo
                
                // 手动控制滑块
                if isManualMode {
                    speedSlider
                }
                
                // 转速范围信息
                speedRangeInfo
            }
            .padding(20)
        }
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(fan.name)
                    .font(.headline)
                
                Text(fan.isManualControl ? "手动控制" : "自动模式")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 风扇图标(带旋转动画)
            Image(systemName: "wind")
                .font(.title)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.auraLogoBlue, .auraSkyBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
    
    private var speedInfo: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(fan.currentSpeed)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(
                    LinearGradient(
                        colors: [.auraLogoBlue, .auraMediumBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text("RPM")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(Int(fan.speedPercentage))%")
                    .font(.caption.bold())
                    .foregroundColor(.auraLogoBlue)
            }
            
            Spacer()
            
            // 转速进度环
            CircularProgressView(
                progress: fan.speedPercentage / 100,
                lineWidth: 6
            )
            .frame(width: 60, height: 60)
        }
    }
    
    private var speedSlider: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("目标转速")
                    .font(.subheadline)
                
                Spacer()
                
                Text("\(Int(targetSpeed)) RPM")
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.auraLogoBlue)
            }
            
            Slider(
                value: $targetSpeed,
                in: Double(fan.minSpeed)...Double(fan.maxSpeed),
                step: 100
            ) {
                Text("转速")
            } minimumValueLabel: {
                Text("\(fan.minSpeed)")
                    .font(.caption2)
            } maximumValueLabel: {
                Text("\(fan.maxSpeed)")
                    .font(.caption2)
            }
            .tint(.auraLogoBlue)
            .onChange(of: targetSpeed) { _, newValue in
                onSpeedChange(Int(newValue))
            }
        }
        .padding(.vertical, 8)
    }
    
    private var speedRangeInfo: some View {
        HStack(spacing: 24) {
            InfoPill(
                label: "最小转速",
                value: "\(fan.minSpeed) RPM",
                color: .auraPaleBlue
            )
            
            InfoPill(
                label: "最大转速",
                value: "\(fan.maxSpeed) RPM",
                color: .auraLogoBlue
            )
        }
    }
}

// MARK: - Info Pill

private struct InfoPill: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption.bold())
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Circular Progress View

private struct CircularProgressView: View {
    let progress: Double
    let lineWidth: CGFloat
    
    var body: some View {
        ZStack {
            // 背景圆环
            Circle()
                .stroke(
                    Color.gray.opacity(0.2),
                    lineWidth: lineWidth
                )
            
            // 进度圆环
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [.auraLogoBlue, .auraSkyBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5), value: progress)
        }
    }
}

// MARK: - Preview

#Preview {
    let smcService = SMCService()
    let persistenceService = PersistenceService()
    
    let viewModel = FanControlViewModel(
        smcService: smcService,
        persistenceService: persistenceService
    )
    
    return NavigationStack {
        FanListView(viewModel: viewModel)
    }
}