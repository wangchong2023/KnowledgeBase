#!/bin/bash

# sync_loc.sh
# 
# 作者: Wang Chong / Antigravity
# 功能说明: 自动将 Sources/Localization/ 目录下所有分表的词条合并到 Localizable.xcstrings 主表中。
#          解决分表在部分构建环境下无法被正确识别和加载的问题。
# 版本: 1.0

# 设置工作目录为脚本所在目录的父目录（项目根目录）
cd "$(dirname "$0")/.."

LOC_DIR="Sources/Localization"
TARGET_FILE="$LOC_DIR/Localizable.xcstrings"
PYTHON_CMD="python3"

# 检查 Python 环境
if ! command -v $PYTHON_CMD &> /dev/null; then
    echo "❌ Error: python3 not found. Please ensure python is installed."
    exit 1
fi

if [ ! -f "$TARGET_FILE" ]; then
    echo "❌ Error: $TARGET_FILE not found."
    exit 1
fi

echo "🚀 Starting Internationalization resources sync..."

$PYTHON_CMD -c '
import json
import os
import glob

loc_dir = "Sources/Localization"
target_path = os.path.join(loc_dir, "Localizable.xcstrings")

with open(target_path, "r", encoding="utf-8") as f:
    target_data = json.load(f)

# 获取所有 .xcstrings 文件
all_files = glob.glob(os.path.join(loc_dir, "*.xcstrings"))
merged_count = 0

for file_path in all_files:
    # 跳过主表本身
    if os.path.abspath(file_path) == os.path.abspath(target_path):
        continue
    
    with open(file_path, "r", encoding="utf-8") as f:
        try:
            source_data = json.load(f)
            strings = source_data.get("strings", {})
            for key, value in strings.items():
                if key not in target_data["strings"]:
                    target_data["strings"][key] = value
                    merged_count += 1
        except Exception as e:
            print(f"⚠️ Warning: Failed to parse {file_path}: {e}")

with open(target_path, "w", encoding="utf-8") as f:
    json.dump(target_data, f, ensure_ascii=False, indent=2)

print(f"✅ Sync complete! Merged {merged_count} new keys into Localizable.xcstrings.")
'

echo "✨ Done."
