#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sqlite3
import uuid
import time
import os
import argparse
import json

# 默认数据库路径探测
def get_default_db_path():
    home = os.path.expanduser("~")
    # 1. 模拟器路径 (iOS)
    # 这里路径较深，通常建议通过 --path 手动指定
    # 2. macOS 标准路径
    mac_doc_path = os.path.join(home, "Documents/km.sqlite3")
    if os.path.exists(mac_doc_path):
        return mac_doc_path
    # 3. Sandbox 路径
    sandbox_path = os.path.join(home, "Library/Containers/com.constantine.km/Data/Documents/km.sqlite3")
    if os.path.exists(sandbox_path):
        return sandbox_path
    return "km.sqlite3" # 默认当前目录

def seed_data(db_path, clean_only=False):
    if not os.path.exists(db_path):
        if not clean_only:
            print(f"⚠️ 数据库文件不存在，将尝试创建: {db_path}")
        else:
            print(f"❌ 数据库不存在，无法执行清空操作: {db_path}")
            return

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # 启用外键支持
    cursor.execute("PRAGMA foreign_keys = ON")

    # 默认都会清理，除非另有说明
    print("🧹 正在清理数据库 (pages, embeddings, chunks, links, fts)...")
    try:
        cursor.execute("DELETE FROM pages")
        cursor.execute("DELETE FROM page_embeddings")
        cursor.execute("DELETE FROM page_chunks")
        cursor.execute("DELETE FROM links")
        cursor.execute("DELETE FROM pages_fts")
    except sqlite3.OperationalError as e:
        print(f"⚠️ 清理部分表时出错 (可能尚未创建): {e}")

    if clean_only:
        conn.commit()
        conn.close()
        print("✅ 数据库已清空。")
        return

    print(f"🌱 正在向 {db_path} 注入 AI Agent 专题测试数据...")
    now = time.time()
    
    test_pages = [
        {
            "title": "AI Agent：超越对话的大脑",
            "type": "concept",
            "content": "# 什么是 AI Agent？\n\nAI Agent (人工智能代理) 是指能够感知环境、进行推理并采取行动以实现目标的智能体。不同于传统的 [[大语言模型 (LLM)]] 仅能进行对话，Agent 具备了“行动力”。\n\n## 核心公式\n**Agent = LLM + [[规划 (Planning)]] + [[记忆 (Memory)]] + [[工具使用 (Tool Use)]]**\n\n相关框架：AutoGPT, BabyAGI, LangChain",
            "tags": ["AI", "Agent", "架构"],
            "aliases": ["AI代理", "智能体"]
        },
        {
            "title": "规划 (Planning)",
            "type": "concept",
            "content": "# 规划 (Planning)\n\n规划是 Agent 解决复杂任务的基础。它通常分为以下几个子任务：\n\n1. **任务分解**: 将大目标拆解为可管理的小步骤 (如 Chain of Thought)。\n2. **自我反思**: 代理会对过去的行动进行修正和完善 (如 ReAct 模式)。\n\n这使得 [[AI Agent：超越对话的大脑]] 能够处理需要多步推理的问题。",
            "tags": ["AI", "Planning", "推理"],
            "aliases": ["任务分解"]
        },
        {
            "title": "记忆 (Memory)",
            "type": "concept",
            "content": "# 记忆 (Memory)\n\n记忆能力让 Agent 能够保持上下文连贯性：\n\n- **短期记忆**: 利用 [[大语言模型 (LLM)]] 的上下文窗口记录当前任务。\n- **长期记忆**: 利用外部存储 (如 [[向量数据库]]) 进行信息检索。\n\n[[AI Agent：超越对话的大脑]] 利用长期记忆来实现跨会话的知识沉淀。",
            "tags": ["AI", "Memory", "RAG"],
            "aliases": ["长期记忆"]
        },
        {
            "title": "工具使用 (Tool Use)",
            "type": "concept",
            "content": "# 工具使用 (Tool Use / Tool Calling)\n\n工具使用是 Agent 与现实世界交互的桥梁。Agent 可以通过 API 调用：\n\n- **实时搜索**: 获取最新资讯。\n- **代码执行**: 进行复杂的数学运算。\n- **文件操作**: 处理本地文档。\n\n这让 [[AI Agent：超越对话的大脑]] 真正具备了解决实际问题的能力。",
            "tags": ["AI", "ToolUse", "API"],
            "aliases": ["工具调用"]
        },
        {
            "title": "大语言模型 (LLM)",
            "type": "concept",
            "content": "# LLM 作为中枢神经\n\n在 [[AI Agent：超越对话的大脑]] 架构中，LLM 扮演了“大脑”的角色，负责理解、决策和任务分发。\n\n为了训练出更强的 Agent，通常需要使用 [[大语言模型训练流程]]，特别是针对函数调用 (Function Calling) 的专门微调。",
            "tags": ["AI", "LLM", "大脑"],
            "aliases": ["核心引擎"]
        }
    ]

    for p in test_pages:
        page_id = str(uuid.uuid4()).upper()
        cursor.execute("""
            INSERT INTO pages (
                id, title, type, content, tags, aliases, 
                status, confidence, created, updated, is_pinned
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            page_id, p["title"], p["type"], p["content"], 
            json.dumps(p["tags"]), json.dumps(p.get("aliases", [])),
            "active", "high", now, now, 0
        ))
        
        # 建立链接记录
        if "AI Agent" in p["title"]: continue
        cursor.execute("INSERT OR REPLACE INTO links (source_id, target_title) VALUES (?, ?)", (page_id, "AI Agent：超越对话的大脑"))

    conn.commit()
    conn.close()
    print(f"✅ 重建完成！共注入 {len(test_pages)} 条深度 AI 专题数据。")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="智元数据重建工具")
    parser.add_argument("--path", type=str, default=get_default_db_path(), help="数据库路径")
    parser.add_argument("--clean", action="store_true", help="是否仅执行清空操作")
    
    args = parser.parse_args()
    seed_data(args.path, clean_only=args.clean)
