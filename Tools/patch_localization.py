import json
import os

file_path = "Sources/Localization/Localizable.xcstrings"

with open(file_path, "r", encoding="utf-8") as f:
    data = json.load(f)

strings = data.get("strings", {})

def update_key(key, zh=None, en=None):
    if key not in strings:
        strings[key] = {"localizations": {}}
    
    if "localizations" not in strings[key]:
        strings[key]["localizations"] = {}
        
    if zh:
        strings[key]["localizations"]["zh-Hans"] = {
            "stringUnit": {"state": "translated", "value": zh}
        }
    if en:
        strings[key]["localizations"]["en"] = {
            "stringUnit": {"state": "translated", "value": en}
        }

# Chat
update_key("chat.group.user", zh="我的指令", en="My Instructions")
update_key("chat.group.ai", zh="AI 启发", en="AI Inspiration")
update_key("chat.group.base", zh="基础引导", en="Basic Guide")
update_key("chat.deepExplorePrompt", zh="总体探索: %@", en="Deep exploration: %@")
update_key("chat.ai.thinking", zh="AI 正在思考...", en="AI Thinking...")
update_key("chat.explorationAndPrompts", zh="总体探索与快捷指令", en="Exploration & Prompts")
update_key("chat.conversationHistory", zh="对话记录", en="Conversation History")
update_key("chat.selectedHistory", zh="选中的对话", en="Selected History")
update_key("chat.role.user", zh="你", en="You")
update_key("chat.role.ai", zh="AI", en="AI")
update_key("chat.fallback.q1", zh="总结我最近添加的知识点", en="Summarize my recent knowledge")
update_key("chat.fallback.q2", zh="我目前的研究重点是什么？", en="What is my current research focus?")
update_key("chat.fallback.q3", zh="帮我发现不同领域间的潜在联系", en="Help me discover potential links")
update_key("chat.exportSelectedMarkdown", zh="导出选中的 Markdown", en="Export Selected Markdown")
update_key("chat.exportSelectedPDF", zh="导出选中的 PDF", en="Export Selected PDF")
update_key("chat.error.noResponse", zh="未收到 AI 响应，请检查网络或模型配置。", en="No response from AI. Please check your network or model configuration.")
update_key("llm.messages", zh="条消息", en="messages")

# Sidebar
update_key("sidebar.dashboard", zh="知识仪表", en="Knowledge Dashboard")
update_key("sidebar.weeklyInsight", zh="知识周报", en="Weekly Insight")
update_key("sidebar.synthesis", zh="知识合成", en="Knowledge Synthesis")
update_key("sidebar.title", zh="知识库", en="Knowledge Vault")
update_key("sidebar.allPages", zh="所有页面", en="All Pages")
update_key("sidebar.pluginMarket", zh="插件市场 (影子服务器)", en="Plugin Market (Mock)")

# Lint
update_key("lint.aiSuggestions", zh="AI 建议", en="AI Suggestions")
update_key("lint.noAISuggestions", zh="暂无 AI 建议", en="No AI Suggestions")
update_key("lint.noAISuggestionsHint", zh="运行深度扫描以获取 AI 建议。", en="Run a deep scan to get AI suggestions.")
update_key("lint.runAIScan", zh="运行 AI 扫描", en="Run AI Scan")
update_key("lint.runCheck", zh="运行检查", en="Run Check")
update_key("lint.scanning", zh="正在扫描...", en="Scanning...")
update_key("lint.title", zh="健康检查", en="Health Check")
update_key("lint.detailIssues", zh="详细问题清单", en="Detailed Issues")
update_key("lint.errors", zh="%d 个错误", en="%d Errors")
update_key("lint.warnings", zh="%d 个警告", en="%d Warnings")
update_key("lint.tips", zh="%d 个优化建议", en="%d Optimization Tips")
update_key("lint.lastCheck.title", zh="上次检查时间", en="Last Checked")
update_key("lint.lastCheck.never", zh="从未检查", en="Never")
update_key("lint.health.score", zh="健康得分", en="Health Score")
update_key("lint.health.excellent", zh="非常健康", en="Excellent")
update_key("lint.health.good", zh="良好", en="Good")
update_key("lint.health.fair", zh="尚可", en="Fair")
update_key("lint.health.poor", zh="亟待优化", en="Needs Improvement")
update_key("lint.metric.pages", zh="总节点数", en="Total Pages")
update_key("lint.metric.broken", zh="断开链接", en="Broken Links")
update_key("lint.metric.orphans", zh="孤立节点", en="Orphan Nodes")
update_key("lint.metric.links", zh="总引用数", en="Total References")
update_key("lint.refactorSection", zh="重构建议", en="Refactor Suggestions")
update_key("lint.linkDiscoverySection", zh="潜在关联发现", en="Potential Link Discovery")
update_key("lint.noIssues", zh="未发现问题", en="No Issues Found")
update_key("lint.noIssuesHint", zh="你的知识库非常整洁，请继续保持！", en="Your knowledge vault is very tidy. Keep it up!")
update_key("lint.apply", zh="应用", en="Apply")
update_key("lint.aiFixSuggestion", zh="AI 修复建议: %@", en="AI Fix Suggestion: %@")
update_key("lint.goToPage", zh="前往页面", en="Go to Page")
update_key("lint.aiSuggestionError", zh="无法获取 AI 建议: %@", en="Failed to get AI suggestion: %@")
update_key("lint.brokenLink", zh="断链: 「%1$@」引用了不存在的页面 [[%2$@]]", en="Broken link: \"%1$@\" refers to missing page [[%2$@]]")
update_key("lint.brokenLinkSuggestion", zh="创建页面「%@」或修复链接", en="Create page \"%@\" or fix link")
update_key("lint.orphanPage", zh="孤立页面: 「%@」没有任何反向链接", en="Orphan page: \"%@\" has no backlinks")
update_key("lint.orphanSuggestion", zh="考虑从相关页面添加 [[%@]] 链接", en="Consider adding [[%@]] links from related pages")
update_key("lint.cycleMessage", zh="循环引用: 「%1$@」与「%2$@」互相引用", en="Circular reference: \"%1$@\" and \"%2$@\" link to each other")
update_key("lint.cycleSuggestion", zh="考虑打破循环，建立单向引用或更高层级的聚合页面", en="Consider breaking the cycle with a one-way link or a higher-level aggregate page")
update_key("lint.stubContent", zh="存根页面: 「%@」内容过少", en="Stub page: \"%@\" has very little content")
update_key("lint.stubSuggestion", zh="丰富页面内容，或将其合并至相关页面", en="Add more content or merge it into related pages")
update_key("lint.outdated", zh="陈旧内容: 「%@」已超过 30 天未更新", en="Stale content: \"%@\" has not been updated in 30 days")
update_key("lint.outdatedSuggestion", zh="检视并更新过时的信息", en="Review and update outdated information")
update_key("misc.ignore", zh="忽略", en="Ignore")

