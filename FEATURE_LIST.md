# WikiCraft 功能清单 & 测试指南

> 文档版本：2026-04-29 | 覆盖全部 28 个视图、11 个组件、14 个服务

---

## 一、App 整体结构

### 1.1 底部导航栏（5 个 Tab）

| Tab | 图标 | 入口视图 | 描述 |
|-----|------|----------|------|
| Wiki | `book.fill` | `WikiNavigationView` | 知识库主界面（侧边栏 + 内容区） |
| Graph | `network` | `GraphContainerView` | 2D 知识图谱 |
| Search | `magnifyingglass` | `SearchView` | 全局搜索 |
| Ingest | `arrow.down.doc.fill` | `IngestView` | 知识导入 |
| Settings | `gearshape.fill` | `SettingsView` | 设置与个性化 |

### 1.2 数据模型概览

**WikiPage 核心字段：**
- `id` (UUID)、`title` (String)、`type` (PageType)、`customIcon` (String?)
- `content` (String，支持 `[[双向链接]]` 语法)
- `aliases` ([String])、`tags` ([String])
- `status` (PageStatus: active/stub/needsUpdate/deprecated)
- `confidence` (Confidence: high/medium/low)
- `isPinned` (Bool)、`created`/`updated` (Date)

**PageType（6 种页面类型）：**
`entity` / `concept` / `source` / `comparison` / `map` / `raw`

---

## 二、知识库页面管理（Wiki Tab）

### 2.1 侧边栏（SidebarView）

| 功能 | 描述 | 测试要点 |
|------|------|---------|
| 页面列表 | 按 PageType 分组展示，支持折叠 | 切换展开/折叠状态；滚动大量页面 |
| 总索引按钮 | 跳转 IndexView（按字母排序） | 索引列表按类型分组、字母排序 |
| 操作日志按钮 | 跳转 LogView | 日志按时间顺序，可展开查看详情 |
| 常用知识菜单 | Top 5 页面（按链接密度+词数排序） | 确认排序正确 |
| 固定页面区 | 手动固定的页面（pin） | 固定/取消固定切换 |
| 健康检查按钮 | 跳转 LintView，显示问题数量徽章 | Badge 数字与实际 lint 问题数一致 |

### 2.2 页面详情（PageDetailView）

| 功能 | 描述 | 测试要点 |
|------|------|---------|
| 页面头信息 | Breadcrumb、类型/状态/可信度徽章 | 徽章颜色正确；tap 均无操作 |
| 页面标题 | 大字展示，含无障碍标签 | VoiceOver 朗读标题 |
| 别名展示 | 水平滚动胶囊 | 多个别名时正常滚动 |
| 标签展示 | 水平滚动胶囊 | 多个标签时正常滚动 |
| 元信息行 | 创建时间、更新时间、字数、出链数 | 日期格式正确 |
| 固定按钮 | 导航栏右侧 pin 图标 | 固定状态切换；图标颜色变化 |
| 反向链接按钮 | 显示反向链接数量 | 弹出 BacklinksView sheet |
| 编辑按钮 | 切换编辑/完成状态 | 编辑状态工具栏变化 |
| 页面类型选择 | Menu → 6 种类型 | 选择后立即保存并更新徽章 |
| 页面图标自定义 | Menu → IconPickerView | 自定义后显示自定义图标 |
| 页面状态选择 | Menu → 4 种状态 | 颜色徽章正确更新 |
| 可信度选择 | Menu → 3 级 | 颜色徽章正确更新 |
| 删除页面 | 确认对话框 | 确认后页面消失；日志记录删除 |
| Markdown 渲染 | MarkdownRendererView 渲染内容 | `[[链接]]` 可点击跳转 |
| 反向链接列表 | NavigationLink 跳转到对应页面 | 链接可正常导航 |
| WikiLink 点击 | 渲染内容中 `[[标题]]` | 跳转到目标页面；不存在时无反应 |

### 2.3 创建页面（CreatePageView）

