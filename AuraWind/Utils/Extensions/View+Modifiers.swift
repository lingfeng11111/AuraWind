//
//  View+Modifiers.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025/11/16.
//

import SwiftUI

// MARK: - 发光效果修饰器

struct GlowModifier: ViewModifier {
    var color: Color
    var radius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.5), radius: radius)
            .shadow(color: color.opacity(0.3), radius: radius * 2)
            .shadow(color: color.opacity(0.1), radius: radius * 3)
    }
}

extension View {
    /// 添加发光效果
    /// - Parameters:
    ///   - color: 发光颜色
    ///   - radius: 发光半径
    func glow(color: Color, radius: CGFloat = 10) -> some View {
        modifier(GlowModifier(color: color, radius: radius))
    }
}

// MARK: - 点击反馈修饰器

struct TapFeedbackModifier: ViewModifier {
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .opacity(isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: Constants.AnimationDuration.fast), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

extension View {
    /// 添加点击反馈效果
    func tapFeedback() -> some View {
        modifier(TapFeedbackModifier())
    }
}

// MARK: - 悬停效果修饰器

struct HoverEffectModifier: ViewModifier {
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .shadow(
                color: .auraBlue.opacity(isHovered ? 0.3 : 0),
                radius: isHovered ? 15 : 0
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension View {
    /// 添加悬停效果
    func hoverEffect() -> some View {
        modifier(HoverEffectModifier())
    }
}

// MARK: - 淡入淡出修饰器

extension View {
    /// 淡入淡出动画
    /// - Parameter isVisible: 是否可见
    func fadeInOut(isVisible: Bool) -> some View {
        self
            .opacity(isVisible ? 1 : 0)
            .animation(.easeInOut(duration: Constants.AnimationDuration.normal), value: isVisible)
    }
    
    /// 滑动进入动画
    /// - Parameters:
    ///   - edge: 滑动方向
    ///   - isVisible: 是否可见
    func slideIn(from edge: Edge, isVisible: Bool) -> some View {
        self
            .offset(
                x: edge == .leading && !isVisible ? -100 : (edge == .trailing && !isVisible ? 100 : 0),
                y: edge == .top && !isVisible ? -100 : (edge == .bottom && !isVisible ? 100 : 0)
            )
            .opacity(isVisible ? 1 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isVisible)
    }
}

// MARK: - 可访问性修饰器

extension View {
    /// 设置可访问性信息
    /// - Parameters:
    ///   - label: 标签
    ///   - hint: 提示
    ///   - value: 值
    func accessibilitySetup(
        label: String,
        hint: String? = nil,
        value: String? = nil
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
    }
}

// MARK: - 卡片样式修饰器

struct CardStyleModifier: ViewModifier {
    var padding: CGFloat = Spacing.md
    var cornerRadius: CGFloat = CornerRadius.lg
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .shadowMedium, radius: 10, y: 5)
    }
}

extension View {
    /// 应用卡片样式
    /// - Parameters:
    ///   - padding: 内边距
    ///   - cornerRadius: 圆角半径
    func cardStyle(padding: CGFloat = Spacing.md, cornerRadius: CGFloat = CornerRadius.lg) -> some View {
        modifier(CardStyleModifier(padding: padding, cornerRadius: cornerRadius))
    }
}