//
//  YAxisRangeEditor.swift
//  AuraWind
//
//  Created by AuraWind Development Team on 2025-11-17.
//

import SwiftUI

/// Y轴范围编辑器组件
/// 提供图表Y轴范围的自定义设置界面
struct YAxisRangeEditor: View {
    
    // MARK: - Properties
    
    /// 图表类型
    let chartType: ChartType
    
    /// 范围管理器
    @ObservedObject var rangeManager: ChartRangeManager
    
    /// 当前编辑的范围值
    @State private var tempRange: YAxisRange
    
    /// 是否显示预设选择器
    @State private var showPresets: Bool = false
    
    /// 当前配色方案
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Initialization
    
    init(chartType: ChartType, rangeManager: ChartRangeManager) {
        self.chartType = chartType
        self.rangeManager = rangeManager
        self._tempRange = State(initialValue: rangeManager.getRange(for: chartType))
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题和当前状态
            headerSection
            
            // 自动/手动模式切换
            modeToggleSection
            
            // 手动范围设置（当不是自动模式时显示）
            if !tempRange.isAutoRange {
                manualRangeSection
            }
            
            // 高级选项
            advancedOptionsSection
            
            // 预设范围
            presetsSection
            
            // 操作按钮
            actionButtonsSection
        }
        .padding()
        .frame(width: 400)
        .onChange(of: tempRange) { _, newRange in
            // 实时预览更新
            if newRange.validate() {
                rangeManager.setRange(newRange, for: chartType)
            }
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: chartIcon)
                    .font(.title2)
                    .foregroundColor(chartColor)
                
                Text(chartType.displayName)
                    .font(.headline)
                
                Spacer()
                
