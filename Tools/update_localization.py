#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
update_localization.py

作者: Wang Chong / Antigravity
功能说明: 自动将 Sources/Localization/ 目录下所有分表的词条合并到 Localizable.xcstrings 主表中。
         解决分表在部分构建环境下无法被正确识别和加载的问题。
版本: 1.1
日期: 2026-05-05
"""

import json
import os
import glob
import sys

def sync_localization():
    # 获取项目根目录 (假设脚本在 Tools/ 目录下)
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    loc_dir = os.path.join(base_dir, "Sources", "Localization")
    target_path = os.path.join(loc_dir, "Localizable.xcstrings")

    if not os.path.exists(target_path):
        print(f"❌ Error: {target_path} not found.")
        sys.exit(1)

    print("🚀 Starting Internationalization resources sync...")

    try:
        with open(target_path, "r", encoding="utf-8") as f:
            target_data = json.load(f)
    except Exception as e:
        print(f"❌ Error: Failed to read target file {target_path}: {e}")
        sys.exit(1)

    # 获取所有 .xcstrings 文件
    all_files = glob.glob(os.path.join(loc_dir, "*.xcstrings"))
    merged_count = 0

    for file_path in all_files:
        # 跳过主表本身
        if os.path.abspath(file_path) == os.path.abspath(target_path):
            continue
        
        print(f"📦 Processing {os.path.basename(file_path)}...")
        with open(file_path, "r", encoding="utf-8") as f:
            try:
                source_data = json.load(f)
                strings = source_data.get("strings", {})
                for key, value in strings.items():
                    if key not in target_data["strings"] or target_data["strings"][key] != value:
                        target_data["strings"][key] = value
                        merged_count += 1
            except Exception as e:
                print(f"⚠️ Warning: Failed to parse {file_path}: {e}")

    try:
        with open(target_path, "w", encoding="utf-8") as f:
            json.dump(target_data, f, ensure_ascii=False, indent=2)
        print(f"✅ Sync complete! Merged {merged_count} new or updated keys into Localizable.xcstrings.")
    except Exception as e:
        print(f"❌ Error: Failed to write to {target_path}: {e}")
        sys.exit(1)

    print("✨ Done.")

if __name__ == "__main__":
    sync_localization()