| 功能 | 描述 | 测试要点 |
|------|------|---------|
| 标题输入 | TextField，必填 | 空标题时"创建"按钮禁用 |
| 类型选择 | 6 个 pill 按钮 | 选中状态高亮 |
| 标签输入 | 逗号分隔多标签 | 多个标签正确解析 |
| 内容编辑器 | monospaced TextEditor | `[[双向链接]]` 语法提示 |
| 实体模板 | 预填充实体类型内容 | 点击后内容被替换 |
| 概念模板 | 预填充概念类型内容 | 点击后内容被替换 |
| 对比模板 | 预填充对比类型内容 | 点击后内容被替换 |
| 创建按钮 | 调用 store.createPage | 创建后自动跳转到新页面 |
| 取消按钮 | 关闭 sheet | 不创建任何页面 |

### 2.4 Markdown 编辑器（MarkdownEditorView）

| 功能 | 描述 | 测试要点 |
|------|------|---------|
| H1/H2/H3 按钮 | 在光标位置插入 `# ` / `## ` / `### ` | 光标位置正确；无选区时插入到当前光标 |
| 粗体按钮 | 包裹选区或插入 `**粗体**` | 选区被包裹；无选区时插入占位符 |
| 斜体按钮 | 包裹选区或插入 `*斜体*` | 同上 |
| 代码按钮 | 包裹选区或插入 `` `代码` `` | 同上 |
| 链接按钮 | 插入 `[[]]` | 光标停在中间位置 |
| 列表按钮 | 插入 `- ` | 光标位置正确 |
| 引用按钮 | 插入 `> ` | 光标位置正确 |
| 表格按钮 | 插入多行表格模板 | 插入完整表格 |
| 分割线按钮 | 插入 `\n---\n` | 正确换行 |
| Wiki链接按钮 | 弹出 WikilinkPickerSheet | Sheet 正常；选择后插入链接 |
| 标签添加 | InlineTagInput 用户输入 | 空白/重复标签被过滤 |
| 别名添加 | InlineAliasInput 用户输入 | 同上 |
| 离开编辑 | 自动保存 page.content | store.updatePage 被调用 |

### 2.5 Wiki 欢迎页（WikiWelcomeView）

| 功能 | 描述 | 测试要点 |
|------|------|---------|
| 统计卡片 | 页面总数、实体数、概念数、知识源数 | 数字与实际数据一致 |
| 快速入门（空 wiki） | 4 步引导创建第一个页面 | 空数据时显示；有数据时隐藏 |
| 使用提示（非空） | 提示使用 `[[双向链接]]` | 有数据时显示快速操作 |
| 最近页面列表 | 最近 5 个更新的页面 | NavigationLink 正常跳转 |
| 固定页面区 | 已固定页面列表 | 无固定页面时不显示 |

---

## 三、全文搜索（Search Tab）

| 功能 | 描述 | 测试要点 |
|------|------|---------|
| 搜索框 | 支持标题/内容/标签/别名搜索 | 搜索结果实时过滤；清空恢复全部 |
| 类型筛选 Pill | 全部 + 6 个 PageType | 选中状态高亮；可组合其他条件 |
| 排序菜单 | 最近更新/最近创建/标题/类型 | 排序结果正确 |
| 结果列表 | NavigationLink 到 PageDetailView | 导航正常 |
| 结果计数 | 底部显示匹配数量 | 数量与实际结果一致 |
| 空状态-无输入 | 提示"输入关键词搜索" | 无搜索时显示此状态 |
| 空状态-无结果 | 提示"没有找到匹配的页面" | 搜索无结果时显示 |

---

## 四、知识图谱

### 4.1 2D 图谱（GraphView）