                if rangeManager.shouldShowRangeWarning(for: chartType) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .help("范围设置无效")
                }
            }
            
            Text("当前范围: \(rangeManager.getRangeDisplayText(for: chartType))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var modeToggleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("范围模式")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Picker("范围模式", selection: $tempRange.isAutoRange) {
                Text("自动范围").tag(true)
                Text("手动设置").tag(false)
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: tempRange.isAutoRange) { _, isAuto in
                if isAuto {
                    // 切换到自动模式时重置为默认范围
                    tempRange = YAxisRange(
                        minValue: nil,
                        maxValue: nil,
                        isAutoRange: true,
                        allowZoom: tempRange.allowZoom
                    )
                }
            }
        }
    }
    
    private var manualRangeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("手动范围设置")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // 最小值输入
            LabeledContent("最小值") {
                HStack {
                    TextField("最小值", value: Binding(
                        get: { tempRange.minValue ?? 0 },
                        set: { tempRange.minValue = $0 }
                    ), format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 100)
                    
                    Button {
                        tempRange.minValue = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // 最大值输入
            LabeledContent("最大值") {
                HStack {
                    TextField("最大值", value: Binding(
                        get: { tempRange.maxValue ?? 100 },
                        set: { tempRange.maxValue = $0 }
                    ), format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 100)
                    
                    Button {
                        tempRange.maxValue = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // 范围验证提示
            if !tempRange.validate() {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("最大值必须大于最小值")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            // 快速预设按钮
            HStack(spacing: 8) {
                Text("快速预设:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(quickPresets, id: \.self) { preset in
                    Button {
                        applyQuickPreset(preset)
                    } label: {
                        Text(getPresetDisplayName(preset))
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    private var advancedOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("高级选项")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Toggle("允许缩放", isOn: $tempRange.allowZoom)
                .help("允许用户通过手势缩放图表")
        }
    }
    
    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("范围预设")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button {
                    showPresets.toggle()
                } label: {
                    Image(systemName: showPresets ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            
            if showPresets {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(rangeManager.getRangePresets(for: chartType), id: \.self) { preset in
                        Button {
                            tempRange = preset
                        } label: {
                            VStack(spacing: 4) {
                                Text(getPresetDisplayName(preset))
                                    .font(.caption)
                                
                                Text(getPresetRangeText(preset))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isSelectedPreset(preset) ? chartColor.opacity(0.2) : Color.clear)
                                    .stroke(isSelectedPreset(preset) ? chartColor : Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            Button {
                rangeManager.resetToDefault(for: chartType)
                tempRange = rangeManager.getRange(for: chartType)
            } label: {
                Text("重置为默认")
            }
            
            Spacer()
            
            Button {
                // 取消更改，恢复原始值
                tempRange = rangeManager.getRange(for: chartType)
            } label: {
                Text("取消")
            }
            
            Button {
                // 应用更改
                if tempRange.validate() {
                    rangeManager.setRange(tempRange, for: chartType)
                }
            } label: {
                Text("应用")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!tempRange.validate())
        }
    }
    
    // MARK: - Helper Properties
    
    private var quickPresets: [YAxisRange] {
        switch chartType {
        case .temperature:
            return [
                YAxisRange(minValue: 0, maxValue: 50, isAutoRange: false, allowZoom: true),
                YAxisRange(minValue: 30, maxValue: 70, isAutoRange: false, allowZoom: true),
                YAxisRange(minValue: 0, maxValue: 100, isAutoRange: false, allowZoom: true)
            ]
        case .fanSpeed:
            return [
                YAxisRange(minValue: 0, maxValue: 2000, isAutoRange: false, allowZoom: true),
                YAxisRange(minValue: 1000, maxValue: 4000, isAutoRange: false, allowZoom: true),
                YAxisRange(minValue: 0, maxValue: 6000, isAutoRange: false, allowZoom: true)
            ]
        case .performance:
            return [
                YAxisRange(minValue: 0, maxValue: 50, isAutoRange: false, allowZoom: true),
                YAxisRange(minValue: 0, maxValue: 80, isAutoRange: false, allowZoom: true),
                YAxisRange(minValue: 0, maxValue: 100, isAutoRange: false, allowZoom: true)
            ]
        case .correlation:
            return [
                YAxisRange(minValue: 0, maxValue: 50, isAutoRange: false, allowZoom: true),
                YAxisRange(minValue: 30, maxValue: 70, isAutoRange: false, allowZoom: true),
                YAxisRange(minValue: 0, maxValue: 100, isAutoRange: false, allowZoom: true)
            ]
        }
    }
    
    private var chartIcon: String {
        switch chartType {
        case .temperature:
            return "thermometer"
        case .fanSpeed:
            return "fan"
        case .correlation:
            return "chart.xyaxis.line"
        case .performance:
            return "cpu"
        }
    }
    
    private var chartColor: Color {
        switch chartType {
        case .temperature:
            return .orange
        case .fanSpeed:
            return .blue
        case .correlation:
            return .purple
        case .performance:
            return .green
        }
    }
    
    // MARK: - Helper Methods
    
    private func getPresetDisplayName(_ preset: YAxisRange) -> String {
        guard let min = preset.minValue, let max = preset.maxValue else {
            return "自定义"
        }
        
        let range = max - min
        switch chartType {
        case .temperature:
            if range <= 30 {
                return "精细"
            } else if range <= 60 {
                return "标准"
            } else {
                return "宽范围"
            }
        case .fanSpeed:
            if max <= 2000 {
                return "低速"
            } else if max <= 4000 {
                return "中速"
            } else {
                return "全速"
            }
        case .performance:
            if max <= 50 {
                return "低负载"
            } else if max <= 80 {
                return "中负载"
            } else {
                return "全负载"
            }
        case .correlation:
            // 关联图表使用温度逻辑
            guard let min = preset.minValue, let max = preset.maxValue else {
                return "自定义"
            }
            let range = max - min
            if range <= 30 {
                return "精细"
            } else if range <= 60 {
                return "标准"
            } else {
                return "宽范围"
            }
        }
    }
    
    private func getPresetRangeText(_ preset: YAxisRange) -> String {
        guard let min = preset.minValue, let max = preset.maxValue else {
            return "自动"
        }
        return String(format: "%.0f-%.0f", min, max)
    }
    
    private func isSelectedPreset(_ preset: YAxisRange) -> Bool {
        return preset.minValue == tempRange.minValue &&
               preset.maxValue == tempRange.maxValue &&
               !tempRange.isAutoRange
    }
    
    private func applyQuickPreset(_ preset: YAxisRange) {
        tempRange = YAxisRange(
            minValue: preset.minValue,
            maxValue: preset.maxValue,
            isAutoRange: false,
            allowZoom: tempRange.allowZoom
        )
    }
}

// MARK: - Preview

#if DEBUG
struct YAxisRangeEditor_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            YAxisRangeEditor(
                chartType: .temperature,
                rangeManager: ChartRangeManager(persistenceService: PersistenceService())
            )
            
            YAxisRangeEditor(
                chartType: .fanSpeed,
                rangeManager: ChartRangeManager(persistenceService: PersistenceService())
            )
            
            YAxisRangeEditor(
                chartType: .performance,
                rangeManager: ChartRangeManager(persistenceService: PersistenceService())
            )
        }
        .padding()
        .frame(width: 450)
        .auraBackground()
    }
}
#endif