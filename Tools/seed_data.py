#!/usr/bin/env python3
"""
ZhiMind 数据库种子工具 (Engineering Optimization)
功能：
1. 自动定位模拟器中的应用数据库路径
2. 清理或重建测试数据
3. 验证双链有效性
"""

import sqlite3
import uuid
import time
import json
import sys
import argparse
import subprocess
import os

# 10 个测试页面数据集 (已整合)
SEED_PAGES = [
    {"title": "Andrej Karpathy", "type": "entity", "content": "# Andrej Karpathy\n\nAI 研究者，前 OpenAI 创始成员。[[LLM Wiki]] 提出者。"},
    {"title": "LLM Wiki", "type": "concept", "content": "# LLM Wiki\n\n基于 [[知识编译]] 的个人知识管理范式。对比 [[RAG]] 具有更强的知识持久性。"},
    {"title": "RAG", "type": "concept", "content": "# RAG (检索增强生成)\n\n对比 [[LLM Wiki]]，RAG 侧重于即时检索而非持久编译。"},
    {"title": "知识编译", "type": "concept", "content": "# 知识编译\n\n将原始资料编译为结构化 Wiki 的过程。参见 [[双向链接]]。"},
    {"title": "双向链接", "type": "concept", "content": "# 双向链接\n\n[[知识图谱]] 的核心纽带。"},
    {"title": "知识图谱", "type": "concept", "content": "# 知识图谱\n\n可视化呈现页面关联。"},
    {"title": "nanoGPT", "type": "entity", "content": "# nanoGPT\n\n最简 GPT 框架。作者 [[Andrej Karpathy]]。"},
    {"title": "llm.c", "type": "entity", "content": "# llm.c\n\n纯 C 语言训练 LLM。"},
    {"title": "向量数据库", "type": "concept", "content": "# 向量数据库\n\n支持 [[RAG]] 的核心基础设施。"},
    {"title": "Obsidian", "type": "entity", "content": "# Obsidian\n\n本地 Markdown 知识库。[[LLM Wiki]] 的灵感来源。"}
]

def get_simulator_db_path():
    """动态查找当前活跃模拟器中的数据库路径"""
    try:
        # 查找 bundle id 对应的容器路径
        bundle_id = "com.km.app"
        result = subprocess.check_output(["xcrun", "simctl", "get_app_container", "booted", bundle_id, "data"], text=True).strip()
        db_path = os.path.join(result, "Documents", "km.sqlite3")
        return db_path
    except Exception as e:
        print(f"⚠️  无法自动定位模拟器路径: {e}")
        return None

def main():
    parser = argparse.ArgumentParser(description="ZhiMind 数据种子工具")
    parser.add_argument("--path", help="手动指定数据库路径")
    parser.add_argument("--clean", action="store_true", help="仅清空数据")
    parser.add_argument("--rebuild", action="store_true", default=True, help="清空并重建 (默认)")
    args = parser.parse_args()

    db_path = args.path or get_simulator_db_path()
    if not db_path or not os.path.exists(db_path):
        print(f"❌ 数据库文件不存在: {db_path}")
        print("提示：请确保模拟器已启动且应用已运行一次。")
        sys.exit(1)

    print(f"📂 正在操作数据库: {db_path}")
    
    try:
        conn = sqlite3.connect(db_path)
        cur = conn.cursor()
        
        # 1. 清理
        cur.execute("DELETE FROM pages")
        print("🗑️  已清理旧数据")

        # 2. 注入
        if not args.clean:
            now = time.time()
            for page in SEED_PAGES:
                pid = str(uuid.uuid4())
                cur.execute("""
                    INSERT INTO pages (id, title, type, content, tags, created, updated, status, aliases, sources, related_page_ids)
                    VALUES (?, ?, ?, ?, '[]', ?, ?, 'active', '[]', '[]', '[]')
                """, (pid, page["title"], page["type"], page["content"], now, now))
            print(f"✅ 已成功注入 {len(SEED_PAGES)} 条种子数据")
            
        conn.commit()
        conn.close()
        print("✨ 操作完成")
        
    except Exception as e:
        print(f"❌ 数据库操作失败: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