| 功能 | 描述 | 测试要点 |
|------|------|---------|
| 节点渲染 | Canvas 绘制；节点大小按链接数 | 无页面时显示空状态 |
| 节点颜色 | 按 PageType 着色 | 6 种类型颜色正确 |
| 固定节点动画 | 固定节点有脉冲动画 | 动画流畅 |
| 缩放 | MagnificationGesture pinch | 缩放范围合理 |
| 平移 | DragGesture pan | 拖动流畅 |
| 图例开关 | 显示/隐藏类型颜色图例 | Toggle 切换 |
| 类型筛选 Pill | 只显示特定类型节点 | 筛选后节点/边更新 |
| 节点点击 | 显示 GraphSelectedNodeCard | Card 显示页面信息 |
| Card 导航 | NavigationLink 跳转到 PageDetail | 导航正常 |
| 缩放控制按钮 | 放大/缩小/重置/重新布局 | 各个按钮功能正确 |
| 空状态 | "页面间的关联将在此可视化" | 无链接页面时显示 |

### 4.2 3D 图谱（Graph3DView）

| 功能 | 描述 | 测试要点 |
|------|------|---------|
| 3D 节点分布 | Fibonacci 球面分布 | 节点位置合理分布 |
| 节点大小 | 按链接数计算 | 链接越多节点越大 |
| 固定节点脉冲 | SCNAction 动画 | 动画循环播放 |
| 相机旋转 | autoRotate toggle | 开/关状态正确切换 |
| 重置相机 | 相机回到初始位置 | 动画过渡平滑（0.5s） |
| 类型筛选 Menu | 只显示特定类型节点 | 过滤后场景重建 |
| 节点点击选择 | hitTest 检测点击 | 点击节点显示 InfoBar |
| InfoBar | 显示节点类型、标题、"查看页面"按钮 | 按钮跳转到 PageDetailView |

---

## 五、AI 对话（Chat Tab）

| 功能 | 描述 | 测试要点 |
|------|------|---------|
| 未配置 Banner | LLM 未配置时显示警告 | 点击跳转到 LLM 设置 |
| 欢迎语-空 wiki | 4 个引导问题 | 点击发送对应消息 |
| 欢迎语-有数据 | 4 个与知识库相关的建议 | 点击发送对应消息 |
| 消息列表 | LazyVStack + ScrollViewReader | 自动滚动到底部 |
| 用户气泡 | 右对齐蓝色气泡 | 文本正常显示 |
| AI 气泡 | 左对齐气泡 + Streaming 效果 | Streaming 逐字显示 |
| Streaming 指示器 | 3 个 PulsingDot | 等待 AI 响应时显示 |
| 发送按钮 | 有输入时启用 | 空输入时禁用 |
| 停止按钮 | AI 响应中显示 | 点击取消请求 |
| 菜单-清空历史 | 弹出确认 | 确认后消息列表清空 |
| 菜单-LLM 设置 | NavigationLink 跳转 | 导航正常 |
| 错误 Alert | 连接失败时弹出 | Alert 显示错误信息 |

---

## 六、LLM 设置

### 6.1 云端 LLM（LLMSettingsView）

| 功能 | 描述 | 测试要点 |
|------|------|---------|
| 启用/禁用 Toggle | 开启后显示配置选项 | Toggle 切换状态 |
| Provider 选择 | OpenAI / DeepSeek / Custom | Radio 风格选中 |
| API Key 输入 | SecureField + show/hide toggle | 密钥正确显示/隐藏 |
| Base URL | 自定义端点输入 | DeepSeek 显示预设 URL |
| Model 输入 | 手动输入 + 建议 pills | 点击 pill 自动填充 |
| 测试连接按钮 | 调用 llmService.validateAPIKey() | 成功显示绿色提示；失败显示错误 |
| 对话历史 | 显示消息数量 | 数字正确 |
| 清空历史按钮 | 确认后清空 | 列表清空；计数归零 |

### 6.2 端侧 LLM（OnDeviceLLMSettingsView）