# Settings
update_key("settings.resetOnboarding", zh="重置引导流程", en="Reset Onboarding")
update_key("settings.resetOnboarding.title", zh="重置引导", en="Reset Onboarding")
update_key("settings.resetOnboarding.message", zh="确定要重新开始新手引导吗？", en="Are you sure you want to restart the onboarding process?")
update_key("settings.resetOnboarding.success", zh="引导流程已重置", en="Onboarding reset successfully")
update_key("settings.injectDemo.successMessage", zh="成功注入 %d 条演示数据，界面已同步更新。", en="Successfully injected %d demo entries. UI has been updated.")
update_key("settings.clearAll.success", zh="数据已清空", en="Data cleared successfully")
update_key("settings.advancedMaintenance", zh="高级维护与数据管理", en="Advanced Maintenance & Data Management")

# Ingest
update_key("ingest.title", zh="知识导入", en="Knowledge Ingest")
update_key("ingest.manualEntry", zh="手动输入", en="Manual Entry")
update_key("ingest.manualEntryHint", zh="直接输入标题和内容创建页面", en="Directly enter title and content")
update_key("ingest.fileImport", zh="文件导入", en="File Import")
update_key("ingest.fileImportHint", zh="支持 Markdown, PDF, TXT 等格式", en="Supports Markdown, PDF, TXT etc.")
update_key("ingest.urlImport", zh="链接导入", en="URL Import")
update_key("ingest.urlImportHint", zh="从网页或文章链接提取知识", en="Extract knowledge from web links")
update_key("ingest.ocrScan", zh="OCR 扫描", en="OCR Scan")
update_key("ingest.ocrScanHint", zh="识别图片或相机拍摄的文字", en="Recognize text from images or camera")
update_key("ingest.clipboardImport", zh="剪贴板导入", en="Clipboard Import")
update_key("ingest.clipboardImportHint", zh="从剪贴板中的文本快速创建", en="Quickly create from clipboard text")
update_key("ingest.voiceNote", zh="语音笔记", en="Voice Note")
update_key("ingest.voiceNoteHint", zh="通过语音转文字录入知识", en="Input knowledge via speech-to-text")

# Log
update_key("log.noLogs", zh="暂无操作日志", en="No operation logs")
update_key("log.noDetails", zh="无详细信息", en="No details")
update_key("log.clearConfirmTitle", zh="确定要清空日志吗？", en="Clear all logs?")
update_key("log.clearConfirmMessage", zh="此操作将永久删除所有本地审计日志，且不可恢复。", en="This will permanently delete all local audit logs and cannot be undone.")
update_key("log.error.saveFailed", zh="无法保存日志: %@", en="Failed to save logs: %@")

update_key("ingest.hero.subtitle", zh="将零散的信息转化为结构化的知识", en="Transform scattered info into structured knowledge")
update_key("ingest.manualTitle", zh="手动录入", en="Manual Entry")
update_key("ingest.field.title", zh="标题", en="Title")
update_key("ingest.field.titlePlaceholder", zh="输入页面标题...", en="Enter page title...")
update_key("ingest.field.tags", zh="标签 (英文逗号分隔)", en="Tags (comma-separated)")
update_key("ingest.field.tagsPlaceholder", zh="AI, 知识管理, LLM...", en="AI, Knowledge Management, LLM...")
update_key("ingest.field.content", zh="内容", en="Content")
update_key("ingest.field.type", zh="类型", en="Type")
update_key("ingest.field.icon", zh="图标", en="Icon")
update_key("ingest.iconCustom", zh="自定义", en="Custom")
update_key("ingest.iconDefault", zh="默认", en="Default")
update_key("ingest.iconReset", zh="重置", en="Reset")

update_key("ingest.submit", zh="导入到知识库", en="Import to Wiki")
update_key("ingest.submitting", zh="正在导入...", en="Importing...")
update_key("ingest.preview", zh="智能预览", en="Smart Preview")
update_key("ingest.previewConfirm", zh="确认应用", en="Confirm")
update_key("ingest.previewDiscard", zh="放弃", en="Discard")
update_key("ingest.suggestLinks", zh="建议关联的页面", en="Suggested Related Pages")

