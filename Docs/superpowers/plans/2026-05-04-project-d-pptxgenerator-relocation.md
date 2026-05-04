# 项目 D：PPTXGenerator 搬迁

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将 PPTXGenerator 从 `Services/AI/` 移入 `Services/Infrastructure/`。

**Architecture:** PPTXGenerator 是纯文件格式生成器（OpenXML），与 AI 无任何关系，属于基础设施层（L0）。

**Tech Stack:** Swift 6, Foundation

---

### Task D1: 移动文件

- [ ] **Step 1: 复制到新位置**

```bash
cp Sources/Shared/Services/AI/PPTXGenerator.swift Sources/Shared/Services/Infrastructure/PPTXGenerator.swift
```

- [ ] **Step 2: 从原目录删除**

```bash
rm Sources/Shared/Services/AI/PPTXGenerator.swift
```

- [ ] **Step 3: 重新生成 Xcode 项目**

```bash
xcodegen generate
```

- [ ] **Step 4: 编译验证**

```bash
xcodebuild build -project KM.xcodeproj -scheme KM -destination 'generic/platform=iOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES 2>&1 | tail -10
```

### Task D2: 更新架构文档

**Files:**
- Modify: `Docs/Architecture/LAYERING_L0_L3.md`
- Modify: `Docs/Architecture/ARCHITECTURE_4PLUS1.md`

在 L0 Infrastructure 的 Infrastructure/ 目录中添加 `PPTXGenerator`。若 AI/ 目录条目中列出则移除。
