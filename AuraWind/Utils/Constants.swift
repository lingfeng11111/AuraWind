//
//  Constants.swift
//  AuraWind
//
//  Created by AuraWind Team on 2025/11/16.
//

import SwiftUI

/// 应用常量定义
enum Constants {
    /// 应用信息
    enum App {
        static let name = "AuraWind"
        static let bundleIdentifier = "com.aurawind.app"
        static let version = "0.1.0"
    }
    
    /// 用户默认值键
    enum UserDefaultsKeys {
        static let hasLaunchedBefore = "hasLaunchedBefore"
        static let autoStartEnabled = "autoStartEnabled"
        static let activeCurveProfile = "activeCurveProfile"
        static let savedProfiles = "savedProfiles"
        static let temperatureUnit = "temperatureUnit"
        static let refreshInterval = "refreshInterval"
    }
    
    /// 间距系统
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    /// 圆角规范
    enum CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let full: CGFloat = 999
    }
    
    /// 动画时长
    enum AnimationDuration {
        static let fast: Double = 0.2
        static let normal: Double = 0.3
        static let slow: Double = 0.5
    }
    
    /// 温度相关常量
    enum Temperature {
        static let minValue: Double = 0
        static let maxValue: Double = 120
        static let warningThreshold: Double = 85
        static let dangerThreshold: Double = 95
    }
    
    /// 风扇相关常量
    enum Fan {
        static let minSpeed: Int = 1000
        static let maxSpeed: Int = 6000
        static let defaultSpeed: Int = 2000
    }
    
    /// 刷新间隔
    enum RefreshInterval {
        static let temperature: TimeInterval = 1.0
        static let fanSpeed: TimeInterval = 1.0
        static let chart: TimeInterval = 2.0
    }
}

/// 间距快捷访问
typealias Spacing = Constants.Spacing

/// 圆角快捷访问
typealias CornerRadius = Constants.CornerRadius