update_key("ingest.tips", zh="导入技巧", en="Import Tips")
update_key("ingest.method.file", zh="文件拖拽", en="File Drag & Drop")
update_key("ingest.method.fileDesc", zh="支持多文件批量导入", en="Support batch import")
update_key("ingest.method.ocr", zh="实时扫描", en="Live Scan")
update_key("ingest.method.ocrDesc", zh="高精度文字识别", en="High precision OCR")
update_key("ingest.method.manual", zh="结构化编辑", en="Structured Edit")
update_key("ingest.method.manualDesc", zh="支持 Markdown 语法", en="Support Markdown syntax")

update_key("ingest.queue.title", zh="导入队列", en="Ingest Queue")
update_key("ingest.queue.desc", zh="正在处理的导入任务", en="Processing ingest tasks")
update_key("ingest.recentActivities", zh="最近活动", en="Recent Activities")
update_key("ingest.fileTooLarge", zh="文件过大 (限 50MB)", en="File too large (Max 50MB)")
update_key("ingest.processing", zh="正在处理...", en="Processing...")
update_key("ingest.success", zh="导入成功", en="Ingest Successful")
update_key("ingest.error", zh="导入失败", en="Ingest Failed")
update_key("ingest.ok", zh="确定", en="OK")
update_key("ingest.smartIngestDoneDesc", zh="已智能编译为 %@ 节点", en="Smart compiled as %@ node")
update_key("ingest.clipboardEmpty", zh="剪贴板为空", en="Clipboard is empty")
update_key("ingest.smartToggle", zh="智能导入 (LLM)", en="Smart Import (LLM)")
update_key("ingest.smartToggleHint", zh="使用 AI 自动提取标签、分类并优化内容格式。", en="Use AI to extract tags, types and optimize content.")
update_key("ingest.deepScan", zh="深度扫描 (RAG)", en="Deep Scan (RAG)")
update_key("ingest.deepScanDesc", zh="对知识库进行全量向量化检索，自动发现新旧知识点之间的潜在关联。", en="Full vector search across vault to discover potential links between new and old knowledge.")
update_key("ingest.urlImportPlaceholder", zh="输入或粘贴网页链接 (每行一个)", en="Enter or paste URLs (one per line)")
update_key("ingest.webDesc", zh="支持大多数网页、文章和 PDF 链接。AI 将自动提取核心内容。", en="Supports most web pages, articles, and PDF links. AI will auto-extract core content.")

# OCR / Speech
update_key("ocr.title", zh="OCR 扫描", en="OCR Scan")
update_key("speech.title", zh="语音笔记", en="Voice Note")

# Tag
update_key("tag.title", zh="标签管理", en="Tag Management")
update_key("tags.addNew", zh="新建标签", en="New Tag")
update_key("tags.manageTitle", zh="管理", en="Manage")
update_key("tag.renameTag", zh="重命名标签", en="Rename Tag")
update_key("tag.newName", zh="新名称", en="New Name")
update_key("tag.renameMessage", zh="将 '%@' 重命名为：", en="Rename '%@' to:")
update_key("tag.deleteTag", zh="删除标签", en="Delete Tag")
update_key("tag.deleteMessage", zh="确定要删除标签 '%@' 吗？此操作不会删除页面。", en="Are you sure you want to delete tag '%@'? This will not delete the pages.")
update_key("tags.inputName", zh="标签名称", en="Tag Name")
update_key("tags.createHint", zh="请输入新标签的名称", en="Please enter the name of the new tag")
update_key("tags.confirmBulkDelete", zh="批量删除确认", en="Confirm Bulk Delete")
update_key("tags.bulkDeleteWarning", zh="确定要删除选中的 %lld 个标签吗？", en="Are you sure you want to delete the selected %lld tags?")
update_key("tags.selectedCount", zh="已选中 %lld 个", en="%lld Selected")
update_key("tag.noTags", zh="暂无标签", en="No Tags")
update_key("tag.noTagsHint", zh="你创建的标签将在这里集中展示", en="Your tags will be displayed here")
update_key("tag.rename", zh="重命名", en="Rename")
update_key("tag.delete", zh="删除", en="Delete")
update_key("tag.tagPages", zh="%lld 个关联页面", en="%lld Related Pages")
update_key("tags.selectToManage", zh="选择标签进行管理", en="Select tags to manage")
update_key("tagcloud.selectTag", zh="选择一个标签以查看关联内容", en="Select a tag to view content")
update_key("tags.pageTitle", zh="标签存根: %@", en="Tag Stub: %@")
update_key("tags.pageContent", zh="这是为了引入标签 '%@' 而创建的存根页面。", en="This is a stub page created to introduce the tag '%@'.")

# Dashboard / Stats
update_key("dashboard.totalPages", zh="总节点数", en="Total Nodes")
update_key("dashboard.totalLinks", zh="总关联数", en="Total Links")
update_key("dashboard.density", zh="连接密度", en="Connection Density")
update_key("dashboard.density.desc", zh="反映了知识点之间的关联紧密程度，密度越高，知识体系越稳固。", en="Reflects the tightness of connections between knowledge points. Higher density means a more solid knowledge system.")
update_key("dashboard.hotTopics", zh="热门领域", en="Hot Topics")
update_key("dashboard.pages", zh="个页面", en="pages")
update_key("dashboard.dailyInsights", zh="每日闪念", en="Daily Insights")
update_key("dashboard.dailyInsights.refresh", zh="点击刷新以获取新的见解", en="Tap to refresh for new insights")

update_key("stat.totalPages", zh="总节点数", en="Total Nodes")
update_key("stat.entities", zh="实体总数", en="Total Entities")
update_key("stat.concepts", zh="概念总数", en="Total Concepts")
update_key("stat.sources", zh="来源总数", en="Total Sources")
update_key("stat.newPages", zh="新增页面", en="New Pages")
update_key("stat.growth", zh="增长趋势", en="Growth Traction")