| 功能 | 描述 | 测试要点 |
|------|------|---------|
| 可用性指示器 | iOS 17+ 显示 CoreML；18.2+ 显示 Apple Intelligence | 颜色正确（绿/红） |
| 模型列表 | 显示可用模型（大小/类型） | 选择后高亮 |
| 加载模型按钮 | 调用 loadModel() | 失败弹出 Alert（已修复静默错误） |
| 卸载模型按钮 | 调用 unloadModel() | 卸载后状态更新 |
| 导入模型 | fileImporter 支持 .mlmodel/.mlmodelc | 选择后调用 importModel() |
| 测试生成按钮 | 弹出 OnDeviceTestView | 需先加载模型才启用 |
| 推理速度显示 | 显示 tok/s | 仅在有数据时显示 |

---

## 七、知识导入（Ingest Tab）

### 7.1 手动导入（IngestView）

| 功能 | 描述 | 测试要点 |
|------|------|---------|
| OCR 扫描入口 | PhotosPicker + 拍照 OCR | 跳转到 OCRScanView |
| 手动录入入口 | 显示 ManualFormSection | - |
| 标题输入 | TextField | 必填 |
| 内容 TextEditor | monospaced，支持 `[[]]` 语法 | 多行输入正常 |
| 标签输入 | 逗号分隔 | 多个标签正确解析 |
| 普通导入 | 0.5s 延迟后创建页面（假延迟，体验优化） | 页面创建成功 |
| 智能导入 Toggle | 开启后显示预览确认 | Toggle 状态切换 |
| 智能导入 | LLM.compile() + 预览 + 确认 | 预览内容正确；确认后创建页面 |

### 7.2 OCR 扫描（OCRScanView）

| 功能 | 描述 | 测试要点 |
|------|------|---------|
| 相册选择 | PhotosPicker 选图 | 图片正确显示 |
| 识别文字按钮 | 调用 OCRService.recognizeText() | 处理中显示 spinner + "识别中..." |
| OCR 失败 | 弹出 Alert（之前是写入文本区，已修复） | 错误信息清晰 |
| 识别结果 | Text 可选择复制 | 复制到剪贴板成功 |
| 字符计数 | 显示识别文本字数 | 数字正确 |
| 标题自动填充 | 取识别文本前 20 字 | 自动填入标题字段 |
| 标签添加 | 用户输入标签名（已修复"标签N"问题） | 空白/重复标签被过滤 |
| 保存到知识库 | 创建 WikiPage | 页面创建成功并跳转 |

### 7.3 PDF 阅读与标注（PDFReaderView）

| 功能 | 描述 | 测试要点 |
|------|------|---------|
| PDF 库空状态 | ContentUnavailableView | 无 PDF 时显示 |
| 添加 PDF | fileImporter 支持 PDF | 选择后添加到库 |
| PDF 列表 | PDFDocumentRow 显示元数据 | 高亮数量正确 |
| PDF 阅读 | 全屏 PDFView | 翻页正常；双指缩放 |
| 高亮标注 | 选择文本后选择颜色 | 高亮颜色正确保存 |
| 高亮笔记 | 高亮后弹出笔记输入 | 保存后笔记关联到高亮 |
| 删除 PDF | Swipe action | 确认后删除 |
| 导入到知识库 | PDFIngestSheet | 提取模式（全文/范围/仅高亮） |
| 预览内容 | 提取内容预览 | 内容正确显示 |

### 7.4 语音笔记（VoiceNoteView）

| 功能 | 描述 | 测试要点 |
|------|------|---------|
| 权限请求 | mic 未授权时显示 | 点击请求权限 |
| 语言选择 | Picker 选择识别语言 | 支持 zh-CN/en-US 等 |
| 开始录音 | 调用 SpeechService.startRecording() | 按钮变为红色方块 |
| 停止录音 | 调用 SpeechService.stopRecording() | 波形停止更新 |
| 音频波形 | 真实 AVAudioRecorder 数据（已修复随机值问题） | 波形随音量实时变化 |
| 实时转写 | Speech framework streaming | 转写文本实时更新 |
| 转写结果复制 | UIPasteboard | 复制成功 |
| 转写结果清空 | SpeechService.clearTranscription() | 文本清空 |
| 保存到知识库 | SaveVoiceNoteSheet | 填写标题后创建页面 |
| 历史录音列表 | 最近 5 条 | VoiceRecordingRow 显示 |

