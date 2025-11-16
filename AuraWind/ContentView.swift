//
//  ContentView.swift
//  AuraWind
//
//  Created by 凌峰 on 2025/11/16.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Logo 和标题
                VStack(spacing: Spacing.md) {
                    // 三叶风扇图标 (使用 wind 或自定义)
                    Image(systemName: "wind")
                        .font(.system(size: 80, weight: .light))
                        .foregroundStyle(LinearGradient.auraPrimary)
                        .glow(color: .auraBrightBlue, radius: 15)
                        .shadow(color: .shadowDark, radius: 10, x: -5, y: -5)
                        .shadow(color: .shadowLight, radius: 10, x: 5, y: 5)
                    
                    Text("AuraWind")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(LinearGradient.auraPrimary)
                    
                    Text("现代化的 macOS 风扇控制软件")
                        .font(.title3)
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .secondary)
                    
                    Text("弥散渐变毛玻璃风格")
                        .font(.caption)
                        .foregroundColor(.auraBrightBlue)
                }
                .padding(.top, Spacing.xl)
                
                // 演示卡片 - 统一毛玻璃风格
                HStack(spacing: Spacing.xl) {
                    // CPU 温度卡片
                    BlurGlassCard {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack {
                                Image(systemName: "cpu.fill")
                                    .foregroundColor(.auraBrightBlue)
                                    .font(.title2)
                                Spacer()
                                Circle()
                                    .fill(Color.statusNormal)
                                    .frame(width: 8, height: 8)
                                    .glow(color: .statusNormal, radius: 3)
                            }
                            
                            Text("CPU 温度")
                                .font(.caption)
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .adaptiveText.opacity(0.6))
                            
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("65")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundStyle(LinearGradient.auraPrimary)
                                Text("°C")
                                    .font(.title3)
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .adaptiveText.opacity(0.5))
                            }
                        }
                        .frame(width: 160)
                    }
                    
                    // 风扇转速卡片
                    BlurGlassCard {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack {
                                Image(systemName: "wind")
                                    .foregroundColor(.auraSkyBlue)
                                    .font(.title2)
                                Spacer()
                                Circle()
                                    .fill(Color.statusNormal)
                                    .frame(width: 8, height: 8)
                                    .glow(color: .statusNormal, radius: 3)
                            }
                            
                            Text("风扇转速")
                                .font(.caption)
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .adaptiveText.opacity(0.6))
                            
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("2500")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundStyle(LinearGradient.auraAccent)
                                Text("RPM")
                                    .font(.caption)
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .adaptiveText.opacity(0.5))
                            }
                        }
                        .frame(width: 160)
                    }
                }
                
                // 状态信息卡片
                BlurGlassCard {
                    VStack(spacing: Spacing.sm) {
                        Text("Phase 3.5: UI统一完成 ✓")
                            .font(.headline)
                            .foregroundColor(.auraBrightBlue)
                        
                        Text("弥散渐变毛玻璃风格")
                            .font(.subheadline)
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .secondary)
                        
                        Text("版本: 0.3.5 Final")
                            .font(.caption)
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                    }
                    .frame(maxWidth: 400)
                }
                
            }
            .padding(Spacing.xl)
        }
        .frame(minWidth: 800, minHeight: 600)
        .auraBackground()
    }
}

#Preview {
    ContentView()
}