# Weekly Insight
update_key("insight.weeklyTitle", zh="知识周报", en="Weekly Insight")
update_key("weekly.aiAnalysis", zh="AI 智能分析", en="AI Intelligence Analysis")
update_key("insight.growth.steady", zh="稳步积累", en="Steady Accumulation")
update_key("insight.growth.explosive", zh="爆发式增长", en="Explosive Growth")
update_key("insight.tips.title", zh="深度建议", en="Deep Insights")
update_key("insight.tips.content", zh="基于本周的知识增长情况，建议你继续深入探索相关领域的关联，并尝试通过思维导图将零散的知识点串联起来。", en="Based on this week's knowledge growth, it is recommended to continue exploring connections in related fields and try to connect fragmented knowledge points through mindmaps.")

# Synthesis
update_key("synthesis.documentList", zh="已合成文档", en="Synthesis Documents")
update_key("synthesis.actions", zh="合成操作", en="Synthesis Actions")
update_key("synthesis.noDocs", zh="暂无此类合成文档", en="No synthesis documents")
update_key("synthesis.error.noPages", zh="知识库为空，无法进行合成", en="Vault is empty, cannot perform synthesis")
update_key("synthesis.error.limitReached", zh="已达到此类文档的存储上限", en="Storage limit reached for this type")
update_key("synthesis.generatedAt", zh="生成于 %@", en="Generated: %@")

# Medals
update_key("medal.wall.title", zh="荣誉墙", en="Medal Wall")
update_key("medal.wall.count", zh="已获得 %lld 枚勋章", en="%lld Medals Earned")
update_key("medal.totalEarned", zh="已获得", en="Earned")
update_key("medal.progress", zh="勋章进度", en="Progress")
update_key("medal.category.explore", zh="初试锋芒", en="Explore")
update_key("medal.category.accumulation", zh="日积月累", en="Accumulation")
update_key("medal.category.connection", zh="万物互联", en="Connection")

update_key("medal.first_page.title", zh="第一步", en="First Step")
update_key("medal.first_page.desc", zh="创建了第一个知识节点", en="Created your first knowledge node")
update_key("medal.nodes_5.title", zh="初见成效", en="Getting Started")
update_key("medal.nodes_5.desc", zh="累计拥有 5 个知识节点", en="Accumulated 5 knowledge nodes")
update_key("medal.nodes_10.title", zh="步入正轨", en="On Track")
update_key("medal.nodes_10.desc", zh="累计拥有 10 个知识节点", en="Accumulated 10 knowledge nodes")
update_key("medal.nodes_100.title", zh="博学多识", en="Polymath")
update_key("medal.nodes_100.desc", zh="累计拥有 100 个知识节点", en="Accumulated 100 knowledge nodes")
update_key("medal.links_5.title", zh="连接初探", en="First Links")
update_key("medal.links_5.desc", zh="建立了 5 条知识关联", en="Established 5 knowledge links")
update_key("medal.links_10.title", zh="织网人", en="Web Weaver")
update_key("medal.links_10.desc", zh="建立了 10 条知识关联", en="Established 10 knowledge links")
update_key("medal.links_100.title", zh="百链成网", en="Networker")
update_key("medal.links_100.desc", zh="建立了 100 条知识关联", en="Established 100 knowledge links")

# AI Task / Task Center
update_key("aitask.center.title", zh="任务中心", en="Task Center")
update_key("aitask.categories", zh="任务分类", en="Categories")
update_key("aitask.noHistory", zh="暂无此类任务历史", en="No task history")
update_key("aitask.history.count", zh="累计执行 %lld 次", en="%lld executions")
update_key("aitask.list.title", zh="任务流详情", en="Task Flow Details")
update_key("aitask.empty.title", zh="当前无活跃任务", en="No Active Tasks")
update_key("aitask.empty.desc", zh="所有 AI 扫描、导出合成和健康检查任务的进度都将在这里显示。", en="Progress of all AI scans, synthesis, and health check tasks will be shown here.")
update_key("aitask.howToTrigger", zh="如何触发任务？", en="How to trigger tasks?")
update_key("aitask.guide.health", zh="健康检查", en="Health Check")
update_key("aitask.guide.health.desc", zh="在侧边栏点击“健康检查”", en="Click 'Health Check' in sidebar")
update_key("aitask.guide.aiscan", zh="智能扫描", en="AI Scan")
update_key("aitask.guide.aiscan.desc", zh="在侧边栏点击“深度扫描”", en="Click 'Deep Scan' in sidebar")
update_key("aitask.guide.ingest", zh="知识导入", en="Knowledge Ingest")
update_key("aitask.guide.ingest.desc", zh="从“导入”页面添加新内容", en="Add content from 'Ingest' page")
update_key("aitask.guide.synthesis", zh="知识合成", en="Knowledge Synthesis")
update_key("aitask.guide.synthesis.desc", zh="在合成中心发起导出任务", en="Start export tasks in Synthesis Center")

update_key("aitask.type.ingest", zh="知识导入", en="Ingest")
update_key("aitask.type.healthCheck", zh="健康检查", en="Health Check")
update_key("aitask.type.aiScan", zh="智能扫描", en="AI Scan")
update_key("aitask.type.ai", zh="AI 任务", en="AI Task")
update_key("aitask.type.synthesis", zh="知识合成", en="Synthesis")

update_key("aitask.status.pending", zh="等待中", en="Pending")
update_key("aitask.status.running", zh="执行中", en="Running")
update_key("aitask.status.completed", zh="已完成", en="Completed")
update_key("aitask.status.failed", zh="已失败", en="Failed")

