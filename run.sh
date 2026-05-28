#!/bin/bash
# NovelCraft 启动脚本
# 自动构建并打包为 macOS .app，然后启动

cd "$(dirname "$0")"

echo "🔨 构建 NovelCraft..."
swift build 2>&1 | tail -5

APP_PATH="NovelCraft.app"
EXE_PATH="$APP_PATH/Contents/MacOS/NovelCraft"
PLIST_PATH="$APP_PATH/Contents/Info.plist"

mkdir -p "$APP_PATH/Contents/MacOS"

# 复制最新的可执行文件
cp .build/arm64-apple-macosx/debug/NovelCraft "$EXE_PATH"

# 确保 Info.plist 存在
if [ ! -f "$PLIST_PATH" ]; then
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
fi

echo "🚀 启动 NovelCraft..."
open "$APP_PATH"
