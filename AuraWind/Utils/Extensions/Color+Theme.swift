//
//  Color+Theme.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025/11/16.
//

import SwiftUI

extension Color {
    // MARK: - Logo 品牌色系 (基于实际 Logo 颜色)
    
    /// 主背景色 - 浅蓝灰 (最大占比)
    static let auraBackground = Color(red: 229/255, green: 237/255, blue: 246/255)
    
    /// 柔和蓝色
    static let auraSoftBlue = Color(red: 207/255, green: 221/255, blue: 245/255)
    
    /// 浅灰白色
    static let auraLightGray = Color(red: 242/255, green: 245/255, blue: 244/255)
    
    /// 明亮蓝色 - 主色调
    static let auraBrightBlue = Color(red: 103/255, green: 172/255, blue: 240/255)
    
    /// 淡青色
    static let auraCyan = Color(red: 219/255, green: 247/255, blue: 247/255)
    
    /// 中蓝色
    static let auraMediumBlue = Color(red: 178/255, green: 210/255, blue: 243/255)
    
    /// 天蓝色
    static let auraSkyBlue = Color(red: 133/255, green: 208/255, blue: 244/255)
    
    /// 极淡青色
    static let auraPaleCyan = Color(red: 230/255, green: 247/255, blue: 244/255)
    
    /// 半透明白色 (用于玻璃效果)
    static let auraGlassWhite = Color(red: 246/255, green: 249/255, blue: 249/255).opacity(96/255)
    
    // MARK: - 便捷别名
    
    /// Logo主蓝色 (兼容性别名)
    static let auraLogoBlue = auraBrightBlue
    
    /// 淡蓝色 (兼容性别名)
    static let auraLightBlue = auraSkyBlue
    
    /// 浅灰蓝色 (兼容性别名)
    static let auraLightGrayBlue = auraBackground
    
    /// 淡蓝色 (兼容性别名)
    static let auraPaleBlue = auraPaleCyan
    
    /// 主色调 (用于按钮、链接等)
    static let auraPrimary = auraBrightBlue
    
    /// 次要色 (用于辅助元素)
    static let auraSecondary = auraMediumBlue
    
    /// 强调色 (用于高亮)
    static let auraAccent = auraSkyBlue
    
    // MARK: - 状态色
    
    /// 正常状态
    static let statusNormal = Color.green
    
    /// 警告状态
    static let statusWarning = Color.orange
    
    /// 危险状态
    static let statusDanger = Color.red
    
    /// 信息状态
    static let statusInfo = auraBrightBlue
    
    // MARK: - 液态玻璃效果色 (新拟物风格)
    
    /// 玻璃背景色 - 使用 Logo 半透明白色
    static let glassBackground = auraGlassWhite
    
    /// 玻璃边框色 - 淡青色边框
    static let glassBorder = auraPaleCyan.opacity(0.6)
    
    /// 玻璃高光色 - 明亮区域
    static let glassHighlight = auraLightGray.opacity(0.8)
    
    /// 玻璃阴影色 - 柔和蓝色阴影
    static let glassShadow = auraSoftBlue.opacity(0.3)
    
    // MARK: - 新拟物阴影 (Neumorphism)
    
    /// 浅色阴影 (凸起效果)
    static let shadowLight = Color.white.opacity(0.8)
    
    /// 深色阴影 (凹陷效果)
    static let shadowDark = auraSoftBlue.opacity(0.2)
    
    /// 环境阴影
    static let shadowAmbient = auraBrightBlue.opacity(0.05)
    
    /// 中等阴影 (用于卡片等)
    static let shadowMedium = auraSoftBlue.opacity(0.15)
    
    /// 通用蓝色别名 (指向主品牌蓝色)
    static let auraBlue = auraBrightBlue
    
    // MARK: - 深色模式专用色
    
    /// 深色模式背景色 - 深邃蓝黑
    static let auraDarkBackground = Color(red: 15/255, green: 23/255, blue: 38/255)
    
    /// 深色模式卡片背景 - 深蓝灰
    static let auraDarkCard = Color(red: 20/255, green: 30/255, blue: 48/255)
    
    /// 深色模式边框高光
    static let auraDarkBorder = Color(red: 60/255, green: 120/255, blue: 180/255)
    
    // MARK: - 径向渐变色(用于炫酷背景)
    
    /// 径向渐变 - 深色中心
    static let radialDarkCenter = Color(red: 15/255, green: 23/255, blue: 38/255)
    
    /// 径向渐变 - 蓝色光晕1
    static let radialBlueGlow1 = Color(red: 26/255, green: 99/255, blue: 137/255)
    
    /// 径向渐变 - 蓝色光晕2
    static let radialBlueGlow2 = Color(red: 36/255, green: 137/255, blue: 191/255)
    
    /// 径向渐变 - 浅蓝边缘
    static let radialLightEdge = Color(red: 13/255, green: 94/255, blue: 133/255)
    
    // MARK: - 自适应颜色
    
    /// 创建自适应颜色（支持深色/浅色模式）
    /// - Parameters:
    ///   - light: 浅色模式下的颜色
    ///   - dark: 深色模式下的颜色
    /// - Returns: 自适应颜色
    static func adaptive(light: Color, dark: Color) -> Color {
        #if os(macOS)
        return Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(dark)
                : NSColor(light)
        })
        #else
        return Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
        #endif
    }
    
    /// 自适应背景色 - 使用 Logo 背景色
    static let adaptiveBackground = adaptive(
        light: auraBackground,
        dark: Color(red: 45/255, green: 55/255, blue: 72/255)
    )
    
    /// 自适应文本色
    static let adaptiveText = adaptive(
        light: Color(red: 51/255, green: 65/255, blue: 85/255),
        dark: auraLightGray
    )
    
    /// 自适应卡片背景 - 液态玻璃效果
    static let adaptiveCardBackground = adaptive(
        light: auraLightGray.opacity(0.7),
        dark: Color(red: 55/255, green: 65/255, blue: 82/255).opacity(0.3)
    )
}

// MARK: - 渐变预设 (基于 Logo 配色)

extension LinearGradient {
    /// AuraWind 主渐变 - 明亮蓝到天蓝
    static let auraPrimary = LinearGradient(
        colors: [.auraBrightBlue, .auraSkyBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// 柔和渐变 - 用于背景
    static let auraSoft = LinearGradient(
        colors: [.auraBackground, .auraSoftBlue],
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// 玻璃渐变效果 - 新拟物风格
    static let glassEffect = LinearGradient(
        colors: [
            Color.auraLightGray.opacity(0.4),
            Color.auraPaleCyan.opacity(0.2),
            Color.auraGlassWhite
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// 边框渐变效果 - 淡青色系
    static let borderGradient = LinearGradient(
        colors: [
            Color.auraCyan.opacity(0.5),
            Color.auraPaleCyan.opacity(0.3),
            Color.auraLightGray.opacity(0.2)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// 强调渐变 - 用于按钮和高亮
    static let auraAccent = LinearGradient(
        colors: [.auraBrightBlue, .auraMediumBlue],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    /// 新拟物高光渐变
    static let neumorphismLight = LinearGradient(
        colors: [
            Color.white.opacity(0.9),
            Color.auraLightGray.opacity(0.6)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// 新拟物阴影渐变
    static let neumorphismShadow = LinearGradient(
        colors: [
            Color.auraSoftBlue.opacity(0.3),
            Color.auraMediumBlue.opacity(0.1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}