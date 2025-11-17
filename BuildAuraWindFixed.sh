#!/bin/bash

# AuraWind 构建脚本 - 修复SMC权限版本
# 这个脚本会构建应用并确保正确的权限设置

echo "🚀 开始构建 AuraWind..."

# 清理之前的构建
echo "🧹 清理之前的构建..."
rm -rf build/
rm -rf DerivedData/

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

# 构建应用
echo "🔨 构建应用..."
xcodebuild -project AuraWind.xcodeproj \
           -scheme AuraWind \
           -configuration Release \
           -derivedDataPath DerivedData \
           CODE_SIGN_IDENTITY="-" \
           CODE_SIGN_STYLE=Automatic \
           DEVELOPMENT_TEAM="" \
           ENABLE_HARDENED_RUNTIME=YES \
           OTHER_CODE_SIGN_FLAGS="--deep --force" \
           clean build

# 检查构建结果
if [ $? -eq 0 ]; then
    echo "✅ 构建成功！"
    
    # 显示构建结果
    echo "📦 构建产物位置:"
    find DerivedData -name "*.app" -type d
    
    # 检查entitlements
    echo "🔍 检查 entitlements:"
    APP_PATH=$(find DerivedData -name "*.app" -type d | head -n 1)
    if [ -n "$APP_PATH" ]; then
        codesign -d --entitlements - "$APP_PATH"
        
        # 验证签名
        echo "🔐 验证签名:"
        codesign -v "$APP_PATH"
    fi
    
    echo ""
    echo "🎉 构建完成！"
    echo "⚠️  重要提示："
    echo "   1. 应用需要管理员权限来访问SMC"
    echo "   2. 首次运行时可能需要手动授权"
    echo "   3. 确保系统完整性保护(SIP)已启用"
    echo "   4. 如果遇到权限问题，请检查控制台日志"
    
else
    echo "❌ 构建失败！"
    echo "请检查错误信息并确保："
    echo "   - Xcode 已正确安装"
    echo "   - 所有依赖项已解决"
    echo "   - 代码签名配置正确"
    exit 1
fi