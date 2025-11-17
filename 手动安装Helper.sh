#!/bin/bash

# 手动安装 Helper Tool（开发测试用）
# 这个脚本会将 Helper Tool 安装到系统目录

set -e

echo "🔧 手动安装 AuraWind Helper Tool"
echo "================================"
echo ""

# 检查是否有 sudo 权限
if [ "$EUID" -ne 0 ]; then 
    echo "❌ 需要 sudo 权限"
    echo "请运行: sudo ./手动安装Helper.sh"
    exit 1
fi

# 路径配置
BUILD_DIR="/Users/lingfeng/Desktop/Program/APP Projects/AuraWind/Build/DerivedData/Build/Products/Release"
HELPER_TOOL="$BUILD_DIR/com.aurawind.AuraWind.SMCHelper"
LAUNCHD_PLIST="/Users/lingfeng/Desktop/Program/APP Projects/AuraWind/SMCHelper/Launchd.plist"

# 目标路径
INSTALL_DIR="/Library/PrivilegedHelperTools"
LAUNCHD_DIR="/Library/LaunchDaemons"
HELPER_NAME="com.aurawind.AuraWind.SMCHelper"

# 检查文件是否存在
if [ ! -f "$HELPER_TOOL" ]; then
    echo "❌ Helper Tool 不存在: $HELPER_TOOL"
    echo "请先编译项目"
    exit 1
fi

if [ ! -f "$LAUNCHD_PLIST" ]; then
    echo "❌ Launchd.plist 不存在: $LAUNCHD_PLIST"
    exit 1
fi

echo "1️⃣ 停止现有的 Helper Tool（如果存在）..."
launchctl unload "$LAUNCHD_DIR/$HELPER_NAME.plist" 2>/dev/null || true

echo "2️⃣ 复制 Helper Tool 到系统目录..."
cp "$HELPER_TOOL" "$INSTALL_DIR/$HELPER_NAME"
chmod 755 "$INSTALL_DIR/$HELPER_NAME"
chown root:wheel "$INSTALL_DIR/$HELPER_NAME"

echo "3️⃣ 复制 Launchd.plist..."
cp "$LAUNCHD_PLIST" "$LAUNCHD_DIR/$HELPER_NAME.plist"
chmod 644 "$LAUNCHD_DIR/$HELPER_NAME.plist"
chown root:wheel "$LAUNCHD_DIR/$HELPER_NAME.plist"

echo "4️⃣ 加载 Helper Tool..."
launchctl load "$LAUNCHD_DIR/$HELPER_NAME.plist"

echo ""
echo "✅ Helper Tool 安装完成！"
echo ""
echo "📋 验证安装:"
echo "   Helper Tool: $(ls -lh $INSTALL_DIR/$HELPER_NAME)"
echo "   Launchd.plist: $(ls -lh $LAUNCHD_DIR/$HELPER_NAME.plist)"
echo ""
echo "🔍 检查运行状态:"
launchctl list | grep -i aurawind || echo "   ⚠️  Helper Tool 未运行"
echo ""
echo "🚀 现在可以运行 AuraWind.app 了"