# Welcome / Onboarding
update_key("app.name", zh="智元", en="ZhiYuan")
update_key("welcome.title", zh="欢迎使用智元", en="Welcome to ZhiYuan")
update_key("welcome.subtitle", zh="你的个人第二大脑与 AI 助手", en="Your personal second brain & AI assistant")
update_key("welcome.growthTrend", zh="知识增长趋势", en="Knowledge Growth Trend")
update_key("welcome.quickStart", zh="新手快速入门", en="Quick Start Guide")
update_key("welcome.guide.createPage", zh="创建你的第一个知识节点", en="Create your first knowledge node")
update_key("welcome.guide.wikiLink", zh="使用 [[双链]] 建立知识关联", en="Use [[Backlinks]] to connect knowledge")
update_key("welcome.demo.title", zh="探索 AI 代理演示数据", en="Explore AI Agent Demo Data")
update_key("welcome.demo.desc", zh="一键注入示例，快速体验图谱与 AI 合成", en="One-click inject to experience Graph & AI Synthesis")

update_key("action.createPage", zh="新建知识节点", en="Create Knowledge Node")
update_key("action.createPage.subtitle", zh="手动录入或使用 AI 模板", en="Manual entry or AI templates")
update_key("action.ingestKnowledge", zh="导入外部知识", en="Ingest External Knowledge")
update_key("action.ingestKnowledge.subtitle", zh="支持 PDF、链接与剪贴板", en="Support PDF, URL, and Clipboard")

# Security / Vault
update_key("security.unlockReason", zh="解锁您的知识金库", en="Unlock your Knowledge Vault")

# Plugins
update_key("plugin.market.connectionError", zh="无法连接至插件市场 (影子服务器)，请确保已启动 python3 -m http.server 8000", en="Cannot connect to Plugin Market. Please ensure the mock server is running.")

# Graph
update_key("graph.cluster.name", zh="主题簇 %lld", en="Topic Cluster %lld")

# Insight / Prompts
update_key("insight.daily.systemPrompt", zh="你是一个贴心的知识复习伙伴，用温暖自然的口吻帮助用户发现知识间的联系。", en="You are a caring knowledge review companion, helping users discover connections between knowledge in a warm and natural tone.")
update_key("insight.daily.prompt.recent", zh="你是一个贴心的知识复习伙伴。用户最近在关注：%@。推荐复习旧笔记《%@》，内容摘要：%@。请用自然亲切的口吻写一句推荐语，点明重读这篇笔记对当前学习的价值。不超过50字。返回JSON: {\"insight\": \"...\", \"suggestedConnection\": \"...\"}", en="You are a caring knowledge review companion. User's recent focus: %@. Recommend reviewing the old note \"%@\", content summary: %@. Please write a recommendation in a natural and friendly tone, highlighting the value of rereading this note for current learning. No more than 50 words. Return JSON: {\"insight\": \"...\", \"suggestedConnection\": \"...\"}")
update_key("insight.daily.prompt.oldest", zh="用自然的口吻写一句推荐语，建议复习《%@》这篇笔记，说明复习价值。不超过50字。内容：%@", en="Write a recommendation in a natural tone, suggesting to review the note \"%@\", explaining the value of review. No more than 50 words. Content: %@")

update_key("insight.weekly.systemPrompt", zh="你是一个资深知识架构师，擅长总结知识体系。", en="You are a senior knowledge architect, skilled at summarizing knowledge systems.")
update_key("insight.weekly.prompt", zh="# Role: 资深知识架构师\n# Context: 用户添加了节点：[%@]。\n# Task: 生成周度报告，包含认知锚点、关联密度等。要求 250 字以内。", en="# Role: Senior Knowledge Architect\n# Context: User added nodes: [%@].\n# Task: Generate a weekly report, including cognitive anchors, connection density, etc. Requirement: Within 250 words.")

# Audit Missing Keys
update_key("ai.status.analyzing", zh="正在分析内容...", en="Analyzing content...")
update_key("ai.status.preprocessing", zh="正在预处理分块...", en="Preprocessing chunks...")
update_key("export.countFormat", zh="共 %lld 条", en="Total %lld")
update_key("graph.copyWikiLink", zh="复制 Wiki 链接", en="Copy Wiki Link")
update_key("graph.viewDetail", zh="查看详情", en="View Detail")
update_key("import.externalVault", zh="导入外部金库", en="Import External Vault")
update_key("misc.action", zh="操作", en="Action")
update_key("misc.all", zh="全部", en="All")
update_key("misc.copyWikiLink", zh="复制双链链接", en="Copy Wiki Link")
update_key("misc.ignore", zh="忽略", en="Ignore")
update_key("misc.openInNewWindow", zh="在新窗口打开", en="Open in New Window")
update_key("misc.preview", zh="预览", en="Preview")
update_key("misc.quickPreview", zh="快速预览", en="Quick Preview")
update_key("misc.reset", zh="重置", en="Reset")
update_key("misc.save", zh="保存", en="Save")
update_key("misc.skip", zh="跳过", en="Skip")
update_key("misc.syncToReminders", zh="同步至提醒事项", en="Sync to Reminders")
update_key("page.history.manual", zh="手动修改", en="Manual Edit")
update_key("page.status", zh="状态", en="Status")
update_key("plugin.noResults", zh="未找到插件", en="No Plugins Found")
update_key("plugin.noResultsHint", zh="尝试更换搜索词", en="Try a different search term")
update_key("prompt.default.actions", zh="行动建议", en="Action Suggestions")
update_key("prompt.default.infographic", zh="可视化信息图", en="Infographic")
update_key("prompt.default.insightQuestions", zh="洞察提问", en="Insight Questions")
update_key("prompt.default.summary", zh="智能总结", en="Smart Summary")
update_key("settings.clearAll", zh="清空全部数据", en="Clear All Data")
update_key("sidebar.chat", zh="智能助手", en="AI Chat")
update_key("sidebar.graph", zh="知识图谱", en="Knowledge Graph")
update_key("synthesis.mindmap.title", zh="思维导图", en="Mindmap")
update_key("watch.capture", zh="快速记录", en="Quick Capture")
update_key("watch.dictate.hint", zh="点击麦克风开始录音", en="Tap mic to record")
update_key("watch.recents", zh="最近记录", en="Recents")

