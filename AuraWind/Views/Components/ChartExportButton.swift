//
//  ChartExportButton.swift
//  AuraWind
//
//  Created by AuraWind Development Team on 2025-11-17.
//

import SwiftUI

/// 图表导出按钮组件
/// 提供图表导出功能的用户界面
struct ChartExportButton: View {
    
    // MARK: - Properties
    
    /// 图表数据点
    let dataPoints: [ChartDataPoint]
    
    /// 图表类型（用于文件名）
    let chartType: ChartType
    
    /// 导出视图模型
    @StateObject private var exportVM: ChartExportViewModel
    
    /// 是否显示导出菜单
    @State private var showExportMenu: Bool = false
    
    /// 是否显示导出设置
    @State private var showSettings: Bool = false
    
    /// 是否显示进度指示器
    @State private var showProgress: Bool = false
    
    /// 当前配色方案
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Initialization
    
    init(
        dataPoints: [ChartDataPoint],
        chartType: ChartType,
        persistenceService: PersistenceServiceProtocol
    ) {
        self.dataPoints = dataPoints
        self.chartType = chartType
        self._exportVM = StateObject(wrappedValue: ChartExportViewModel(
            persistenceService: persistenceService
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        Menu {
            exportMenuContent
        } label: {
            exportButtonLabel
        }
        .menuStyle(BorderlessButtonMenuStyle())
        .disabled(exportVM.isExporting)
        .sheet(isPresented: $showSettings) {
            exportSettingsSheet
        }
        .onChange(of: exportVM.shouldShowProgress) { _, show in
            withAnimation(.easeInOut(duration: 0.2)) {
                showProgress = show
            }
        }
    }
    
    // MARK: - Button Label
    
    private var exportButtonLabel: some View {
        HStack(spacing: 8) {
            if showProgress {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(0.8)
            } else {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14))
            }
            
            Text("导出")
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(colorScheme == .dark ? .white : .black)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark
                    ? Color.white.opacity(0.1)
                    : Color.black.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(colorScheme == .dark
                    ? Color.white.opacity(0.2)
                    : Color.black.opacity(0.1),
                    lineWidth: 1)
        )
    }
    
    // MARK: - Export Menu Content
    
