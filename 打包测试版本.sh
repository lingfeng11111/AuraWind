#!/bin/bash

echo "🚀 开始打包 AuraWind Release 版本..."
echo ""

PROJECT_DIR="/Users/lingfeng/Desktop/Program/APP Projects/AuraWind"
PROJECT_FILE="$PROJECT_DIR/AuraWind.xcodeproj"
SCHEME="AuraWind"
BUILD_DIR="$PROJECT_DIR/Build"
APP_NAME="AuraWind.app"

# 清理旧的构建
echo "🧹 清理旧构建..."
rm -rf "$BUILD_DIR"
xcodebuild clean -project "$PROJECT_FILE" -scheme "$SCHEME" -configuration Release > /dev/null 2>&1

# 构建 Release 版本
echo "🔨 构建 Release 版本..."
xcodebuild \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    build

if [ $? -ne 0 ]; then
    echo "❌ 构建失败"
    exit 1
fi

echo "✅ 构建成功"
echo ""

# 找到构建的应用
BUILT_APP="$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME"

if [ ! -d "$BUILT_APP" ]; then
    echo "❌ 找不到构建的应用: $BUILT_APP"
    exit 1
fi

# 复制到桌面
DESKTOP_APP="$HOME/Desktop/$APP_NAME"
echo "📦 复制应用到桌面..."
rm -rf "$DESKTOP_APP"
cp -R "$BUILT_APP" "$DESKTOP_APP"

echo "✅ 应用已复制到桌面: $DESKTOP_APP"
echo ""

# 验证 Helper Tool
echo "🔍 验证 Helper Tool..."
HELPER_IN_APP="$DESKTOP_APP/Contents/Library/LaunchServices/com.aurawind.AuraWind.SMCHelper"

if [ -f "$HELPER_IN_APP" ]; then
    echo "✅ Helper Tool 已打包: $(ls -lh "$HELPER_IN_APP" | awk '{print $5}')"
else
    echo "⚠️  警告: Helper Tool 未找到"
    echo "   需要在 Xcode 中配置 Copy Files Phase"
fi

# 检查 Launchd.plist
LAUNCHD_IN_APP="$DESKTOP_APP/Contents/Library/LaunchServices/Launchd.plist"
if [ -f "$LAUNCHD_IN_APP" ]; then
    echo "✅ Launchd.plist 已打包"
else
    echo "⚠️  警告: Launchd.plist 未找到"
fi

echo ""
echo "🎉 打包完成！"
echo ""
echo "📝 测试步骤:"
echo "1. 双击桌面上的 AuraWind.app"
echo "2. 首次运行会请求安装 Helper Tool"
echo "3. 输入管理员密码"
echo "4. 查看是否能读取真实的硬件数据"
echo ""
echo "🐛 如果遇到问题:"
echo "- 查看控制台日志: Console.app"
echo "- 搜索 'AuraWind' 或 'SMCHelper'"
echo ""
echo "🗑️  卸载 Helper Tool (如果需要):"
echo "sudo launchctl unload /Library/LaunchDaemons/com.aurawind.AuraWind.SMCHelper.plist"
echo "sudo rm /Library/PrivilegedHelperTools/com.aurawind.AuraWind.SMCHelper"
echo "sudo rm /Library/LaunchDaemons/com.aurawind.AuraWind.SMCHelper.plist"