# Demo Data
update_key("demo.aiAgent.title", zh="AI Agent：超越对话的大脑", en="AI Agent: The Brain Beyond Chat")
update_key("demo.aiAgent.content", zh="# 什么是 AI Agent？\n\nAI Agent (人工智能代理) 是指能够感知环境、进行推理并采取行动以实现目标的智能体。不同于传统的 [[大语言模型 (LLM)]] 仅能进行对话，Agent 具备了“行动力”。\n\n## 核心公式\n**Agent = LLM + [[规划 (Planning)]] + [[记忆 (Memory)]] + [[工具使用 (Tool Use)]]**\n\n相关框架：AutoGPT, BabyAGI, LangChain", en="# What is an AI Agent?\n\nAn AI Agent is an intelligent entity that perceives its environment, reasons, and takes actions to achieve goals. Unlike traditional [[Large Language Models (LLM)]], which only chat, Agents have the power to 'act'.\n\n## Core Formula\n**Agent = LLM + [[Planning]] + [[Memory]] + [[Tool Use]]**\n\nFrameworks: AutoGPT, BabyAGI, LangChain")

update_key("demo.planning.title", zh="规划 (Planning)", en="Planning")
update_key("demo.planning.content", zh="# 规划 (Planning)\n\n规划是 Agent 解决复杂任务的基础。它通常分为以下几个子任务：\n\n1. **任务分解**: 将大目标拆解为可管理的小步骤 (如 Chain of Thought)。\n2. **自我反思**: 代理会对过去的行动进行修正和完善 (如 ReAct 模式)。\n\n这使得 [[AI Agent：超越对话的大脑]] 能够处理需要多步推理的问题。", en="# Planning\n\nPlanning is the foundation for an Agent to solve complex tasks. It usually consists of the following sub-tasks:\n\n1. **Task Decomposition**: Breaking down large goals into manageable steps (e.g., Chain of Thought).\n2. **Self-Reflection**: The agent corrects and refines past actions (e.g., ReAct mode).\n\nThis enables [[AI Agent: The Brain Beyond Chat]] to handle problems requiring multi-step reasoning.")

update_key("demo.memory.title", zh="记忆 (Memory)", en="Memory")
update_key("demo.memory.content", zh="# 记忆 (Memory)\n\n记忆能力让 Agent 能够保持上下文连贯性：\n\n- **短期记忆**: 利用 [[大语言模型 (LLM)]] 的上下文窗口记录当前任务。\n- **长期记忆**: 利用外部存储 (如 [[向量数据库]]) 进行信息检索。\n\n[[AI Agent：超越对话的大脑]] 利用长期记忆来实现跨会话的知识沉淀。", en="# Memory\n\nMemory enables the Agent to maintain contextual consistency:\n\n- **Short-term Memory**: Uses the [[Large Language Model (LLM)]]'s context window for the current task.\n- **Long-term Memory**: Uses external storage (e.g., [[Vector Database]]) for information retrieval.\n\n[[AI Agent: The Brain Beyond Chat]] uses long-term memory for knowledge accumulation across sessions.")

update_key("demo.toolUse.title", zh="工具使用 (Tool Use)", en="Tool Use")
update_key("demo.toolUse.content", zh="# 工具使用 (Tool Use / Tool Calling)\n\n工具使用是 Agent 与现实世界交互的桥梁。Agent 可以通过 API 调用：\n\n- **实时搜索**: 获取最新资讯。\n- **代码执行**: 进行复杂的数学运算。\n- **文件操作**: 处理本地文档。\n\n这让 [[AI Agent：超越对话的大脑]] 真正具备了解决实际问题的能力。", en="# Tool Use / Tool Calling\n\nTool use is the bridge for an Agent to interact with the real world. Agents can call APIs for:\n\n- **Real-time Search**: Get latest news.\n- **Code Execution**: Perform complex calculations.\n- **File Operations**: Process local documents.\n\nThis makes [[AI Agent: The Brain Beyond Chat]] truly capable of solving real-world problems.")

update_key("demo.llm.title", zh="大语言模型 (LLM)", en="Large Language Model (LLM)")
update_key("demo.llm.content", zh="# LLM 作为中枢神经\n\n在 [[AI Agent：超越对话的大脑]] 架构中，LLM 扮演了“大脑”的角色，负责理解、决策和任务分发。\n\n为了训练出更强的 Agent，通常需要使用 [[大语言模型训练流程]]，特别是针对函数调用 (Function Calling) 的专门微调。", en="# LLM as the Central Nervous System\n\nIn the [[AI Agent: The Brain Beyond Chat]] architecture, the LLM acts as the 'brain', responsible for understanding, decision-making, and task distribution.\n\nTo train stronger Agents, specialized fine-tuning for Function Calling is often required.")

