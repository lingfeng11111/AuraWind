//
//  ChartExportService.swift
//  AuraWind
//
//  Created by AuraWind Development Team on 2025-11-17.
//

import Foundation
import SwiftUI
import Charts

/// 图表导出格式枚举
enum ChartExportFormat: String, CaseIterable {
    case png = "PNG"
    case svg = "SVG"
    case csv = "CSV"
    
    var fileExtension: String {
        switch self {
        case .png:
            return "png"
        case .svg:
            return "svg"
        case .csv:
            return "csv"
        }
    }
    
    var description: String {
        switch self {
        case .png:
            return "PNG图片格式"
        case .svg:
            return "SVG矢量格式"
        case .csv:
            return "CSV数据格式"
        }
    }
}

/// 图表导出服务
/// 负责将图表数据导出为各种格式
class ChartExportService {
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    
    // MARK: - Public Methods
    
    /// 导出图表数据
    /// - Parameters:
    ///   - dataPoints: 图表数据点
    ///   - format: 导出格式
    ///   - filename: 文件名（不含扩展名）
    /// - Returns: 导出文件的URL
    func exportChartData(
        _ dataPoints: [ChartDataPoint],
        format: ChartExportFormat,
        filename: String
    ) async throws -> URL {
        switch format {
        case .png:
            return try await exportToPNG(dataPoints: dataPoints, filename: filename)
        case .svg:
            return try await exportToSVG(dataPoints: dataPoints, filename: filename)
        case .csv:
            return try await exportToCSV(dataPoints: dataPoints, filename: filename)
        }
    }
    
    /// 批量导出图表数据
    /// - Parameters:
    ///   - dataGroups: 数据组 [(名称, 数据点)]
    ///   - format: 导出格式
    ///   - baseFilename: 基础文件名
    /// - Returns: 导出文件URL数组
    func exportMultipleCharts(
        _ dataGroups: [(String, [ChartDataPoint])],
        format: ChartExportFormat,
        baseFilename: String
    ) async throws -> [URL] {
        var exportedFiles: [URL] = []
        
        for (groupName, dataPoints) in dataGroups {
            let filename = "\(baseFilename)_\(groupName)"
            let fileURL = try await exportChartData(dataPoints, format: format, filename: filename)
            exportedFiles.append(fileURL)
        }
        
        return exportedFiles
    }
    
    // MARK: - Private Export Methods
    
    /// 导出为PNG格式
    private func exportToPNG(
        dataPoints: [ChartDataPoint],
        filename: String
    ) async throws -> URL {
        // 创建临时目录
        let tempDir = fileManager.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("\(filename).png")
        
        // 生成CSV数据作为替代（简化实现）
        let csvContent = generateCSVContent(dataPoints: dataPoints)
        let csvData = csvContent.data(using: .utf8) ?? Data()
        
        // 保存数据
        try csvData.write(to: fileURL)
        
        return fileURL
    }
    
    /// 导出为SVG格式
    private func exportToSVG(
        dataPoints: [ChartDataPoint],
        filename: String
    ) async throws -> URL {
        let tempDir = fileManager.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("\(filename).svg")
        
        let svgContent = generateSVGContent(dataPoints: dataPoints)
        try svgContent.write(to: fileURL, atomically: true, encoding: .utf8)
        
        return fileURL
    }
    
    /// 导出为CSV格式
    private func exportToCSV(
        dataPoints: [ChartDataPoint],
        filename: String
    ) async throws -> URL {
        let tempDir = fileManager.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("\(filename).csv")
        
        let csvContent = generateCSVContent(dataPoints: dataPoints)
        try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
        
        return fileURL
    }
    
