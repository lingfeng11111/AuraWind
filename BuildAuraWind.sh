#!/usr/bin/env bash
# 用法：bash BuildAuraWind.sh
set -e

# 0. 基本路径
PROJECT_DIR="/Users/lingfeng/Desktop/Program/APP Projects/AuraWind"
SCHEME="AuraWind"                 # 跟你在 Xcode 里看到的一致
CONFIGURATION="Release"
DERIVED_PATH="${PROJECT_DIR}/build"
APP_NAME="AuraWind.app"
OUT_DIR="${HOME}/Desktop/AuraWind-${CONFIGURATION}"

# 1. 清理旧产物
echo "🧹 清理旧产物…"
rm -rf "${DERIVED_PATH}" "${OUT_DIR}"

# 2. 编译（自动签名，用 Xcode 里选中的 team）
echo "🔨 开始编译…"
xcodebuild -project "${PROJECT_DIR}/AuraWind.xcodeproj" \
           -scheme "${SCHEME}" \
           -configuration "${CONFIGURATION}" \
           -derivedDataPath "${DERIVED_PATH}" \
           clean build

# 3. 找到 .app 并拷到桌面
BUILT_APP=$(find "${DERIVED_PATH}" -name "${APP_NAME}" -type d | head -n 1)
if [[ -z "${BUILT_APP}" ]]; then
  echo "❌ 未找到 ${APP_NAME}"
  exit 1
fi
echo "✅ 找到产物：${BUILT_APP}"

mkdir -p "${OUT_DIR}"
cp -R "${BUILT_APP}" "${OUT_DIR}/"
echo "📦 已拷贝到 ${OUT_DIR}"

# 4. 打开文件夹方便查看
open "${OUT_DIR}"

# 5. （可选）直接生成 dmg，需要就取消注释
# DMG_NAME="AuraWind.dmg"
# hdiutil create -volname "AuraWind Installer" \
#                -srcfolder "${OUT_DIR}" \
#                -ov -format UDZO \
#                "${HOME}/Desktop/${DMG_NAME}"
# echo "💿 DMG 已生成：${HOME}/Desktop/${DMG_NAME}"

echo "🎉 全部完成！"