# Query Rewrite
update_key("prompt.queryRewrite.instruction", zh="你是一位知识检索专家。请分析以下“用户原始查询”，并将其改写为一组更专业的“结构化检索词”。", en="You are a knowledge retrieval expert. Please analyze the following 'User Original Query' and rewrite it into a set of professional 'Structured Retrieval Terms'.")
update_key("prompt.queryRewrite.rules", zh="要求：", en="Requirements:")
update_key("prompt.queryRewrite.rule1", zh="识别查询中的核心概念、实体和技术术语。", en="Identify core concepts, entities, and technical terms in the query.")
update_key("prompt.queryRewrite.rule2", zh="补全缩写（如“AI”改为“人工智能”）。", en="Expand abbreviations (e.g., 'AI' to 'Artificial Intelligence').")
update_key("prompt.queryRewrite.rule3", zh="扩展相关的近义词或相关领域词。", en="Expand related synonyms or domain-specific terms.")
update_key("prompt.queryRewrite.rule4", zh="请直接输出改写后的检索字符串，各关键词以逗号分隔。", en="Directly output the rewritten search string, with keywords separated by commas.")
update_key("prompt.queryRewrite.userQuery", zh="用户原始查询", en="User Original Query")
update_key("prompt.queryRewrite.footer", zh="检索集合：", en="Search Collection:")

# LLM / AI Settings
update_key("llm.title", zh="模型设置", en="Model Settings")
update_key("llm.enableAssistant", zh="开启 LLM 助手", en="Enable LLM Assistant")
update_key("llm.status", zh="状态", en="Status")
update_key("llm.provider", zh="提供商", en="Provider")
update_key("llm.apiKey", zh="API 密钥", en="API Key")
update_key("llm.apiAddress", zh="API 地址", en="API Address")
update_key("llm.model", zh="模型名称", en="Model Name")
update_key("llm.configuration", zh="模型配置", en="Configuration")
update_key("llm.testing", zh="正在测试...", en="Testing...")
update_key("llm.testConnection", zh="测试连接", en="Test Connection")
update_key("llm.validation", zh="连通性校验", en="Connectivity Validation")
update_key("llm.info", zh="说明", en="Info")
update_key("llm.info.localKey", zh="您的 API 密钥仅在本地加密存储，绝不会上传到第三方服务器。", en="Your API key is only stored locally and encrypted.")
update_key("llm.info.contextSent", zh="只有当前页面内容及相关元数据会被发送给 LLM。", en="Only current page content and metadata are sent to LLM.")
update_key("llm.info.openAICompatible", zh="支持所有兼容 OpenAI API 规范的提供商。", en="Supports all OpenAI-compatible providers.")
update_key("llm.info.smartIngest", zh="开启后，导入知识时将自动使用 LLM 进行优化。", en="If enabled, LLM will optimize knowledge during ingest.")

update_key("ondevice.assistMode", zh="协作式 AI (影子模式)", en="Collaborative AI (Shadow Mode)")
update_key("ondevice.assistDesc", zh="开启后，AI 将在后台静默运行，为您提供即时的知识发现和重构建议。", en="AI runs silently in background to provide instant insights and refactor tips.")
update_key("ondevice.enableAutoScan", zh="自动扫描知识库", en="Auto Scan Vault")
update_key("ondevice.autoRefactor", zh="自动生成重构建议", en="Auto Refactor Suggestions")
update_key("ondevice.connected", zh="连接成功", en="Connected")
update_key("ondevice.errorFormat", zh="连接失败: %@", en="Connection Failed: %@")

# Onboarding & Coachmarks
update_key("onboarding.step.welcome.title", zh="欢迎来到 %@", en="Welcome to %@")
update_key("onboarding.step.welcome.desc", zh="智元是一款基于 LLM 的第二大脑工具，旨在通过双向链接和图谱技术，帮助您构建结构化的个人知识体系。", en="ZhiYuan is an LLM-powered second brain tool designed to help you build a structured knowledge vault via backlinking and graph technology.")
update_key("onboarding.step.linking.title", zh="双向链接的力量", en="Power of Backlinking")
update_key("onboarding.step.linking.desc", zh="使用 [[标题]] 语法，在不同页面之间建立语义关联，让碎片化的信息自然流动、聚合。", en="Use [[title]] syntax to create semantic links between pages, letting fragmented info flow and aggregate naturally.")
update_key("onboarding.step.aiLab.title", zh="AI 原生协作", en="AI-Native Collaboration")
update_key("onboarding.step.aiLab.desc", zh="内置深度集成的 AI 助手，支持智能摘要、测验生成、语法修复及自动化知识合成。", en="Deeply integrated AI assistant supports smart summary, quiz generation, linting, and automated synthesis.")
update_key("onboarding.step.graph.title", zh="可视化知识图谱", en="Visual Knowledge Graph")
update_key("onboarding.step.graph.desc", zh="通过交互式 2D/3D 图谱，直观洞察知识之间的隐藏关联，发现思想的成长轨迹。", en="Discover hidden links between knowledge and visualize your thought trajectory via interactive 2D/3D graphs.")
update_key("onboarding.step.vault.title", zh="开启您的智慧之旅", en="Start Your Journey")
update_key("onboarding.step.vault.desc", zh="现在，开始录入您的第一条知识，让您的智慧在“智元”中生根发芽。", en="Now, start entering your first piece of knowledge and let your wisdom take root in ZhiYuan.")
update_key("onboarding.action.start", zh="立即开始", en="Get Started")
update_key("onboarding.action.next", zh="下一步", en="Next")
update_key("onboarding.action.skip", zh="跳过", en="Skip")