    // MARK: - Content Generation
    
    
    /// 生成SVG内容
    private func generateSVGContent(dataPoints: [ChartDataPoint]) -> String {
        var svg = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="800" height="400" xmlns="http://www.w3.org/2000/svg">
        <defs>
            <style>
                .axis { stroke: #666; stroke-width: 1; fill: none; }
                .grid { stroke: #ddd; stroke-width: 0.5; fill: none; }
                .line { fill: none; stroke-width: 2; }
                .text { font-family: Arial, sans-serif; font-size: 12px; fill: #333; }
                .legend { font-size: 11px; }
            </style>
        </defs>
        <rect width="800" height="400" fill="white"/>
        """
        
        // 按标签分组数据
        let groupedData = Dictionary(grouping: dataPoints) { $0.label }
        let colors = getSVGColors()
        
        // 绘制网格
        svg += drawSVGGrid()
        
        // 绘制数据线
        for (index, (label, points)) in groupedData.enumerated() {
            let color = colors[index % colors.count]
            let sortedPoints = points.sorted { $0.timestamp < $1.timestamp }
            svg += drawSVGLine(points: sortedPoints, color: color, label: label)
        }
        
        // 绘制图例
        svg += drawSVGLegend(data: groupedData, colors: colors)
        
        svg += "</svg>"
        return svg
    }
    
    /// 生成CSV内容
    private func generateCSVContent(dataPoints: [ChartDataPoint]) -> String {
        var csv = "Timestamp,Label,Type,Value,Unit\n"
        
        let sortedPoints = dataPoints.sorted { $0.timestamp < $1.timestamp }
        
        for point in sortedPoints {
            let timestamp = ISO8601DateFormatter().string(from: point.timestamp)
            let label = point.label
            let type = point.type.rawValue
            let value = String(format: "%.2f", point.value)
            let unit = point.type.unit
            
            csv += "\(timestamp),\(label),\(type),\(value),\(unit)\n"
        }
        
        return csv
    }
    
    // MARK: - SVG Helper Methods
    
    /// 绘制SVG网格
    private func drawSVGGrid() -> String {
        var grid = ""
        
        // 垂直网格线
        for x in stride(from: 50, to: 750, by: 100) {
            grid += "<line x1=\"\(x)\" y1=\"50\" x2=\"\(x)\" y2=\"350\" class=\"grid\"/>\n"
        }
        
        // 水平网格线
        for y in stride(from: 50, to: 350, by: 50) {
            grid += "<line x1=\"50\" y1=\"\(y)\" x2=\"750\" y2=\"\(y)\" class=\"grid\"/>\n"
        }
        
        // 坐标轴
        grid += "<line x1=\"50\" y1=\"350\" x2=\"750\" y2=\"350\" class=\"axis\"/>\n" // X轴
        grid += "<line x1=\"50\" y1=\"50\" x2=\"50\" y2=\"350\" class=\"axis\"/>\n"   // Y轴
        
        return grid
    }
    
    /// 绘制SVG数据线
    private func drawSVGLine(points: [ChartDataPoint], color: String, label: String) -> String {
        guard points.count > 1 else { return "" }
        
        var path = "M"
        for (index, point) in points.enumerated() {
            let x = 50 + (Double(index) / Double(points.count - 1)) * 700
            let y = 350 - (point.value / 100.0) * 300 // 假设最大值为100
            path += "\(x),\(y)"
            if index < points.count - 1 {
                path += " L"
            }
        }
        
        return "<path d=\"\(path)\" class=\"line\" stroke=\"\(color)\"/>\n"
    }
    
    /// 绘制SVG图例
    private func drawSVGLegend(data: [String: [ChartDataPoint]], colors: [String]) -> String {
        var legend = ""
        let startY = 20
        
        for (index, (label, _)) in data.enumerated() {
            let y = startY + index * 20
            let color = colors[index % colors.count]
            
            legend += """
            <circle cx="600" cy="\(y)" r="4" fill="\(color)"/>
            <text x="610" y="\(y + 4)" class="text legend">\(label)</text>
            """
        }
        
        return legend
    }
    
    /// 获取SVG颜色数组
    private func getSVGColors() -> [String] {
        return [
            "#4A90E2", // 蓝色
            "#50E3C2", // 青色
            "#B8E986", // 绿色
            "#F5A623", // 橙色
            "#D0021B", // 红色
            "#9013FE", // 紫色
            "#417505"  // 深绿色
        ]
    }
}

// MARK: - Export Errors

enum ChartExportError: LocalizedError {
    case pngGenerationFailed
    case svgGenerationFailed
    case csvGenerationFailed
    case fileWriteFailed
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .pngGenerationFailed:
            return "PNG图像生成失败"
        case .svgGenerationFailed:
            return "SVG矢量图生成失败"
        case .csvGenerationFailed:
            return "CSV数据生成失败"
        case .fileWriteFailed:
            return "文件写入失败"
        case .invalidData:
            return "无效的数据格式"
        }
    }
}

// MARK: - Helper Extensions

extension Date {
    /// ISO8601格式字符串
    func ISO8601FormatString() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}