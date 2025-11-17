#!/bin/bash

# 完整的打包和安装脚本（参考 Macs Fan Control 的方式）
# 适用于 ad-hoc 签名的开发环境

set -e

echo "🚀 AuraWind 完整打包和安装脚本"
echo "================================"
echo ""

# 路径配置
PROJECT_DIR="/Users/lingfeng/Desktop/Program/APP Projects/AuraWind"
BUILD_DIR="$PROJECT_DIR/Build/DerivedData/Build/Products/Release"
APP_PATH="$BUILD_DIR/AuraWind.app"
HELPER_TOOL="$BUILD_DIR/com.aurawind.AuraWind.SMCHelper"
DESKTOP_APP="$HOME/Desktop/AuraWind.app"

# 系统安装路径
HELPER_INSTALL_PATH="/Library/PrivilegedHelperTools/com.aurawind.AuraWind.SMCHelper"
LAUNCHD_PLIST_PATH="/Library/LaunchDaemons/com.aurawind.AuraWind.SMCHelper.plist"

# 步骤 1: 清理旧的构建
echo "1️⃣ 清理旧的构建..."
cd "$PROJECT_DIR"
xcodebuild clean -project AuraWind.xcodeproj -configuration Release > /dev/null 2>&1 || true

# 步骤 2: 编译项目
echo "2️⃣ 编译项目..."
xcodebuild -project AuraWind.xcodeproj \
  -scheme AuraWind \
  -configuration Release \
  -derivedDataPath "./Build/DerivedData" \
  build 2>&1 | grep -E "(BUILD|error:)" | tail -5

if [ ! -f "$HELPER_TOOL" ]; then
    echo "❌ Helper Tool 编译失败"
    exit 1
fi

echo "   ✅ 编译成功"

# 步骤 3: 将 Helper Tool 打包到应用内部（模仿 Macs Fan Control）
echo "3️⃣ 将 Helper Tool 打包到应用内部..."
HELPER_DIR="$APP_PATH/Contents/Library/LaunchServices"
mkdir -p "$HELPER_DIR"
cp "$HELPER_TOOL" "$HELPER_DIR/"
chmod 755 "$HELPER_DIR/com.aurawind.AuraWind.SMCHelper"

echo "   ✅ Helper Tool 已打包到应用内部"

# 步骤 4: 重新签名应用（ad-hoc）
echo "4️⃣ 重新签名应用..."
codesign --force --deep --sign - "$APP_PATH" 2>&1 | grep -v "replacing existing signature" || true

echo "   ✅ 应用已签名"

# 步骤 5: 复制到桌面
echo "5️⃣ 复制应用到桌面..."
rm -rf "$DESKTOP_APP"
cp -R "$APP_PATH" "$DESKTOP_APP"

echo "   ✅ 应用已复制到桌面"

# 步骤 6: 安装 Helper Tool（需要 sudo）
echo "6️⃣ 安装 Helper Tool 到系统目录..."
echo "   （需要管理员权限）"

if [ "$EUID" -ne 0 ]; then
    echo ""
    echo "⚠️  需要 sudo 权限来安装 Helper Tool"
    echo "请运行: sudo $0"
    echo ""
    echo "或者手动运行:"
    echo "sudo cp '$HELPER_DIR/com.aurawind.AuraWind.SMCHelper' '$HELPER_INSTALL_PATH'"
    echo "sudo cp '$PROJECT_DIR/SMCHelper/Launchd.plist' '$LAUNCHD_PLIST_PATH'"
    echo "sudo launchctl load '$LAUNCHD_PLIST_PATH'"
    exit 0
fi

# 停止旧的 Helper Tool
echo "   停止旧的 Helper Tool..."
launchctl unload "$LAUNCHD_PLIST_PATH" 2>/dev/null || true
pkill -9 -f "com.aurawind.AuraWind.SMCHelper" 2>/dev/null || true
sleep 1

# 复制 Helper Tool
echo "   复制 Helper Tool..."
cp "$HELPER_DIR/com.aurawind.AuraWind.SMCHelper" "$HELPER_INSTALL_PATH"
chmod 755 "$HELPER_INSTALL_PATH"
chown root:wheel "$HELPER_INSTALL_PATH"

# 复制 Launchd.plist
echo "   复制 Launchd.plist..."
cp "$PROJECT_DIR/SMCHelper/Launchd.plist" "$LAUNCHD_PLIST_PATH"
chmod 644 "$LAUNCHD_PLIST_PATH"
chown root:wheel "$LAUNCHD_PLIST_PATH"

# 加载 Helper Tool
echo "   加载 Helper Tool..."
launchctl load "$LAUNCHD_PLIST_PATH"

sleep 1

# 验证
echo ""
echo "✅ 安装完成！"
echo ""
echo "📋 验证:"
echo "   Helper Tool: $(ls -lh $HELPER_INSTALL_PATH 2>/dev/null || echo '未安装')"
echo "   运行状态: $(launchctl list | grep -i aurawind || echo '未运行')"
echo ""
echo "🚀 现在可以运行桌面上的 AuraWind.app 了！"
