#!/bin/bash

# AuraWind 打包脚本 - 生成可分发的应用包
# 这个脚本会创建Archive并导出为可分发的应用

echo "🚀 开始打包 AuraWind..."

# 清理之前的构建
echo "🧹 清理之前的构建..."
rm -rf build/
rm -rf DerivedData/
rm -rf AuraWind.xcarchive

# 确保entitlements文件存在
if [ ! -f "AuraWind/AuraWind.entitlements" ]; then
    echo "❌ 找不到 entitlements 文件"
    exit 1
fi

# 确保Info.plist存在
if [ ! -f "AuraWind/Info.plist" ]; then
    echo "❌ 找不到 Info.plist 文件"
    exit 1
fi

# 创建Archive
echo "📦 创建Archive..."
xcodebuild -project AuraWind.xcodeproj \
           -scheme AuraWind \
           -configuration Release \
           -archivePath AuraWind.xcarchive \
           CODE_SIGN_IDENTITY="-" \
           CODE_SIGN_STYLE=Automatic \
           DEVELOPMENT_TEAM="" \
           ENABLE_HARDENED_RUNTIME=YES \
           CODE_SIGN_ENTITLEMENTS="AuraWind/AuraWind.entitlements" \
           archive

# 检查Archive结果
if [ $? -eq 0 ]; then
    echo "✅ Archive创建成功！"
    
    # 导出Archive为应用包
    echo "📤 导出应用包..."
    
    # 创建导出选项plist
    cat > ExportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string></string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>destination</key>
    <string>export</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>thinning</key>
    <string><none></string>
</dict>
</plist>
EOF
    
    xcodebuild -exportArchive \
               -archivePath AuraWind.xcarchive \
               -exportPath build/ \
               -exportOptionsPlist ExportOptions.plist
    
    if [ $? -eq 0 ]; then
        echo "✅ 应用包导出成功！"
        
        # 显示构建结果
        echo "📦 打包产物位置:"
        find build -name "*.app" -type d
        
        # 检查最终应用的entitlements
        APP_PATH=$(find build -name "*.app" -type d | head -n 1)
        if [ -n "$APP_PATH" ]; then
            echo "🔍 检查最终应用的 entitlements:"
            echo "完整的Entitlements信息:"
            codesign -d --entitlements - "$APP_PATH"
            
            # 验证签名
            echo "🔐 验证签名:"
            codesign -v "$APP_PATH"
            
            # 检查是否有SMC相关的entitlements
            echo "🔍 检查SMC权限:"
            codesign -d --entitlements - "$APP_PATH" | grep -i "smc\|iokit\|temporary-exception"
            
            echo ""
            echo "🎉 打包完成！"
            echo "📍 应用位置: $APP_PATH"
            echo ""
            echo "⚠️  重要提示："
            echo "   1. 这是一个开发者签名的应用"
            echo "   2. 首次运行时可能需要手动授权"
            echo "   3. 确保系统完整性保护(SIP)已启用"
            echo "   4. 如果遇到权限问题，请检查控制台日志"
            echo "   5. 使用 'codesign -d --entitlements - /path/to/app' 验证权限"
            echo ""
            echo "🔧 安装和运行："
            echo "   - 将应用拖到/Applications文件夹"
            echo "   - 首次运行时会提示授权"
            echo "   - 在系统设置中授予必要的权限"
            
            # 提供打开应用的选项
            echo ""
            read -p "是否立即打开应用进行测试？(y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                open "$APP_PATH"
            fi
        fi
        
        # 清理临时文件
        rm -f ExportOptions.plist
        
    else
        echo "❌ 应用包导出失败！"
        exit 1
    fi
    
else
    echo "❌ Archive创建失败！"
    echo "请检查错误信息并确保："
    echo "   - Xcode 已正确安装"
    echo "   - 所有依赖项已解决"
    echo "   - 代码签名配置正确"
    exit 1
fi

echo ""
echo "🎯 下一步："
echo "   1. 将应用安装到/Applications文件夹"
echo "   2. 首次运行时授予权限"
echo "   3. 测试SMC功能（温度、风扇控制）"
echo "   4. 如有问题，检查控制台日志"