//
//  BlurGlassCard.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025-11-16.
//  统一的弥散渐变毛玻璃卡片 - 简约优雅
//

import SwiftUI

/// 弥散渐变毛玻璃卡片
/// 统一的UI组件,适用于整个应用
struct BlurGlassCard<Content: View>: View {
    
    // MARK: - Properties
    
    let content: Content
    var padding: CGFloat
    var cornerRadius: CGFloat
    
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Initialization
    
    init(
        padding: CGFloat = Spacing.md,
        cornerRadius: CGFloat = CornerRadius.lg,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    // MARK: - Body
    
    var body: some View {
        content
            .padding(padding)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(cardBorder)
            .shadow(color: shadowColor, radius: 12, x: 0, y: 4)
    }
    
    // MARK: - Background
    
    /// 卡片背景 - 深色模式毛玻璃，白天模式径向渐变
    @ViewBuilder
    private var cardBackground: some View {
        if colorScheme == .dark {
            // 深色模式 - 恢复毛玻璃效果
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                
                LinearGradient(
                    colors: [
                        .auraBrightBlue.opacity(0.3),
                        .auraSkyBlue.opacity(0.2),
                        .auraMediumBlue.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(0.15)
            }
        } else {
            // 白天模式 - 自适应径向渐变
            GeometryReader { geometry in
                RadialGradient(
                    colors: gradientColors,
                    center: .center,
                    startRadius: 0,
                    endRadius: max(geometry.size.width, geometry.size.height) * 0.7
                )
            }
        }
    }
    
    /// 渐变颜色 - 白天模式径向渐变
    private var gradientColors: [Color] {
        // 白天模式 - 径向渐变：中心白色，边缘淡蓝
        return [
            Color.white,                                          // 中心纯白
            Color(red: 245/255, green: 250/255, blue: 254/255),  // 过渡淡蓝
            Color(red: 235/255, green: 245/255, blue: 253/255)   // 边缘淡蓝
        ]
    }
    
    /// 卡片边框 - 细腻半透明
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(
                borderGradient,
                lineWidth: 1
            )
    }
    
    /// 边框渐变
    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark ? [
                .white.opacity(0.15),
                .auraBrightBlue.opacity(0.1),
                .white.opacity(0.05)
            ] : [
                // 白天模式 - 淡淡的蓝色边框
                .auraSkyBlue.opacity(0.25),
                .auraMediumBlue.opacity(0.20),
                .auraSoftBlue.opacity(0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// 阴影颜色
    private var shadowColor: Color {
        colorScheme == .dark
            ? .black.opacity(0.3)
            : .auraSoftBlue.opacity(0.15)
    }
}

// MARK: - Preview

#Preview("Light Mode") {
    ZStack {
        // 背景渐变
        LinearGradient(
            colors: [
                .auraBackground,
                .auraSoftBlue,
                .auraPaleCyan
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        VStack(spacing: 24) {
            BlurGlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "cpu.fill")
                            .foregroundColor(.auraBrightBlue)
                        Spacer()
                        Text("正常")
                            .font(.caption)
                            .foregroundColor(.statusNormal)
                    }
                    
                    Text("CPU 温度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("65°C")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.auraBrightBlue, .auraSkyBlue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }
            
            BlurGlassCard {
                VStack {
                    Image(systemName: "wind")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.auraBrightBlue, .auraSkyBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("AuraWind")
                        .font(.title2.bold())
                    Text("弥散渐变毛玻璃")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(32)
    }
}

#Preview("Dark Mode") {
    ZStack {
        // 深色背景渐变
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.08, blue: 0.15),
                Color(red: 0.08, green: 0.12, blue: 0.20),
                Color(red: 0.06, green: 0.10, blue: 0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        VStack(spacing: 24) {
            BlurGlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "thermometer.high")
                            .foregroundColor(.auraSkyBlue)
                        Spacer()
                        Text("警告")
                            .font(.caption)
                            .foregroundColor(.statusWarning)
                    }
                    
                    Text("GPU 温度")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("82°C")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }
            
            BlurGlassCard {
                VStack {
                    Image(systemName: "wind")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.auraBrightBlue, .auraSkyBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("AuraWind")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text("深色模式")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(32)
    }
    .preferredColorScheme(.dark)
}