---

## 八、知识健康

### 8.1 健康检查（LintView）

| 功能 | 描述 | 测试要点 |
|------|------|---------|
| 运行检查按钮 | 调用 LintService.runFullLint() | 显示 loading spinner |
| 问题计数 | 按 severity 分组显示 | 数字正确 |
| 空状态（无问题） | 绿色对勾 + "一切正常" | 无问题时显示 |
| 问题列表 | 按 severity 排序 | Error → Warning → Info |
| 问题可展开 | 点击展开 suggestion | 展开动画正常 |
| 跳转到页面 | "转到页面" 按钮 | NavigationLink 跳转正确 |

### 8.2 操作日志（LogView）

| 功能 | 描述 | 测试要点 |
|------|------|---------|
| 日志列表 | 按时间倒序 | 最新在上 |
| 日志可展开 | tap 展开查看详情 | 动画展开/折叠 |
| 颜色编码 | create=绿/update=蓝/delete=红/lint=橙 等 | 颜色正确 |
| 空状态 | 无日志时显示提示 | 空数据时显示 |
| 关闭按钮 | 关闭 sheet | sheet 正确 dismiss |

### 8.3 总索引（IndexView）

| 功能 | 描述 | 测试要点 |
|------|------|---------|
| 统计概览 | 页面总数/实体/概念/知识源 | 数字正确 |
| 按类型分组 | Entity / Concept / Source / Comparison | 字母排序 |
| 页面行 | 类型图标 + 标题 + 字数 + 标签 | NavigationLink 正常 |

### 8.4 标签云（TagCloudView）

| 功能 | 描述 | 测试要点 |
|------|------|---------|
| 标签云 FlowLayout | 自定义 Layout 协议 | 标签自动换行 |
| 标签点击 | 显示使用该标签的页面列表 | 列表正确过滤 |
| 重命名标签 | Alert 输入新名称 | 所有使用该标签的页面同步更新 |
| 删除标签 | 确认后删除 | 从所有页面移除该标签 |
| 标签计数 Badge | 显示使用数量 | 数量正确 |

---

## 九、协作（Collaboration Tab）

| 功能 | 描述 | 测试要点 |
|------|------|---------|
| 模拟器警告 | Simulator 不支持 MultipeerConnectivity | 警告正确显示 |
| 用户名输入 | TextField（持久化到 UserDefaults） | 持久化正确 |
| 主持人按钮 | 显示 HostingSetupSheet | Sheet 正常弹出 |
| 加入房间按钮 | 搜索房间列表 | DiscoveredRoomRow 显示 |
| 加入房间 | 调用 collabService.join() | 连接成功显示角色徽章 |
| 房间信息卡 | 显示房间名/拥有者/在线人数 | 信息正确 |
| 离开按钮 | 调用 collabService.stop() | 退出后状态重置 |
| 已连接用户列表 | ConnectedPeerRow 显示 | 角色徽章颜色正确 |
| 最近编辑列表 | RecentEditRow 显示最后 10 条 | 时间戳正确 |
| 角色徽章 | Owner=蓝/Editor=绿/Viewer=灰 | 颜色正确 |

---

## 十、同步与备份

### 10.1 iCloud 同步（iCloudSyncView）

| 功能 | 描述 | 测试要点 |
|------|------|---------|
| 状态显示 | idle/syncing/synced/error | 图标和颜色正确 |
| 上次同步时间 | 显示时间戳 | 格式正确 |
| 上传到 iCloud | pushToCloud() | 进度 spinner；成功/失败 alert |
| 从 iCloud 下载 | pullFromCloud()（**已加确认对话框**） | 下载前弹出警告；覆盖本地数据 |
| 双向同步 | sync() | 冲突时弹出 ConflictAlert |
| 自动同步 Toggle | 5 分钟间隔自动执行 | Toggle 开启后计时器启动 |
| 冲突解决策略 | Merge / KeepLocal / KeepRemote | 选择后持久化到 UserDefaults |
| 清除 iCloud 数据 | 推送空数据 | 远端数据清空 |

