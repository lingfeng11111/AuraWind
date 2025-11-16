//
//  View+Background.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025-11-16.
//  统一的背景渐变扩展
//

import SwiftUI

extension View {
    /// 应用统一的弥散渐变背景
    func auraBackground() -> some View {
        ZStack {
            AuraBackgroundGradient()
                .ignoresSafeArea()
            self
        }
    }
}

/// 统一的背景渐变组件
struct AuraBackgroundGradient: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        (colorScheme == .dark ? darkModeColor : lightModeColor)
    }
    
    /// 浅色模式背景色 - 纯白色
    private var lightModeColor: Color {
        Color.white
    }
    
    /// 深色模式背景色 - 统一深蓝黑
    private var darkModeColor: Color {
        Color(red: 0.06, green: 0.10, blue: 0.18)
    }
}