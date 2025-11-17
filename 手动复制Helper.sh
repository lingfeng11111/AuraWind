#!/bin/bash

# 手动复制 Helper Tool 到应用包（临时解决方案）

BUILD_DIR="/Users/lingfeng/Library/Developer/Xcode/DerivedData/AuraWind-fxfcuvsqjmorizgtbzgwuyvgdkmw/Build/Products/Debug"
APP_PATH="$BUILD_DIR/AuraWind.app"
HELPER_PATH="$BUILD_DIR/com.aurawind.AuraWind.SMCHelper"
LAUNCHD_PLIST="/Users/lingfeng/Desktop/Program/APP Projects/AuraWind/SMCHelper/Launchd.plist"

echo "📦 开始复制 Helper Tool..."

# 创建目录
mkdir -p "$APP_PATH/Contents/Library/LaunchServices"

# 复制 Helper Tool
if [ -f "$HELPER_PATH" ]; then
    cp "$HELPER_PATH" "$APP_PATH/Contents/Library/LaunchServices/"
    chmod +x "$APP_PATH/Contents/Library/LaunchServices/com.aurawind.AuraWind.SMCHelper"
    echo "✅ Helper Tool 已复制"
else
    echo "❌ Helper Tool 不存在: $HELPER_PATH"
    exit 1
fi

# 复制 Launchd.plist
if [ -f "$LAUNCHD_PLIST" ]; then
    cp "$LAUNCHD_PLIST" "$APP_PATH/Contents/Library/LaunchServices/"
    echo "✅ Launchd.plist 已复制"
else
    echo "❌ Launchd.plist 不存在: $LAUNCHD_PLIST"
    exit 1
fi

# 验证
echo ""
echo "📋 验证结果:"
ls -lh "$APP_PATH/Contents/Library/LaunchServices/"

echo ""
echo "✅ 完成！现在可以运行应用了"