### 10.2 本地备份（BackupView）

| 功能 | 描述 | 测试要点 |
|------|------|---------|
| 自动备份 Toggle | 每次写入磁盘时自动备份 | 开关功能正常 |
| 手动创建备份 | BackupService.createBackup() | 创建成功反馈 haptic |
| 导出当前备份 | ShareLink 导出 | 系统分享 sheet 正常弹出 |
| 备份历史列表 | 显示日期/大小 | Restore SwipeAction |
| 恢复备份 | 确认后执行 | 数据正确恢复；Success haptic |
| 删除备份 | SwipeAction | 删除后列表更新 |

---

## 十一、设置（Settings Tab）

| 功能 | 描述 | 测试要点 |
|------|------|---------|
| 外观-深色模式 | System/Light/Dark | 立即应用；持久化 |
| 外观-强调色 | 8 种颜色可选 | 立即应用到 tintColor |
| AI-Chat 导航 | NavigationLink 到 ChatView | 导航正常 |
| AI-LLM 设置导航 | NavigationLink 到 LLMSettingsView | 导航正常 |
| AI-端侧 LLM 导航 | NavigationLink 到 OnDeviceLLMSettingsView | 导航正常 |
| 数据-iCloud 同步导航 | NavigationLink 到 iCloudSyncView | 导航正常 |
| 数据-备份导航 | NavigationLink 到 BackupView | 导航正常 |
| 数据-导出 Markdown | ShareLink 导出 ZIP | 包含所有页面的 .md 文件 |
| 数据-从剪贴板导入 | importFromClipboard() | JSON 格式正确解析；重复标题跳过 |
| 功能-语音笔记导航 | NavigationLink 到 VoiceNoteView | 导航正常 |
| 功能-PDF 库导航 | NavigationLink 到 PDFReaderView | 导航正常 |
| 功能-协作导航 | NavigationLink 到 CollaborationView | 导航正常 |
| 功能-3D 图谱导航 | NavigationLink 到 Graph3DView | 导航正常（visionOS + iOS） |
| 功能-Vision Pro 导航 | NavigationLink 到 VisionProSpatialView | iOS 显示模拟预览 |
| 统计信息 | 页面总数/总字数/stub 数/日志数 | 数字正确 |
| 维护-标签管理导航 | NavigationLink 到 TagCloudView | 导航正常 |
| 维护-健康检查导航 | NavigationLink 到 LintView | 导航正常 |
| 维护-总索引导航 | NavigationLink 到 IndexView | 导航正常 |
| 维护-性能面板导航 | NavigationLink 到 PerformanceView | 导航正常 |
| 重置知识库 | 二次确认 + "重置所有数据" | **Danger Zone** 红色按钮；执行不可逆 |

---

## 十二、已知问题 & 测试边界

### 12.1 需要手动测试确认已修复

| 编号 | 问题 | 修复状态 |
|------|------|---------|
| B-01 | MarkdownEditor insertAtCursor() 追加而非定位光标 | ✅ 已修复（UITextViewRepresentable + CursorState） |
| B-02 | iCloudSync pullFromCloud 无确认覆盖本地 | ✅ 已修复（新增 showPullConfirmation Alert） |
| B-03 | OnDeviceLLM loadModel/importModel 静默失败 | ✅ 已修复（新增 showError Alert） |
| B-04 | OCR 失败写入文本区而非 alert | ✅ 已修复（showOCRError Alert） |
| B-05 | OCR addTag() 生成无意义"标签N" | ✅ 已修复（showAddTagInput Alert 输入） |
| B-06 | Graph3DView resetCamera 空函数 | ✅ 已修复（SCNTransaction 动画重置） |
| B-07 | VoiceNote 波形使用随机值 | ✅ 已修复（SpeechService.audioLevelHistory 真实数据） |

### 12.2 持续存在的问题（需要更长修复周期）