update_key("coachmark.graphDiscovery.title", zh="发现隐藏的关联", en="Discover Hidden Links")
update_key("coachmark.graphDiscovery.desc", zh="您的知识库中存在一些 AI 识别出的潜在关联，前往图谱视图进行确认并一键建立链接。", en="AI has identified potential links in your vault. Head to Graph view to confirm and link them with one click.")
update_key("coachmark.graphDiscovery.action", zh="前往查看", en="Check it Out")
update_key("misc.skip", zh="忽略", en="Skip")

# AI Assistant Shortcuts
update_key("prompt.shortcut.deepReview", zh="深度复盘我的核心概念", en="Deeply review my core concepts")
update_key("prompt.shortcut.findGaps", zh="查找我知识体系中的断层", en="Find gaps in my knowledge system")
update_key("prompt.shortcut.studyPath", zh="规划我的下一步学习路径", en="Plan my next study path")

# Insight Recap
update_key("insight.recap.tip", zh="点击查看更多关联建议", en="Tap to see more connection suggestions")

# App
update_key("app.name", zh="智元", en="ZhiYuan")

# Accessibility
update_key("a11y.links", zh="关联数", en="Links")
update_key("a11y.tags", zh="标签", en="Tags")
update_key("a11y.words", zh="字数", en="Word count")
update_key("a11y.tapToOpen", zh="轻点以打开", en="Tap to open")

# Backup
update_key("backup.title", zh="数据备份", en="Data Backup")
update_key("backup.lastBackup", zh="上次备份", en="Last Backup")
update_key("backup.createNow", zh="立即备份", en="Backup Now")
update_key("backup.restore", zh="恢复备份", en="Restore")

# Collaboration
update_key("collab.title", zh="协作中心", en="Collaboration")
update_key("collab.hostSession", zh="开启协作会话", en="Host Session")
update_key("collab.joinSession", zh="加入协作会话", en="Join Session")

# Misc Extensions
update_key("misc.all", zh="全部", en="All")
update_key("misc.reset", zh="重置", en="Reset")
update_key("misc.skip", zh="跳过", en="Skip")
update_key("misc.copyWikiLink", zh="复制双链链接", en="Copy Wiki Link")

# Action Extensions
update_key("action.generateMindmap", zh="生成思维导图", en="Generate Mindmap")
update_key("action.generateQuiz", zh="生成知识测验", en="Generate Quiz")
update_key("action.generateReport", zh="生成深度报告", en="Generate Report")
update_key("action.generateSlides", zh="生成演示文稿", en="Generate Slides")
update_key("action.generateInfographic", zh="生成信息图表", en="Generate Infographic")

# Quiz Generation Labels
update_key("prompt.quiz.defaultTitle", zh="知识测验", en="Knowledge Quiz")
update_key("prompt.quiz.question", zh="问题", en="Question")
update_key("prompt.quiz.option", zh="选项", en="Option")
update_key("prompt.quiz.explanation", zh="解析", en="Explanation")

# Quiz View
update_key("quiz.title", zh="知识测验", en="Knowledge Quiz")
update_key("quiz.questionFormat", zh="题目 %d / %d", en="Question %d / %d")
update_key("quiz.scoreFormat", zh="得分: %d", en="Score: %d")
update_key("quiz.completed", zh="测验完成", en="Quiz Completed")
update_key("quiz.yourScore", zh="你的得分", en="Your Score")
update_key("quiz.backToPage", zh="返回页面", en="Back to Page")
update_key("quiz.showAnswer", zh="查看答案与解析", en="Show Answer & Explanation")
update_key("quiz.correctAnswer", zh="正确答案", en="Correct Answer")
update_key("quiz.explanation", zh="解析", en="Explanation")
update_key("misc.correct", zh="正确", en="Correct")
update_key("misc.incorrect", zh="错误", en="Incorrect")
update_key("misc.nextQuestion", zh="下一题", en="Next Question")
update_key("misc.viewResults", zh="查看结果", en="View Results")

# LLM Prompt Labels
update_key("llm.prompt.pageTitle", zh="页面标题", en="Page Title")
update_key("llm.prompt.issueDesc", zh="问题描述", en="Issue Description")
update_key("llm.prompt.issueType", zh="问题类型", en="Issue Type")
update_key("llm.prompt.pageContentSnippet", zh="当前页面部分内容", en="Current Page Content Snippet")
update_key("llm.prompt.otherPageTitles", zh="知识库中的其他页面标题", en="Other Page Titles in Vault")

# Misc
update_key("misc.success", zh="操作成功", en="Success")
update_key("misc.awesome", zh="好的", en="Awesome")
update_key("misc.close", zh="关闭", en="Close")
update_key("misc.done", zh="完成", en="Done")
update_key("misc.error", zh="错误", en="Error")
update_key("misc.ok", zh="确定", en="OK")
update_key("misc.confirm", zh="确定", en="Confirm")
update_key("misc.clear", zh="清空", en="Clear")
update_key("misc.clearAll", zh="全部清空", en="Clear All")
update_key("misc.cancel", zh="取消", en="Cancel")
update_key("misc.create", zh="创建", en="Create")
update_key("misc.delete", zh="删除", en="Delete")
update_key("misc.deleteAll", zh="全部删除", en="Delete All")
update_key("misc.bulkDelete", zh="批量删除", en="Bulk Delete")
update_key("misc.loading", zh="加载中...", en="Loading...")
update_key("misc.view", zh="查看", en="View")
update_key("misc.edit", zh="编辑", en="Edit")
update_key("misc.copy", zh="复制", en="Copy")
update_key("misc.import", zh="导入", en="Import")
update_key("misc.unknown", zh="未知", en="Unknown")

data["strings"] = strings

with open(file_path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("Successfully updated Localizable.xcstrings")