    private var exportMenuContent: some View {
        Group {
            // 快速导出选项
            Section("快速导出") {
                ForEach(ChartExportFormat.allCases, id: \.self) { format in
                    Button {
                        performQuickExport(format: format)
                    } label: {
                        HStack {
                            Image(systemName: formatIcon(format))
                                .frame(width: 20)
                            Text(format.description)
                            Spacer()
                            Text(".\(format.fileExtension)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            Divider()
            
            // 高级选项
            Section("高级选项") {
                Button {
                    showSettings = true
                } label: {
                    Label("导出设置", systemImage: "gear")
                }
                
                if exportVM.lastExportedFile != nil {
                    Button {
                        exportVM.openLastExportedFile()
                    } label: {
                        Label("打开最后导出", systemImage: "folder")
                    }
                    
                    Button {
                        exportVM.revealLastExportedFile()
                    } label: {
                        Label("在Finder中显示", systemImage: "arrow.right.circle")
                    }
                }
            }
            
            // 批量导出（如果有多个数据系列）
            if hasMultipleSeries {
                Divider()
                
                Section("批量导出") {
                    Button {
                        performBatchExport()
                    } label: {
                        Label("导出所有系列", systemImage: "doc.on.doc")
                    }
                }
            }
        }
    }
    
    // MARK: - Export Settings Sheet
    
    private var exportSettingsSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 格式选择
                formatSelectionSection
                
                // 文件设置
                fileSettingsSection
                
                // 图像设置（PNG/SVG）
                if selectedFormatSupportsImageSettings {
                    imageSettingsSection
                }
                
                // 预览
                exportPreviewSection
                
                Spacer()
                
                // 操作按钮
                actionButtons
            }
            .padding()
            .navigationTitle("导出设置")
            #if os(macOS)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showSettings = false
                    }
                }
            }
            #else
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showSettings = false
                    }
                }
            }
            #endif
        }
        .frame(width: 400, height: 500)
    }
    
    // MARK: - Settings Sections
    
    private var formatSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("导出格式")
                .font(.headline)
            
            Picker("格式", selection: $exportVM.selectedFormat) {
                ForEach(ChartExportFormat.allCases, id: \.self) { format in
                    Text(format.description)
                        .tag(format)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    private var fileSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("文件设置")
                .font(.headline)
            
            LabeledContent("文件名") {
                TextField("文件名", text: $exportVM.exportFilename)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 200)
            }
            
            Toggle("包含图例", isOn: $exportVM.includeLegend)
            Toggle("包含网格", isOn: $exportVM.includeGrid)
        }
    }
    
    private var imageSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("图像设置")
                .font(.headline)
            
            LabeledContent("宽度") {
                HStack {
                    Slider(value: $exportVM.imageWidth, in: 800...2000, step: 100)
                        .frame(width: 120)
                    Text("\(Int(exportVM.imageWidth))px")
                        .frame(width: 50)
                }
            }
            
            LabeledContent("高度") {
                HStack {
                    Slider(value: $exportVM.imageHeight, in: 400...1200, step: 100)
                        .frame(width: 120)
                    Text("\(Int(exportVM.imageHeight))px")
                        .frame(width: 50)
                }
            }
        }
    }
    
    private var exportPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("预览")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("文件: \(exportVM.exportFilename).\(exportVM.selectedFormat.fileExtension)")
                        .font(.caption)
                    Text("格式: \(exportVM.getFormatDisplayName(exportVM.selectedFormat))")
                        .font(.caption)
                    Text("大小: \(Int(exportVM.imageWidth)) × \(Int(exportVM.imageHeight))px")
                        .font(.caption)
                }
                
                Spacer()
                
                if exportVM.shouldShowProgress {
                    VStack(spacing: 4) {
                        ProgressView(value: exportVM.exportProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(width: 100)
                        Text("\(exportVM.exportProgressPercentage)%")
                            .font(.caption)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark
                        ? Color.white.opacity(0.05)
                        : Color.black.opacity(0.03))
            )
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                exportVM.resetSettings()
            } label: {
                Text("重置")
            }
            
            Spacer()
            
            Button {
                showSettings = false
            } label: {
                Text("取消")
            }
            
            Button {
                performSettingsExport()
            } label: {
                Text("导出")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!exportVM.canExport)
        }
    }
    
    // MARK: - Helper Properties
    
    private var hasMultipleSeries: Bool {
        let uniqueLabels = Set(dataPoints.map { $0.label })
        return uniqueLabels.count > 1
    }
    
    private var selectedFormatSupportsImageSettings: Bool {
        switch exportVM.selectedFormat {
        case .png, .svg:
            return true
        case .csv:
            return false
        }
    }
    
    // MARK: - Actions
    
    private func performQuickExport(format: ChartExportFormat) {
        // 设置默认文件名
        let timestamp = getCurrentTimestamp()
        exportVM.exportFilename = "\(chartType.filePrefix)_\(timestamp)"
        exportVM.selectedFormat = format
        
        // 执行导出
        exportVM.exportChart(dataPoints)
    }
    
    private func performSettingsExport() {
        exportVM.exportChart(dataPoints)
        showSettings = false
    }
    
    private func performBatchExport() {
        // 按标签分组数据
        let groupedData = Dictionary(grouping: dataPoints) { $0.label }
        let dataGroups: [(String, [ChartDataPoint])] = groupedData.map { ($0.key, $0.value) }
        
        exportVM.exportMultipleCharts(dataGroups)
    }
    
    // MARK: - Helper Methods
    
    private func formatIcon(_ format: ChartExportFormat) -> String {
        switch format {
        case .png:
            return "photo"
        case .svg:
            return "wand.and.rays"
        case .csv:
            return "table"
        }
    }
    
    private func getCurrentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
}

// MARK: - Chart Type

enum ChartType {
    case temperature
    case fanSpeed
    case correlation
    case performance
    
    var filePrefix: String {
        switch self {
        case .temperature:
            return "Temperature"
        case .fanSpeed:
            return "FanSpeed"
        case .correlation:
            return "Correlation"
        case .performance:
            return "Performance"
        }
    }
    
    var displayName: String {
        switch self {
        case .temperature:
            return "温度图表"
        case .fanSpeed:
            return "风扇转速图表"
        case .correlation:
            return "关联图表"
        case .performance:
            return "性能图表"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ChartExportButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // 有数据状态
            ChartExportButton(
                dataPoints: ChartDataPoint.temperatureExamples(count: 30, label: "CPU"),
                chartType: .temperature,
                persistenceService: PersistenceService()
            )
            
            // 多系列数据
            ChartExportButton(
                dataPoints: ChartDataPoint.temperatureExamples(count: 30, label: "CPU") +
                           ChartDataPoint.temperatureExamples(count: 30, label: "GPU"),
                chartType: .temperature,
                persistenceService: PersistenceService()
            )
            
            // 空数据状态
            ChartExportButton(
                dataPoints: [],
                chartType: .temperature,
                persistenceService: PersistenceService()
            )
        }
        .padding()
        .auraBackground()
    }
}
#endif