| 编号 | 问题 | 影响范围 |
|------|------|---------|
| K-01 | 全部 28 个视图无 accessibility 标签 | VoiceOver 用户体验 |
| K-02 | 大量硬编码中文字符串未使用 L.tr() | 国际化不可行 |
| K-03 | SidebarView.frequentPages 每次渲染重新计算 | 性能隐患（O(n log n) 每帧） |
| K-04 | PDFKit onTextSelected 未连接代理 | PDF 高亮选中文本功能失效 |

### 12.3 网络相关边界条件

| 场景 | 预期行为 |
|------|---------|
| LLM API Key 无效 | 测试连接失败 → 显示错误信息 |
| LLM 网络超时 | Streaming 中断 → 显示错误 Alert |
| iCloud 不可用（未登录/无网络） | 状态显示 error；按钮禁用 |
| iCloud 同步冲突 | 弹出 ConflictAlert 让用户选择策略 |
| 离线状态下智能导入 | LLM 服务不可用 → 提示网络错误 |

### 12.4 数据边界条件

| 场景 | 预期行为 |
|------|---------|
| 创建页面标题为空 | "创建"按钮禁用 |
| 标签输入空白/重复 | 静默过滤，不添加 |
| 删除最后一页 | Sidebar 显示空状态 |
| 恢复备份后数据不一致 | 以备份数据为准（merge 策略） |
| Wikilink 指向不存在的页面 | 渲染为普通文本（不 crash） |
| 大量页面（>1000）的图谱渲染 | Canvas 性能可能下降 |

---

## 十三、组件清单（Components）

| 组件文件 | 组件 | 用途 |
|---------|------|------|
| `WikiCard.swift` | WikiCard, WikiSectionHeader, WikiLabeledRow, WikiStepRow, WikiChip, WikiIconChip, WikiPrimaryButton, WikiCapsuleButton, WikiSuccessBanner, WikiTextField, WikiTagField, WikiMonospacedEditor, AnimatedSection, WikiScrollableChips | 基础 UI 组件库 |
| `ChatComponents.swift` | ChatBubbleView, ChatContentView, ChatLinkParser, PulsingDot | 对话气泡组件 |
| `EditorComponents.swift` | WikilinkPickerSheet, EditorToolbarButton, TagChip, AliasChip, InlineTagInput | Markdown 编辑器组件 |
| `GraphComponents.swift` | GraphNodeView, GraphNodeLabel, GraphZoomControls, GraphLegend, GraphSelectedNodeCard | 图谱可视化组件 |
| `IngestViewComponents.swift` | IngestHeroSection, IngestEntryCardsSection, IngestManualFormSection, SmartIngestPreview, IngestTipsSection | 导入视图组件 |
| `OnDeviceComponents.swift` | OnDeviceTestView, OnDeviceModelRow | 端侧 LLM 组件 |
| `PDFComponents.swift` | PDFIngestSheet, PDFDocumentRow, Color.pdfHighlight | PDF 组件 |
| `CollaborationComponents.swift` | CollabInfoRow, DiscoveredRoomRow, ConnectedPeerRow, RecentEditRow, CollabRoleBadge | 协作组件 |
| `SettingsComponents.swift` | AccentColorPicker, SettingsNavigationRow, SettingsStatRow, InfoRow | 设置页组件 |
| `VoiceNoteComponents.swift` | SaveVoiceNoteSheet, VoiceRecordingRow | 语音笔记组件 |
| `HostingSetupSheet.swift` | HostingSetupSheet | 协作主机设置 |
| `MarkdownTextView.swift` | MarkdownTextViewRepresentable, CursorState, EditorActionExecutor, MarkdownEditorToolbar | 光标感知编辑器 |
| `WikiEmptyState.swift` | WikiEmptyState | 通用空状态组件 |
| `WikiLoadingOverlay.swift` | WikiLoadingOverlay, WikiInlineProgress | 通用加载组件 |

---

*文档生成时间：2026-04-29 | 由 WikiCraft 代码库自动分析生成*
