#!/bin/bash
# NovelCraft 启动脚本
# 自动构建并打包为 macOS .app，然后启动

set -e

cd "$(dirname "$0")"

# 若 NovelCraft 正在运行，先退出旧实例以确保重新加载最新代码
if pgrep -x "NovelCraft" > /dev/null 2>&1; then
    echo "🛑 正在退出已运行的 NovelCraft..."
    killall NovelCraft
    sleep 1
fi

# 确保使用 Xcode 工具链（SwiftData 宏需要完整 Xcode 的编译器插件）
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

echo "🔨 构建 NovelCraft..."
if ! swift build; then
    echo "❌ 构建失败，请检查编译错误"
    exit 1
fi

APP_PATH="NovelCraft.app"
EXE_PATH="$APP_PATH/Contents/MacOS/NovelCraft"
PLIST_PATH="$APP_PATH/Contents/Info.plist"
RESOURCES_PATH="$APP_PATH/Contents/Resources"

mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$RESOURCES_PATH"

# 自动查找构建产物（支持 debug/release 和多架构）
BUILT_EXE=$(find .build -name NovelCraft -type f -perm +111 | head -1)
if [ -z "$BUILT_EXE" ]; then
    echo "❌ 未找到构建产物 NovelCraft"
    exit 1
fi

cp "$BUILT_EXE" "$EXE_PATH"

# 复制依赖的 Bundle 资源（如隐私清单）
find .build -name "*.bundle" -type d | while read -r bundle; do
    bundle_name=$(basename "$bundle")
    rm -rf "$RESOURCES_PATH/$bundle_name"
    cp -R "$bundle" "$RESOURCES_PATH/"
done

# 每次构建都更新 Info.plist，确保版本号等元数据同步
cat > "$PLIST_PATH" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh-CN</string>
    <key>CFBundleExecutable</key>
    <string>NovelCraft</string>
    <key>CFBundleIdentifier</key>
    <string>com.novelcraft.NovelCraft</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>NovelCraft</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
</dict>
</plist>
EOF

echo "🚀 启动 NovelCraft..."
open "$APP_PATH"
