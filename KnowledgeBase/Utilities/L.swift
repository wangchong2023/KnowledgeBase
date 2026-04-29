import Foundation

// MARK: - Language Mode
/// 语言偏好选项
enum LanguageMode: String, CaseIterable {
    case system
    case chinese
    case english

    var displayName: String {
        switch self {
        case .system: return L.tr("settings.language.system")
        case .chinese: return "简体中文"
        case .english: return "English"
        }
    }

    var icon: String {
        switch self {
        case .system: return "globe"
        case .chinese: return "character.book.closed"
        case .english: return "character.cursor.ibeam"
        }
    }
}

// MARK: - Localization Helper
/// Simple localization system: Chinese Simplified (zh-Hans) default, English fallback.
/// Supports user-configurable language preference, defaults to system language.
enum L {

    // MARK: - Language Preference
    /// 用户语言偏好，存储在 UserDefaults
    private static let languageModeKey = "km_language_mode"
    private static var languageModeRaw: String {
        get { UserDefaults.standard.string(forKey: languageModeKey) ?? LanguageMode.system.rawValue }
        set { UserDefaults.standard.set(newValue, forKey: languageModeKey) }
    }

    /// 当前语言模式
    static var languageMode: LanguageMode {
        get { LanguageMode(rawValue: languageModeRaw) ?? .system }
        set { languageModeRaw = newValue.rawValue }
    }

    /// 当前实际语言代码：优先读用户偏好，否则跟随系统
    static var currentLanguage: String {
        switch languageMode {
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "en"
            if preferred.hasPrefix("zh-Hans") || preferred.hasPrefix("zh-CN") || preferred.hasPrefix("zh_Hans") {
                return "zh-Hans"
            }
            return "en"
        case .chinese:
            return "zh-Hans"
        case .english:
            return "en"
        }
    }

    static var isChinese: Bool { currentLanguage == "zh-Hans" }

    // MARK: - Lookup
    /// 每次调用 tr() 时重新读取语言，确保语言切换后立即生效
    static func tr(_ key: String) -> String {
        let lang = currentLanguage
        if let url = Bundle.main.url(forResource: "Localizable", withExtension: "strings", subdirectory: "\(lang).lproj"),
           let data = try? Data(contentsOf: url),
           let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: String] {
            return dict[key] ?? key
        }
        // Fallback: use embedded strings
        return lang == "zh-Hans" ? zhStrings[key] ?? key : enStrings[key] ?? key
    }

    /// 带格式化参数的翻译，如 trf("settings.count", 42) → "共 42 条"
    static func trf(_ key: String, _ args: CVarArg...) -> String {
        let template = tr(key)
        if args.isEmpty {
            return template
        }
        return String(format: template, arguments: args)
    }
    
    // MARK: - Embedded Strings (Fallback)
    // These are used when .strings files are not found (e.g., during development).
    // In production, the .lproj/ files take precedence.
    
    private static let zhStrings: [String: String] = [
        // MARK: - Tab Bar
        "tab.wiki": "知识库",
        "tab.graph": "图谱",
        "tab.search": "搜索",
        "tab.ingest": "导入",
        "tab.pdf": "PDF",
        "tab.voice": "语音",
        "tab.chat": "AI",
        "tab.collab": "协作",
        "tab.settings": "设置",
        
        // MARK: - Page Types
        "type.entity": "实体",
        "type.concept": "概念",
        "type.source": "来源",
        "type.comparison": "对比",
        "type.map": "地图",
        "type.raw": "原始",
        
        // MARK: - Page Status
        "status.active": "活跃",
        "status.stub": "占位",
        "status.needsUpdate": "待更新",
        "status.deprecated": "已弃用",
        
        // MARK: - Confidence
        "confidence.high": "高",
        "confidence.medium": "中",
        "confidence.low": "低",
        
        // MARK: - Welcome Page
        "welcome.subtitle": "基于 Karpathy LLM Wiki 的 iOS 知识管理",
        "stat.totalPages": "总页面",
        "stat.entities": "实体",
        "stat.concepts": "概念",
        "stat.sources": "来源",
        "quickStart": "快速开始",
        "action.createPage": "创建页面",
        "action.createPage.subtitle": "新建一个 Wiki 页面",
        "action.ingestKnowledge": "导入知识",
        "action.ingestKnowledge.subtitle": "将原始资料编译到 Wiki",
        "action.browseGraph": "浏览图谱",
        "action.browseGraph.subtitle": "可视化知识关联",
        "action.healthCheck": "健康检查",
        "action.healthCheck.subtitle": "检测断链、孤立页面、矛盾",
        "recentUpdates": "最近更新",
        "pinned": "已收藏",
        
        // MARK: - Sidebar
        "sidebar.navigation": "导航",
        "sidebar.fullIndex": "总索引",
        "sidebar.operationLog": "操作日志",
        "sidebar.tags": "标签",
        "sidebar.tools": "工具",
        "sidebar.healthCheck": "健康检查",
        
        // MARK: - Page Detail
        "detail.pageType": "页面类型",
        "detail.status": "状态",
        "detail.confidence": "可信度",
        "detail.deletePage": "删除页面",
        "detail.confirmDelete": "确认删除",
        "detail.deleteMessage": "此操作不可恢复，页面及所有引用将被删除。",
        "detail.cancel": "取消",
        "detail.backlinks": "反向链接",
        "detail.noBacklinks": "暂无反向链接",
        "detail.created": "创建",
        "detail.updated": "更新",
        "detail.words": "字",
        "detail.outLinks": "出链",
        
        // MARK: - Search
        "search.placeholder": "搜索页面、标签、内容...",
        "search.all": "全部",
        "search.noResults": "没有找到匹配的页面",
        "search.pages": "个页面",
        "search.sort.recentlyUpdated": "最近更新",
        "search.sort.recentlyCreated": "最近创建",
        "search.sort.title": "标题",
        "search.sort.type": "类型",
        
        // MARK: - Ingest
        "ingest.title": "知识导入",
        "ingest.titleLabel": "标题",
        "ingest.titlePlaceholder": "输入页面标题",
        "ingest.typeLabel": "类型",
        "ingest.tagsLabel": "标签（逗号分隔）",
        "ingest.tagsPlaceholder": "AI, 知识管理, LLM",
        "ingest.contentLabel": "内容",
        "ingest.smartIngest": "智能导入 (LLM)",
        "ingest.smartIngest.description": "LLM 将自动编译原始资料：提取关键信息、建立交叉引用、推荐标签和类型",
        "ingest.compiling": "编译中...",
        "ingest.success": "导入成功！知识已编译到 Wiki",
        "ingest.flow": "导入流程",
        "ingest.step1": "将原始资料粘贴到内容区域",
        "ingest.step2": "选择页面类型和标签",
        "ingest.step3": "点击导入，系统自动编译",
        "ingest.step4": "自动检测已有页面的交叉引用",
        "ingest.step5": "更新索引和操作日志",
        "ingest.llmPreview": "LLM 编译预览",
        "ingest.confirmIngest": "确认导入",
        "ingest.discard": "放弃",
        "ingest.suggestedRelations": "建议关联",
        "ingest.error": "错误",
        "ingest.ok": "确定",
        
        // MARK: - Lint
        "lint.runCheck": "运行健康检查",
        "lint.checking": "检查中...",
        "lint.foundIssues": "发现 %d 个问题",
        "lint.healthy": "知识库状态良好",
        "lint.healthyDesc": "没有发现断链、孤立页面或矛盾内容",
        "lint.errors": "错误",
        "lint.warnings": "警告",
        "lint.tips": "提示",
        "lint.goToPage": "前往页面 →",
        
        // MARK: - Graph
        "graph.title": "知识图谱",
        "graph.emptyDesc": "页面间的关联将在此可视化",
        "graph.all": "全部",
        "graph.nodesConnections": "%d 节点 · %d 连接",
        "graph.linkHint": "在编辑页面时使用 [[页面名]] 即可建立链接",
        "graph.nodes": "节点",
        "graph.connections": "连接",
        
        // MARK: - Settings
        "settings.appearance": "外观",
        "settings.darkMode": "暗色模式",
        "settings.accentColor": "主题色",
        "settings.wikiStats": "知识库统计",
        "settings.totalWords": "总字数",
        "settings.stubPages": "占位页面",
        "settings.operationLog": "操作日志",
        "settings.tools": "工具",
        "settings.iCloudSync": "iCloud 同步",
        "settings.unavailable": "不可用",
        "settings.llmAssistant": "LLM 助手",
        "settings.notConfigured": "未配置",
        "settings.healthCheck": "健康检查",
        "settings.fullIndex": "总索引",
        "settings.importClipboard": "从剪贴板导入",
        "settings.about": "关于",
        "settings.aboutDesc": "基于 Karpathy LLM Wiki 方法论的 iOS 知识管理应用",
        "settings.coreConcept": "核心理念：编译而非检索，让知识持久累积",
        "settings.features": "功能特性",
        "settings.feature.bidirectionalLinks": "双向链接 [[wikilink]]",
        "settings.feature.graphViz": "知识图谱可视化",
        "settings.feature.ingest": "知识导入编译",
        "settings.feature.llmAssistant": "LLM AI 助手 + 智能导入",
        "settings.feature.lint": "Lint 健康检查",
        "settings.feature.fullTextSearch": "全文搜索与过滤",
        "settings.feature.darkTheme": "暗色主题",
        "settings.dangerZone": "危险操作",
        "settings.resetWiki": "重置知识库",
        "settings.resetAllData": "重置所有数据",
        "settings.resetWarning": "此操作将删除所有页面和日志，恢复为默认内容。不可恢复。",
        "settings.importComplete": "导入完成",
        "settings.importedCount": "成功导入 %d 个页面",
        "settings.gotIt": "好的",
        
        // MARK: - Chat
        "chat.title": "AI 助手",
        "chat.clearHistory": "清空对话",
        "chat.llmSettings": "LLM 设置",
        "chat.configureFirst": "请先配置 LLM API Key",
        "chat.welcomeTitle": "知识库 AI 助手",
        "chat.welcomeDesc": "基于你的知识库内容回答问题，发现关联，发现盲区",
        "chat.inputPlaceholder": "问你的知识库...",
        "chat.expandFull": "展开全文",
        "chat.suggested.summarize": "总结我的知识库中最重要的概念",
        "chat.suggested.connections": "有哪些页面之间可能存在关联但没有链接？",
        "chat.suggested.gaps": "知识库中有哪些盲区需要补充？",
        "chat.suggested.compare": "对比不同概念的异同",
        "chat.suggested.whatContent": "知识库中有哪些内容？",
        "chat.suggested.organize": "帮我整理知识结构",
        "chat.suggested.recommend": "推荐可以添加的新页面",
        "chat.suggested.explain": "解释这些概念之间的关系",
        
        // MARK: - LLM Settings
        "llm.status": "状态",
        "llm.enableAssistant": "启用 LLM 助手",
        "llm.provider": "服务商",
        "llm.customAPI": "自定义 API",
        "llm.configuration": "配置",
        "llm.apiAddress": "API 地址",
        "llm.model": "模型",
        "llm.validation": "验证",
        "llm.testing": "测试中...",
        "llm.testConnection": "测试连接",
        "llm.connectionSuccess": "连接成功！API Key 有效",
        "llm.validationFailed": "验证失败",
        "llm.chatHistory": "对话记录",
        "llm.messages": "条",
        "llm.clearHistory": "清空对话记录",
        "llm.chatSection": "对话",
        "llm.info": "说明",
        "llm.info.localKey": "API Key 仅存储在本地设备",
        "llm.info.contextSent": "对话时会发送知识库内容作为上下文",
        "llm.info.openAICompatible": "支持所有 OpenAI 兼容 API",
        "llm.info.smartIngest": "智能导入使用 LLM 编译原始资料",
        
        // MARK: - iCloud Sync
        "icloud.syncStatus": "iCloud 同步状态",
        "icloud.lastSync": "上次同步",
        "icloud.syncActions": "同步操作",
        "icloud.pushToCloud": "上传到 iCloud",
        "icloud.pullFromCloud": "从 iCloud 下载",
        "icloud.bidirectionalSync": "双向同步",
        "icloud.syncSettings": "同步设置",
        "icloud.autoSync": "自动同步",
        "icloud.conflictPolicy": "冲突解决策略",
        "icloud.merge": "合并（推荐）",
        "icloud.keepLocal": "保留本地",
        "icloud.keepRemote": "保留远程",
        "icloud.aboutSync": "关于 iCloud 同步",
        "icloud.info1": "数据通过 iCloud 私有数据库存储",
        "icloud.info2": "仅限同一 Apple ID 的设备间同步",
        "icloud.info3": "冲突时默认合并两边数据",
        "icloud.info4": "页面以更新时间为准，保留较新版本",
        "icloud.clearCloudData": "清除 iCloud 数据",
        "icloud.syncError": "同步错误",
        "icloud.conflictDetected": "冲突检测",
        "icloud.conflictMessage": "本地与远程数据存在冲突，请选择解决方式。",
        "icloud.notAvailable": "iCloud 不可用，请确认已登录 iCloud 账户",
        "icloud.cloudKitError": "CloudKit 错误",
        "icloud.encodingFailed": "数据编码失败",
        "icloud.decodingFailed": "数据解码失败",
        "icloud.conflictFailed": "冲突解决失败",
        "icloud.idle": "未同步",
        "icloud.syncing": "同步中...",
        "icloud.synced": "已同步",
        "icloud.syncFailed": "同步失败",
        
        // MARK: - PDF
        "pdf.documents": "PDF 文档",
        "pdf.library": "PDF 文档库",
        "pdf.libraryDesc": "添加 PDF 文档，阅读并高亮标注，提取内容到知识库",
        "pdf.addPDF": "添加 PDF",
        "pdf.delete": "删除",
        "pdf.ingest": "导入",
        "pdf.pages": "页",
        "pdf.highlights": "标注",
        "pdf.cannotLoad": "无法加载 PDF",
        "pdf.done": "完成",
        "pdf.annotateSelected": "标注选中文字",
        "pdf.addNote": "添加备注...",
        "pdf.saveAnnotation": "保存标注",
        "pdf.targetPage": "目标页面",
        "pdf.pageTitle": "页面标题",
        "pdf.pageType": "页面类型",
        "pdf.extractionMethod": "提取方式",
        "pdf.fullText": "全文",
        "pdf.pageRange": "指定页范围",
        "pdf.highlightsOnly": "仅标注内容",
        "pdf.fromPage": "从第",
        "pdf.toPage": "页到第",
        "pdf.page": "页",
        "pdf.extractionRange": "提取范围",
        "pdf.noHighlights": "暂无标注内容，请先在阅读时添加高亮标注",
        "pdf.contentPreview": "内容预览",
        "pdf.ingestToWiki": "导入到知识库",
        "pdf.cannotLoadPDF": "无法加载 PDF",
        
        // MARK: - OCR
        "ocr.title": "OCR 文字识别",
        "ocr.selectImage": "选择图片进行文字识别",
        "ocr.fromAlbum": "从相册选择",
        "ocr.recognize": "识别文字",
        "ocr.result": "识别结果",
        "ocr.copy": "复制",
        "ocr.charCount": "字数",
        "ocr.saveToWiki": "保存到知识库",
        "ocr.pageTitle": "页面标题",
        "ocr.pageType": "页面类型",
        "ocr.cancel": "取消",
        "ocr.recognizeFailed": "识别失败",
        
        // MARK: - Editor
        "editor.pageTitle": "页面标题",
        "editor.addTag": "添加标签",
        "editor.enterTag": "输入标签",
        "editor.addAlias": "添加别名",
        "editor.enterAlias": "输入别名",
        "editor.bold": "粗体",
        "editor.italic": "斜体",
        "editor.code": "代码",
        "editor.link": "链接",
        "editor.list": "列表",
        "editor.quote": "引用",
        "editor.table": "表格",
        "editor.divider": "分割线",
        "editor.wikiLink": "Wiki链接",
        "editor.insertWikiLink": "插入 Wiki 链接",
        "editor.searchPages": "搜索页面...",
        "editor.cancel": "取消",
        "editor.bidirectionalLinks": "支持 [[双向链接]] 语法",
        
        // MARK: - Create Page
        "create.title": "创建页面",
        "create.basicInfo": "基本信息",
        "create.tagsPlaceholder": "标签（逗号分隔）",
        "create.content": "内容",
        "create.quickTemplates": "快速模板",
        "create.entityTemplate": "实体模板",
        "create.conceptTemplate": "概念模板",
        "create.comparisonTemplate": "对比模板",
        "create.cancel": "取消",
        "create.create": "创建",
        "create.overview": "概述",
        "create.coreContributions": "核心贡献",
        "create.keyIdeas": "关键理念",
        "create.relatedLinks": "相关链接",
        "create.definition": "定义",
        "create.corePoints": "核心要点",
        "create.dimension": "维度",
        "create.description": "说明",
        "create.comparisonDimensions": "对比维度",
        "create.conclusion": "结论",
        
        // MARK: - Backlinks
        "backlinks.outgoing": "出链",
        "backlinks.noOutgoing": "无出链",
        "backlinks.backlinks": "反向链接",
        "backlinks.noBacklinks": "无反向链接",
        "backlinks.close": "关闭",
        
        // MARK: - Index
        "index.overview": "概览",
        "index.pages": "页面",
        "index.words": "字",
        
        // MARK: - Log
        "log.noLogs": "暂无操作日志",
        "log.noDetails": "暂无详细信息",
        "log.close": "关闭",
        
        // MARK: - Tag Cloud
        "tagcloud.selectTag": "选择标签查看相关页面",
        "tagcloud.pagesForTag": "标签 #%@ 的页面",
        
        // MARK: - Widget / Watch
        "widget.pages": "页面",
        "widget.words": "字",
        "widget.active": "活跃",
        "widget.stub": "占位",
        "widget.wordCount": "字数",
        "widget.recentUpdates": "最近更新",
        "widget.pageCount": "%d 页",

        // MARK: - Shortcuts
        "shortcuts.searchWiki": "搜索知识库",
        "shortcuts.searchWikiDesc": "在知识库中搜索内容",
        "shortcuts.searchKeyword": "搜索关键词",
        "shortcuts.noResults": "未找到与「%@」相关的内容",
        "shortcuts.foundResults": "找到 %d 个相关页面",
        "shortcuts.wikiStats": "知识库统计",
        "shortcuts.wikiStatsDesc": "获取知识库的统计信息",
        "shortcuts.createPage": "创建知识页面",
        "shortcuts.createPageDesc": "在知识库中创建一个新的知识页面",
        "shortcuts.pageTitle": "页面标题",
        "shortcuts.pageContent": "页面内容",
        "shortcuts.createdPage": "已创建页面「%@」",
        "shortcuts.statsFormat": "知识库统计：总页面 %d，总字数 %d，实体 %d，概念 %d，占位 %d",
        "shortcuts.stats": "统计",
        "shortcuts.search": "搜索",
        
        // MARK: - Lint Messages
        "lint.orphanPage": "孤立页面: 「%@」没有任何反向链接",
        "lint.orphanSuggestion": "考虑从相关页面添加 [[%@]] 链接",
        "lint.brokenLink": "断链: 「%@」引用了不存在的页面 [[%@]]",
        "lint.brokenLinkSuggestion": "创建页面「%@」或修复链接",
        "lint.stubContent": "占位内容: 「%@」内容少于100字",
        "lint.stubSuggestion": "补充更多内容或将状态改为「占位」",
        "lint.outdated": "可能过时: 「%@」已超过30天未更新",
        "lint.outdatedSuggestion": "检查内容是否需要更新",
        
        // MARK: - Log Actions
        "logAction.create": "创建",
        "logAction.update": "更新",
        "logAction.delete": "删除",
        "logAction.lint": "Lint",
        "logAction.ingest": "导入",
        "logAction.smartIngest": "智能导入",
        "logAction.importPDF": "导入PDF",
        "logAction.importPDFFailed": "导入PDF失败",
        "logAction.deletePDF": "删除PDF",
        "logAction.ingestPDF": "导入PDF",
        "logAction.highlight": "高亮标注",
        "logAction.ocrRecognize": "OCR识别",
        "logAction.undo": "撤销操作",
        "logAction.redo": "重做操作",
        "logAction.healthCheck": "健康检查",
        "logAction.lintIssuesFound": "发现 %d 个问题",
        
        // MARK: - Export
        "export.header": "知识库导出",
        "export.exportTime": "导出时间",
        "export.totalPages": "总页面",
        "export.type": "类型",
        "export.status": "状态",
        "export.confidence": "可信度",
        "export.tags": "标签",
        "export.aliases": "别名",
        "export.created": "创建",
        "export.updated": "更新",
        "export.importedPage": "导入页面",
        "export.imported": "导入",
        
        // MARK: - Templates
        "template.overview": "概述",
        "template.coreContributions": "核心贡献",
        "template.keyIdeas": "关键理念",
        "template.relatedLinks": "相关链接",
        "template.definition": "定义",
        "template.corePoints": "核心要点",
        "template.dimension": "维度",
        "template.description": "说明",
        "template.comparisonDimensions": "对比维度",
        "template.conclusion": "结论",
        
        // MARK: - Collaboration
        "collab.title": "实时协作",
        "collab.subtitle": "通过本地网络与他人实时协作编辑知识库",
        "collab.role.owner": "主持人",
        "collab.role.editor": "编辑者",
        "collab.role.viewer": "查看者",
        "collab.status.ready": "就绪",
        "collab.status.hosting": "正在主持协作",
        "collab.status.searching": "正在搜索附近的协作房间...",
        "collab.status.joining": "正在加入...",
        "collab.status.connected": "已连接",
        "collab.status.connecting": "连接中...",
        "collab.status.disconnected": "已断开",
        "collab.status.pageReceived": "收到页面同步",
        "collab.status.simulatorNotSupported": "模拟器不支持本地协作",
        "collab.status.advertiseError": "广播失败",
        "collab.status.browseError": "搜索失败",
        "collab.simulatorWarning": "MultipeerConnectivity 在模拟器上不可用，请在真机上测试协作功能。",
        "collab.defaultRoom": "知识库协作房间",
        "collab.username": "用户名",
        "collab.usernamePlaceholder": "输入你的名字",
        "collab.hostSession": "主持协作",
        "collab.joinSession": "加入协作",
        "collab.stopSearching": "停止搜索",
        "collab.nearbyRooms": "附近的协作房间",
        "collab.searching": "正在搜索...",
        "collab.hostedBy": "主持人:",
        "collab.leaveSession": "离开协作",
        "collab.connectedUsers": "已连接的用户",
        "collab.recentEdits": "最近的编辑",
        "collab.noEdits": "暂无编辑记录",
        "collab.hostSetup": "设置协作房间",
        "collab.roomName": "房间名称",
        "collab.roomNamePlaceholder": "输入房间名称",
        "collab.howItWorks": "工作原理",
        "collab.info.local": "通过本地 Wi-Fi / 蓝牙直连",
        "collab.info.encrypted": "端到端加密传输",
        "collab.info.maxPeers": "最多支持 8 位协作者",
        "collab.startHosting": "开始主持",
        
        // MARK: - Graph 3D
        "graph3d.title": "3D 图谱",
        "graph3d.viewPage": "查看页面",
        
        // MARK: - Speech / Voice Note
        "speech.title": "语音笔记",
        "speech.subtitle": "语音转文字，快速记录灵感与知识",
        "speech.language": "识别语言",
        "speech.status.ready": "就绪",
        "speech.status.denied": "麦克风权限被拒绝",
        "speech.status.restricted": "语音识别受限",
        "speech.status.notDetermined": "等待授权",
        "speech.status.unknown": "未知状态",
        "speech.status.recording": "正在录音...",
        "speech.status.complete": "转录完成",
        "speech.status.error": "识别错误",
        "speech.status.audioError": "音频引擎错误",
        "speech.status.localeNotSupported": "不支持该语言",
        "speech.status.simulatorNotSupported": "模拟器不支持语音录入，请在真机上测试",
        "speech.needPermission": "需要麦克风权限才能录音",
        "speech.requestPermission": "请求权限",
        "speech.tapToRecord": "点击开始录音",
        "speech.tapToStop": "点击停止录音",
        "speech.audioLevel": "音频电平",
        "speech.result": "转录结果",
        "speech.characters": "字符",
        "speech.saveToWiki": "保存到知识库",
        "speech.history": "历史记录",
        "speech.saveTitle": "保存语音笔记",
        "speech.noteTitle": "笔记标题",
        "speech.noteTitlePlaceholder": "输入笔记标题",
        "speech.voiceNote": "语音笔记",
        "speech.voiceTag": "语音",
        "speech.error.localeNotSupported": "不支持该语言",
        "speech.error.notAuthorized": "未授权",
        "speech.error.audioEngine": "音频引擎错误",
        
        // MARK: - Spatial (Vision Pro)
        "spatial.title": "空间计算",
        "spatial.subtitle": "在 Vision Pro 中以沉浸式 3D 方式浏览知识图谱",
        "spatial.features": "空间计算功能",
        "spatial.feature.3dGraph": "3D 知识图谱",
        "spatial.feature.3dGraph.desc": "在空间中自由浏览和操作知识节点",
        "spatial.feature.gesture": "手势交互",
        "spatial.feature.gesture.desc": "捏合、拖拽、旋转操作知识节点",
        "spatial.feature.gaze": "眼动追踪",
        "spatial.feature.gaze.desc": "注视即选中，自然交互",
        "spatial.feature.spatialAudio": "空间音频",
        "spatial.feature.spatialAudio.desc": "节点关联音频反馈，沉浸式体验",
        "spatial.requirement": "完整体验需要 Apple Vision Pro 设备。当前显示为 iOS 预览模式。",
        
        // MARK: - On-Device LLM
        "ondevice.title": "端侧 LLM",
        "ondevice.subtitle": "在设备本地运行 LLM，无需网络，完全私密",
        "ondevice.available": "端侧推理可用",
        "ondevice.unavailable": "端侧推理不可用",
        "ondevice.requiresIOS17": "需要 iOS 17.0 或更高版本",
        "ondevice.supportsFoundation": "支持 Apple Foundation Models",
        "ondevice.supportsCoreML": "支持 Core ML 模型推理",
        "ondevice.models": "可用模型",
        "ondevice.noModels": "没有可用的本地模型。请导入 .mlmodelc 模型文件。",
        "ondevice.system": "系统",
        "ondevice.local": "本地",
        "ondevice.modelLoaded": "模型已加载",
        "ondevice.unload": "卸载",
        "ondevice.loadModel": "加载模型",
        "ondevice.importModel": "导入模型",
        "ondevice.appleIntelligence": "Apple Intelligence",
        "ondevice.test": "测试推理",
        "ondevice.testGeneration": "测试文本生成",
        "ondevice.inferenceSpeed": "推理速度",
        "ondevice.info": "说明",
        "ondevice.info.privacy": "所有推理在设备本地完成，数据不离开设备",
        "ondevice.info.offline": "无需网络连接，完全离线运行",
        "ondevice.info.ne": "利用 Neural Engine 加速推理",
        "ondevice.info.memory": "模型使用设备内存，大模型可能影响性能",
        "ondevice.testPrompt": "输入测试提示词",
        "ondevice.generating": "生成中...",
        "ondevice.generate": "生成",
        "ondevice.result": "生成结果",
        "ondevice.error.modelNotFound": "模型未找到",
        "ondevice.error.modelNotLoaded": "模型未加载",
        "ondevice.error.notSupported": "当前系统不支持",
        "ondevice.error.inferenceFailed": "推理失败",
        "ondevice.error.compilationFailed": "模型编译失败",
        "ondevice.chatContext": "你是知识库助手。基于以下知识库内容回答问题。",
        "ondevice.chatQuestion": "问题",
        
        // MARK: - Misc
        "misc.text": "文本",
        "misc.confirm": "确认",
        "misc.save": "保存",
        "misc.delete": "删除",
        "misc.edit": "编辑",
        "misc.close": "关闭",
        "misc.cancel": "取消",
        "misc.ok": "确定",
        "misc.error": "错误",
        "misc.success": "成功",
        "misc.loading": "加载中...",
        "misc.noData": "暂无数据",
        "misc.search": "搜索",
        
        // MARK: - Undo
        "undo.undo": "撤销",
        "undo.redo": "重做",
        "undo.unavailable": "无可撤销操作",
        "undo.redoUnavailable": "无可重做操作",
        
        // MARK: - Backup
        "backup.title": "备份与恢复",
        "backup.settings": "备份设置",
        "backup.autoBackup": "自动备份",
        "backup.lastBackup": "上次备份",
        "backup.actions": "操作",
        "backup.createNow": "立即创建备份",
        "backup.exportCurrent": "导出当前数据",
        "backup.history": "备份历史",
        "backup.noBackups": "暂无备份",
        "backup.noBackupsDesc": "创建备份以保护您的知识库数据",
        "backup.restoreTitle": "恢复备份",
        "backup.restoreMessage": "确定要从此备份恢复吗？当前数据将被替换，恢复前会自动创建安全备份。",
        "backup.restore": "恢复",
        "backup.pages": "页",
        "backup.words": "字",
        
        // MARK: - Deep Link
        "deeplink.pageNotFound": "未找到页面",
        "deeplink.openedPage": "已打开页面",
        
        // MARK: - Accessibility
        "a11y.words": "字",
        "a11y.links": "个链接",
        "a11y.tags": "标签",
        "a11y.tapToOpen": "轻点打开",
        "a11y.voiceOver": "VoiceOver",
        "a11y.reduceMotion": "减弱动态效果",
        "a11y.highContrast": "高对比度",
        
        // MARK: - Performance
        "perf.title": "性能监控",
        "perf.memory": "内存使用",
        "perf.pages": "页面数",
        "perf.words": "总字数",
        "perf.nodes": "图谱节点",
        "perf.edges": "图谱边",
        "perf.timing": "耗时分析",
        "perf.save": "保存",
        "perf.load": "加载",
        "perf.lint": "健康检查",
        "perf.graphLayout": "图谱布局",
        "perf.search": "搜索",
        "perf.lastUpdated": "最后更新",
        
        // MARK: - LLM Errors
        "llm.error.notConfigured": "LLM 未配置。请在设置中填写 API Key。",
        "llm.error.invalidURL": "API 地址无效",
        "llm.error.invalidResponse": "API 返回格式异常",
        "llm.error.unauthorized": "API Key 无效或已过期",
        "llm.error.rateLimited": "请求过于频繁，请稍后重试",
        "llm.error.httpError": "HTTP 错误",
        "llm.error.apiError": "API 错误",
        "llm.error.cancelled": "请求已取消",
        
        // MARK: - LLM System Prompt
        "llm.prompt.role": "你是知识库助手，基于 Karpathy LLM Wiki 方法论运行。",
        "llm.prompt.duty1": "1. 回答用户关于知识库内容的问题",
        "llm.prompt.duty2": "2. 帮助整理和编译知识",
        "llm.prompt.duty3": "3. 建议页面间的关联",
        "llm.prompt.duty4": "4. 发现知识盲区和矛盾",
        "llm.prompt.rule1": "- 基于知识库事实回答，引用相关页面用 [[页面标题]] 格式",
        "llm.prompt.rule2": "- 如果知识库中没有相关信息，明确说明",
        "llm.prompt.rule3": "- 回答使用中文",
        "llm.prompt.rule4": "- 保持简洁、准确、有条理",
        "llm.prompt.overview": "当前知识库概览：",
        "llm.prompt.totalPages": "- 总页面",
        "llm.prompt.entityCount": "实体",
        "llm.prompt.conceptCount": "概念",
        "llm.prompt.sourceCount": "来源",
        "llm.prompt.entityList": "实体列表：",
        "llm.prompt.conceptList": "概念列表：",
        "llm.prompt.sourceList": "来源列表：",
        "llm.prompt.recentUpdates": "最近更新：",
        "llm.prompt.relevantPages": "相关页面内容：",
        "llm.prompt.typeLabel": "类型",
        "llm.prompt.statusLabel": "状态",
        
        // MARK: - LLM Smart Ingest Prompt
        "llm.ingest.compileInstruction": "请将以下原始资料编译为结构化的 Wiki 页面内容。",
        "llm.ingest.compileRules": "编译规则：",
        "llm.ingest.rule1": "1. 使用 Markdown 格式",
        "llm.ingest.rule2": "2. 用 [[页面标题]] 语法链接到已有的 Wiki 页面（如果内容提及了相关概念）",
        "llm.ingest.rule3": "3. 提取关键概念作为标签",
        "llm.ingest.rule4": "4. 组织内容为清晰的章节结构",
        "llm.ingest.rule5": "5. 如果内容涉及对比或关联，使用表格呈现",
        "llm.ingest.rule6": "6. 保持事实准确，不添加原文没有的信息",
        "llm.ingest.existingPages": "已有 Wiki 页面（请优先链接这些）",
        "llm.ingest.rawTitle": "原始资料标题",
        "llm.ingest.rawContent": "原始资料内容：",
        "llm.ingest.jsonFormat": "请以 JSON 格式返回编译结果：",
        "llm.ingest.jsonCompiledContent": "编译后的 Markdown 内容",
        "llm.ingest.jsonSuggestedTags": "标签",
        "llm.ingest.jsonSummary": "一段简短摘要",
        "llm.ingest.systemPrompt": "你是知识库的编译器。将原始资料编译为结构化的知识库内容。只返回 JSON，不要包含其他文本。",
        
        // MARK: - LLM Provider Display Name
        "llm.provider.custom": "自定义 API",
        
        // MARK: - OCR Errors
        "ocr.error.invalidImage": "无效图片",
        "ocr.error.noResults": "未识别到文字",
        "ocr.error.cameraUnavailable": "相机不可用",
        
        // MARK: - iCloud Sync Errors
        "icloud.error.notAvailable": "iCloud 不可用，请确认已登录 iCloud 账户",
        "icloud.error.cloudKit": "CloudKit 错误",
        "icloud.error.encoding": "数据编码失败",
        "icloud.error.decoding": "数据解码失败",
        "icloud.error.conflictResolution": "冲突解决失败",
        
        // MARK: - Sync Status Labels
        "sync.idle": "未同步",
        "sync.syncing": "同步中...",
        "sync.synced": "已同步",
        "sync.error": "同步失败",
        
        // MARK: - Speech Language Names
        "speech.lang.zhHans": "中文（简体）",
        "speech.lang.zhHant": "中文（繁体）",
        
        // MARK: - On-Device LLM Smart Ingest Prompt
        "ondevice.ingest.compileToWiki": "将以下内容编译为结构化 Wiki 页面。已有页面",
        "ondevice.ingest.title": "标题",
        "ondevice.ingest.content": "内容",
        "ondevice.ingest.linkAndFormat": "用 [[页面标题]] 链接已有页面。输出 Markdown 格式。",
        
        // MARK: - Splash
        "splash.quote": "人类的工作是策展来源、引导分析、问好问题。\nLLM 的工作是除此之外的一切。",
        "splash.enter": "进入知识宇宙",
        
        // MARK: - Backup Log
        "backup.log.createFailed": "备份失败: %@",
        "backup.log.restoreFailed": "恢复备份失败: %@",
        "backup.log.crashRecovery": "检测到崩溃恢复 - 发现脏标记",
        "backup.log.saveIndexFailed": "保存备份索引失败: %@",
        
        // MARK: - Deep Link Log
        "deepLink.log.indexingFailed": "Spotlight 索引失败: %@",
        
        // MARK: - Log Service
        "log.error.saveFailed": "保存日志失败: %@",
        
        // MARK: - PageStore
        "pageStore.error.saveFailed": "保存页面失败: %@",
        
        // MARK: - Performance Summary
        "perf.summary.title": "📊 性能摘要",
        "perf.summary.pages": "页面",
        "perf.summary.words": "字",
        "perf.summary.graph": "图谱",
        "perf.summary.nodes": "节点",
        "perf.summary.edges": "边",
        "perf.summary.memory": "内存",
        "perf.summary.save": "保存",
        "perf.summary.load": "加载",
        "perf.summary.lint": "健康检查",
        "perf.summary.graphLayout": "图谱布局",
        "perf.summary.search": "搜索",
        
        // MARK: - PDF Page Separator
        "pdf.pageSeparator": "\n\n--- 第 %@ 页 ---\n\n",
        
        // MARK: - Speech Language Names (Additional)
        "speech.lang.enUS": "英语（美国）",
        "speech.lang.enGB": "英语（英国）",
        "speech.lang.jaJP": "日语",
        "speech.lang.koKR": "韩语",
        "speech.lang.frFR": "法语",
        "speech.lang.deDE": "德语",
        "speech.lang.esES": "西班牙语",
        "speech.lang.ptBR": "葡萄牙语（巴西）",
        
        // MARK: - LLM Provider Display Names
        "llm.provider.openAI": "OpenAI",
        "llm.provider.deepSeek": "DeepSeek",
        
        // MARK: - On-Device Model Name
        "ondevice.model.bundled": "知识库 LLM（内置）",
        
        // MARK: - Theme Settings
        "settings.theme.system": "跟随系统",
        "settings.theme.light": "浅色模式",
        "settings.theme.dark": "深色模式",

        // MARK: - Language Settings
        "settings.language.system": "跟随系统",
        "settings.appearanceMode": "外观模式",
        "settings.language": "语言",

        "settings.section.danger": "危险操作",

        "settings.onDeviceLLM": "端侧 LLM",
        "settings.exportMarkdown": "导出为 Markdown",
        "settings.spatialComputingHint": "在 Apple Vision Pro 中沉浸式浏览",
        "settings.totalPages": "总页面",
        "settings.stubPagesHint": "被链接但内容为空的页面，建议补充内容",
        "settings.tagManagerHint": "浏览所有标签及关联页面",
        "settings.masterIndex": "总索引",
        "settings.aboutAppDesc": "基于 Karpathy LLM Wiki 方法论的 iOS 知识管理应用",
        "settings.confirmReset": "确认重置",
        "settings.cancel": "取消",
        "settings.settings": "设置",

        "ingest.hero.subtitle": "将原始资料编译到 Wiki，自动提取关键信息并建立交叉引用",
        "ingest.ocrScan": "OCR 扫描",
        "ingest.ocrScanHint": "从图片中识别文字",
        "ingest.tip5": "更新索引和操作日志",

        "tooltip.tag.desc": "为页面添加标签，方便分类检索和批量管理",

        "misc.gotIt": "知道了",

        // MARK: - Page Detail
        "page.empty": "这个页面还没有内容",
        "page.emptyHint": "点击右上角 ✏️ 开始编辑，使用 [[页面名]] 建立关联",
        "page.pin": "固定页面",
        "page.unpin": "取消固定",
        "page.backlinks": "反向链接",
        "page.backlinksCount": "%d 个页面",
        "page.edit": "编辑页面",
        "page.doneEditing": "完成编辑",
        "page.type": "页面类型",
        "page.icon": "图标",
        "page.tags": "标签",
        "page.alias": "别名",
        "page.confidence": "可信度",
        "page.status": "状态",
        "page.created": "创建时间",
        "page.updated": "更新时间",
        "page.wordCount": "%d 字",
        "page.outLinks": "出链 (%d)",
        "page.backLinks": "反向链接 (%d)",
        "page.noOutLinks": "无出链",
        "page.noBackLinks": "无反向链接",
        "page.searchPlaceholder": "搜索页面...",
        "page.close": "关闭",

        // MARK: - Create Page
        "create.pageTitle": "页面标题",
        "create.selectType": "选择类型",
        "create.selectIcon": "选择图标",
        "create.contentPlaceholder": "输入内容...",
        "create.creating": "创建中...",
        "create.selectTypeHint": "为新页面选择一个合适的类型",

        // MARK: - iCloud Sync
        "icloud.title": "iCloud 同步",
        "icloud.status": "iCloud 同步状态",
        "icloud.upload": "上传到 iCloud",
        "icloud.download": "从 iCloud 下载",
        "icloud.bidirectional": "双向同步",
        "icloud.notConfigured": "未配置",
        "icloud.enableSync": "启用 iCloud 同步",
        "icloud.disableSync": "停用 iCloud 同步",
        "icloud.syncNow": "立即同步",
        "icloud.neverSynced": "从未同步",

        // MARK: - OCR Scan
        "ocr.scan": "扫描图片",
        "ocr.confirm": "确定",
        "ocr.scanFailed": "文字识别失败",
        "ocr.noTextFound": "未在图片中找到文字",
        "ocr.usePhoto": "使用照片",
        "ocr.useCamera": "拍照",
        "ocr.processing": "正在识别文字...",

        // MARK: - LLM Settings
        "llm.title": "LLM 设置",
        "llm.enable": "启用 LLM 助手",
        "llm.apiKey": "API Key",
        "llm.apiKeyPlaceholder": "输入 API Key",
        "llm.apiAddressPlaceholder": "https://api.openai.com",
        "llm.modelPlaceholder": "gpt-4o-mini",
        "llm.save": "保存",
        "llm.saved": "已保存",
        "llm.notConfigured": "未配置",
        "llm.configured": "已配置",
        "llm.notEnabled": "未启用",
        "llm.enabled": "已启用",

        // MARK: - Tag Cloud
        "tag.title": "标签管理",
        "tag.noTags": "还没有任何标签",
        "tag.noTagsHint": "在编辑页面时添加标签，或导入内容时指定标签",
        "tag.rename": "重命名",
        "tag.delete": "删除",
        "tag.tagPages": "标签 #%@ 的页面",
        "tag.allPages": "所有页面",
        "tag.manage": "管理",

        // MARK: - PDF Reader
        "pdf.title": "PDF 文档",
        "pdf.libraryHint": "添加 PDF 文档，阅读并高亮标注，提取内容到知识库",
        "pdf.add": "添加 PDF",
        "pdf.addDocument": "添加文档",
        "pdf.import": "导入",
        "pdf.cancel": "取消",
        "pdf.noDocuments": "还没有 PDF 文档",
        "pdf.noDocumentsHint": "点击上方按钮添加 PDF 文件",

        // MARK: - Chat
        "chat.notConfigured": "请先配置 LLM API Key",
        "chat.error": "错误",
        "chat.ok": "确定",
        "chat.expanding": "展开全文",
        "chat.collapse": "收起",
        "chat.sending": "发送中...",

        // MARK: - Sidebar
        "sidebar.masterIndex": "总索引",
        "sidebar.backToMain": "返回",

        // MARK: - Search
        "search.title": "搜索",
        "search.recentUpdates": "最近更新",
        "search.recentCreated": "最近创建",
        "search.byTitle": "标题",
        "search.byType": "类型",

        // MARK: - Index
        "index.entities": "实体",
        "index.concepts": "概念",
        "index.sources": "来源",
        "index.comparisons": "对比",
        "index.maps": "地图",
        "index.raw": "原始",
        "index.total": "总计",
        "index.lastUpdated": "最后更新",
        "index.viewAll": "查看全部",

        // MARK: - Markdown Editor
        "editor.searchPage": "搜索页面...",
        "editor.tagPlaceholder": "输入标签",
        "editor.aliasPlaceholder": "输入别名",

        // MARK: - Lint
        "lint.title": "健康检查",
        "lint.running": "检查中...",
        "lint.noIssues": "知识库状态良好",
        "lint.noIssuesHint": "没有发现断链、孤立页面或矛盾内容",
        "lint.ok": "正常",

        // MARK: - Backlinks
        "backlinks.title": "反向链接",
        "backlinks.noOutLinks": "无出链",
        "backlinks.noBackLinks": "无反向链接",

        // MARK: - Graph

        // MARK: - Ingest View
        "ingest.smartIngestDone": "智能导入",
        "ingest.smartIngestDoneDesc": "LLM 编译完成，类型: %@",

        // MARK: - Loading
        "loading": "加载中...",

        // MARK: - Log
        "log.title": "操作日志",

        // MARK: - Widget & Watch
        "widget.title": "知识库",
        "widget.characters": "字",
        "widget.placeholder": "占位",

        // MARK: - Page Detail (Format & Accessibility)
        "page.statusFormat": "状态: %@",
        "page.confidenceFormat": "可信度: %@",
        "page.deletePageTitle": "删除「%@」",
        "page.typeAccessibility": "页面类型: %@",
        "page.statusAccessibility": "状态: %@",
        "page.confidenceAccessibility": "可信度: %@",
        "page.titleAccessibility": "页面标题: %@",
        "page.aliasAccessibility": "别名: %@",
        "page.tagsAccessibility": "标签: %@",
        "page.createdFormat": "创建: %@",
        "page.updatedFormat": "更新: %@",
        "page.outLinksCount": "%d 出链",
        "page.metaAccessibility": "元信息，创建于 %@，%@ 字，%d 个出站链接",
        "page.doubleTapToNavigate": "双击跳转到该页面",
        "page.confirmDelete": "确认删除",
        "page.deleteMessage": "此操作不可恢复，页面及所有引用将被删除。",

        // MARK: - iCloud Sync (Additional)
        "icloud.lastSyncFormat": "上次同步：%@",
        "icloud.pullWillOverwrite": "从 iCloud 下载将覆盖本地数据",
        "icloud.pullOverwriteMessage": "所有本地页面将被远程数据替换，此操作不可撤销。",
        "icloud.autoSyncFailed": "自动同步失败",

        // MARK: - Sidebar (Additional)
        "sidebar.frequentKnowledge": "常用知识",
        "sidebar.linkUnit": "链",

        // MARK: - OCR (Additional)
        "ocr.scanTag": "扫描",
        "ocr.addTag": "添加",
        "ocr.changeIcon": "更换",
        "ocr.customIcon": "自定义",
        "ocr.charCountFormat": "字数：%d",

        // MARK: - PDF (Additional)
        "pdf.noteLabel": "备注：",
        "pdf.ingestModeFormat": "模式: %@",
        "pdf.pageCountFormat": "%d 页",
        "pdf.highlightCountFormat": "%d 标注",
        "pdf.createdPage": "创建页面 %@",
        "pdf.pageNumber": "第 %d 页",

        // MARK: - Tag (Additional)
        "tag.renameTag": "重命名标签",
        "tag.newName": "新名称",
        "tag.renameMessage": "将 #%@ 重命名为新名称",
        "tag.deleteTag": "删除标签",
        "tag.deleteMessage": "将从 %d 个页面中移除 #%@，此操作不可撤销",

        // MARK: - Search (Additional)
        "search.noResultsHint": "尝试更换关键词或调整筛选条件",
        "search.pagesCount": "%d 个页面",
        "search.search": "搜索",

        // MARK: - Index (Additional)
        "index.entityCount": "实体 (%d)",
        "index.conceptCount": "概念 (%d)",
        "index.sourceCount": "来源 (%d)",
        "index.comparisonCount": "对比 (%d)",
        "index.wordCount": "%d 字",

        // MARK: - Icon Picker
        "iconPicker.common": "常用",
        "iconPicker.academic": "学术",
        "iconPicker.nature": "自然",
        "iconPicker.transport": "交通",
        "iconPicker.symbols": "符号",
        "iconPicker.selectIcon": "选择图标",
        "iconPicker.customSelected": "已选择自定义图标",
        "iconPicker.useDefault": "使用默认图标",
        "iconPicker.reset": "重置",
        "iconPicker.allIcons": "全部图标",

        // MARK: - Backlinks (Additional)
        "backlinks.outgoingCount": "出链 (%d)",
        "backlinks.backlinksCount": "反向链接 (%d)",

        // MARK: - Splash (Additional)
        "splash.appName": "知识库",

        // MARK: - Collaboration
        "collab.room": "知识库 Room",
        "collab.joining": "正在加入房间...",
    ]

    
    private static let enStrings: [String: String] = [
        // MARK: - Tab Bar
        "tab.wiki": "Wiki",
        "tab.graph": "Graph",
        "tab.search": "Search",
        "tab.ingest": "Ingest",
        "tab.pdf": "PDF",
        "tab.voice": "Voice",
        "tab.chat": "AI",
        "tab.collab": "Collab",
        "tab.settings": "Settings",
        
        // MARK: - Page Types
        "type.entity": "Entity",
        "type.concept": "Concept",
        "type.source": "Source",
        "type.comparison": "Comparison",
        "type.map": "Map",
        "type.raw": "Raw",
        
        // MARK: - Page Status
        "status.active": "Active",
        "status.stub": "Stub",
        "status.needsUpdate": "Needs Update",
        "status.deprecated": "Deprecated",
        
        // MARK: - Confidence
        "confidence.high": "High",
        "confidence.medium": "Medium",
        "confidence.low": "Low",
        
        // MARK: - Welcome Page
        "welcome.subtitle": "iOS Knowledge Management based on Karpathy LLM Wiki",
        "stat.totalPages": "Pages",
        "stat.entities": "Entities",
        "stat.concepts": "Concepts",
        "stat.sources": "Sources",
        "quickStart": "Quick Start",
        "action.createPage": "Create Page",
        "action.createPage.subtitle": "Create a new Wiki page",
        "action.ingestKnowledge": "Ingest Knowledge",
        "action.ingestKnowledge.subtitle": "Compile raw material into Wiki",
        "action.browseGraph": "Browse Graph",
        "action.browseGraph.subtitle": "Visualize knowledge connections",
        "action.healthCheck": "Health Check",
        "action.healthCheck.subtitle": "Detect broken links, orphan pages, conflicts",
        "recentUpdates": "Recent Updates",
        "pinned": "Pinned",
        
        // MARK: - Sidebar
        "sidebar.navigation": "Navigation",
        "sidebar.fullIndex": "Full Index",
        "sidebar.operationLog": "Operation Log",
        "sidebar.tags": "Tags",
        "sidebar.tools": "Tools",
        "sidebar.healthCheck": "Health Check",
        
        // MARK: - Page Detail
        "detail.pageType": "Page Type",
        "detail.status": "Status",
        "detail.confidence": "Confidence",
        "detail.deletePage": "Delete Page",
        "detail.confirmDelete": "Confirm Delete",
        "detail.deleteMessage": "This action cannot be undone. The page and all references will be deleted.",
        "detail.cancel": "Cancel",
        "detail.backlinks": "Backlinks",
        "detail.noBacklinks": "No backlinks yet",
        "detail.created": "Created",
        "detail.updated": "Updated",
        "detail.words": "words",
        "detail.outLinks": "out-links",
        
        // MARK: - Search
        "search.placeholder": "Search pages, tags, content...",
        "search.all": "All",
        "search.noResults": "No matching pages found",
        "search.pages": "pages",
        "search.sort.recentlyUpdated": "Recently Updated",
        "search.sort.recentlyCreated": "Recently Created",
        "search.sort.title": "Title",
        "search.sort.type": "Type",
        
        // MARK: - Ingest
        "ingest.title": "Knowledge Ingest",
        "ingest.subtitle": "Compile raw material into Wiki, auto-extract key info and build cross-references",
        "ingest.titleLabel": "Title",
        "ingest.titlePlaceholder": "Enter page title",
        "ingest.typeLabel": "Type",
        "ingest.tagsLabel": "Tags (comma separated)",
        "ingest.tagsPlaceholder": "AI, knowledge, LLM",
        "ingest.contentLabel": "Content",
        "ingest.smartIngest": "Smart Ingest (LLM)",
        "ingest.smartIngest.description": "LLM will auto-compile raw material: extract key info, build cross-references, suggest tags and type",
        "ingest.compiling": "Compiling...",
        "ingest.ingestButton": "Ingest to Wiki",
        "ingest.success": "Ingest successful! Knowledge compiled to Wiki",
        "ingest.flow": "Ingest Flow",
        "ingest.step1": "Paste raw material into content area",
        "ingest.step2": "Select page type and tags",
        "ingest.step3": "Click import, system auto-compiles",
        "ingest.step4": "Auto-detect cross-references with existing pages",
        "ingest.step5": "Update index and operation log",
        "ingest.llmPreview": "LLM Compile Preview",
        "ingest.confirmIngest": "Confirm Import",
        "ingest.discard": "Discard",
        "ingest.suggestedRelations": "Suggested Relations",
        "ingest.error": "Error",
        "ingest.ok": "OK",
        
        // MARK: - Lint
        "lint.runCheck": "Run Health Check",
        "lint.checking": "Checking...",
        "lint.foundIssues": "Found %d issues",
        "lint.healthy": "Wiki is healthy",
        "lint.healthyDesc": "No broken links, orphan pages, or conflicts found",
        "lint.errors": "Errors",
        "lint.warnings": "Warnings",
        "lint.tips": "Tips",
        "lint.goToPage": "Go to page →",
        
        // MARK: - Graph
        "graph.title": "Knowledge Graph",
        "graph.emptyDesc": "Page connections will be visualized here",
        "graph.all": "All",
        "graph.nodesConnections": "%d nodes · %d connections",
        "graph.linkHint": "Use [[Page Name]] in the editor to create links",
        "graph.nodes": "nodes",
        "graph.connections": "connections",
        
        // MARK: - Settings
        "settings.appearance": "Appearance",
        "settings.darkMode": "Dark Mode",
        "settings.accentColor": "Accent Color",
        "settings.wikiStats": "Wiki Statistics",
        "settings.totalWords": "Total Words",
        "settings.stubPages": "Stub Pages",
        "settings.operationLog": "Operation Log",
        "settings.tools": "Tools",
        "settings.iCloudSync": "iCloud Sync",
        "settings.unavailable": "Unavailable",
        "settings.llmAssistant": "LLM Assistant",
        "settings.notConfigured": "Not Configured",
        "settings.healthCheck": "Health Check",
        "settings.fullIndex": "Full Index",
        "settings.importClipboard": "Import from Clipboard",
        "settings.about": "About",
        "settings.aboutDesc": "iOS knowledge management app based on Karpathy LLM Wiki methodology",
        "settings.coreConcept": "Core concept: compile, don't retrieve. Let knowledge accumulate persistently.",
        "settings.features": "Features",
        "settings.feature.bidirectionalLinks": "Bidirectional links [[wikilink]]",
        "settings.feature.graphViz": "Knowledge graph visualization",
        "settings.feature.ingest": "Knowledge import & compilation",
        "settings.feature.llmAssistant": "LLM AI Assistant + Smart Import",
        "settings.feature.lint": "Lint health check",
        "settings.feature.fullTextSearch": "Full-text search & filtering",
        "settings.feature.darkTheme": "Dark theme",
        "settings.dangerZone": "Danger Zone",
        "settings.resetWiki": "Reset Wiki",
        "settings.resetAllData": "Reset All Data",
        "settings.resetWarning": "This will delete all pages and logs, restoring default content. Cannot be undone.",
        "settings.importComplete": "Import Complete",
        "settings.importedCount": "Successfully imported %d pages",
        "settings.gotIt": "Got it",
        
        // MARK: - Chat
        "chat.title": "AI Assistant",
        "chat.clearHistory": "Clear Chat",
        "chat.llmSettings": "LLM Settings",
        "chat.configureFirst": "Please configure LLM API Key first",
        "chat.welcomeTitle": "Knowledge Base AI Assistant",
        "chat.welcomeDesc": "Answer questions based on your wiki, discover connections, find gaps",
        "chat.inputPlaceholder": "Ask your wiki...",
        "chat.expandFull": "Expand full text",
        "chat.suggested.summarize": "Summarize the most important concepts in my wiki",
        "chat.suggested.connections": "Which pages might be related but not linked?",
        "chat.suggested.gaps": "What gaps exist in my wiki that need filling?",
        "chat.suggested.compare": "Compare similarities and differences between concepts",
        "chat.suggested.whatContent": "What content is in my wiki?",
        "chat.suggested.organize": "Help me organize the knowledge structure",
        "chat.suggested.recommend": "Recommend new pages to add",
        "chat.suggested.explain": "Explain the relationships between these concepts",
        
        // MARK: - LLM Settings
        "llm.status": "Status",
        "llm.enableAssistant": "Enable LLM Assistant",
        "llm.provider": "Provider",
        "llm.customAPI": "Custom API",
        "llm.configuration": "Configuration",
        "llm.apiAddress": "API URL",
        "llm.model": "Model",
        "llm.validation": "Validation",
        "llm.testing": "Testing...",
        "llm.testConnection": "Test Connection",
        "llm.connectionSuccess": "Connection successful! API Key is valid",
        "llm.validationFailed": "Validation failed",
        "llm.chatHistory": "Chat History",
        "llm.messages": "messages",
        "llm.clearHistory": "Clear Chat History",
        "llm.chatSection": "Chat",
        "llm.info": "Info",
        "llm.info.localKey": "API Key is stored locally on device only",
        "llm.info.contextSent": "Wiki content is sent as context during conversations",
        "llm.info.openAICompatible": "Supports all OpenAI-compatible APIs",
        "llm.info.smartIngest": "Smart import uses LLM to compile raw material",
        
        // MARK: - iCloud Sync
        "icloud.syncStatus": "iCloud Sync Status",
        "icloud.lastSync": "Last synced",
        "icloud.syncActions": "Sync Actions",
        "icloud.pushToCloud": "Upload to iCloud",
        "icloud.pullFromCloud": "Download from iCloud",
        "icloud.bidirectionalSync": "Bidirectional Sync",
        "icloud.syncSettings": "Sync Settings",
        "icloud.autoSync": "Auto Sync",
        "icloud.conflictPolicy": "Conflict Resolution Policy",
        "icloud.merge": "Merge (Recommended)",
        "icloud.keepLocal": "Keep Local",
        "icloud.keepRemote": "Keep Remote",
        "icloud.aboutSync": "About iCloud Sync",
        "icloud.info1": "Data is stored via iCloud private database",
        "icloud.info2": "Sync only between devices with the same Apple ID",
        "icloud.info3": "Defaults to merging data from both sides on conflict",
        "icloud.info4": "Pages use update time, keeping the newer version",
        "icloud.clearCloudData": "Clear iCloud Data",
        "icloud.syncError": "Sync Error",
        "icloud.conflictDetected": "Conflict Detected",
        "icloud.conflictMessage": "Local and remote data have conflicts. Please choose a resolution.",
        "icloud.notAvailable": "iCloud unavailable. Please sign in to your iCloud account.",
        "icloud.cloudKitError": "CloudKit error",
        "icloud.encodingFailed": "Data encoding failed",
        "icloud.decodingFailed": "Data decoding failed",
        "icloud.conflictFailed": "Conflict resolution failed",
        "icloud.idle": "Not synced",
        "icloud.syncing": "Syncing...",
        "icloud.synced": "Synced",
        "icloud.syncFailed": "Sync failed",
        
        // MARK: - PDF
        "pdf.documents": "PDF Documents",
        "pdf.library": "PDF Library",
        "pdf.libraryDesc": "Add PDF documents, read and highlight, extract content to wiki",
        "pdf.addPDF": "Add PDF",
        "pdf.delete": "Delete",
        "pdf.ingest": "Ingest",
        "pdf.pages": "pages",
        "pdf.highlights": "highlights",
        "pdf.cannotLoad": "Cannot load PDF",
        "pdf.done": "Done",
        "pdf.annotateSelected": "Annotate selected text",
        "pdf.addNote": "Add note...",
        "pdf.saveAnnotation": "Save Annotation",
        "pdf.targetPage": "Target Page",
        "pdf.pageTitle": "Page Title",
        "pdf.pageType": "Page Type",
        "pdf.extractionMethod": "Extraction Method",
        "pdf.fullText": "Full Text",
        "pdf.pageRange": "Page Range",
        "pdf.highlightsOnly": "Highlights Only",
        "pdf.fromPage": "From page",
        "pdf.toPage": "to page",
        "pdf.page": "page",
        "pdf.extractionRange": "Extraction Range",
        "pdf.noHighlights": "No highlights yet. Add highlights while reading first.",
        "pdf.contentPreview": "Content Preview",
        "pdf.ingestToWiki": "Ingest to Wiki",
        "pdf.cannotLoadPDF": "Cannot load PDF",
        
        // MARK: - OCR
        "ocr.title": "OCR Text Recognition",
        "ocr.selectImage": "Select an image for text recognition",
        "ocr.fromAlbum": "From Album",
        "ocr.recognize": "Recognize Text",
        "ocr.result": "Recognition Result",
        "ocr.copy": "Copy",
        "ocr.charCount": "Characters",
        "ocr.saveToWiki": "Save to Wiki",
        "ocr.pageTitle": "Page Title",
        "ocr.pageType": "Page Type",
        "ocr.cancel": "Cancel",
        "ocr.recognizeFailed": "Recognition failed",
        
        // MARK: - Editor
        "editor.pageTitle": "Page Title",
        "editor.addTag": "Add Tag",
        "editor.enterTag": "Enter tag",
        "editor.addAlias": "Add Alias",
        "editor.enterAlias": "Enter alias",
        "editor.bold": "Bold",
        "editor.italic": "Italic",
        "editor.code": "Code",
        "editor.link": "Link",
        "editor.list": "List",
        "editor.quote": "Quote",
        "editor.table": "Table",
        "editor.divider": "Divider",
        "editor.wikiLink": "WikiLink",
        "editor.insertWikiLink": "Insert Wiki Link",
        "editor.searchPages": "Search pages...",
        "editor.cancel": "Cancel",
        "editor.bidirectionalLinks": "Supports [[bidirectional links]] syntax",
        
        // MARK: - Create Page
        "create.title": "Create Page",
        "create.basicInfo": "Basic Info",
        "create.tagsPlaceholder": "Tags (comma separated)",
        "create.content": "Content",
        "create.quickTemplates": "Quick Templates",
        "create.entityTemplate": "Entity Template",
        "create.conceptTemplate": "Concept Template",
        "create.comparisonTemplate": "Comparison Template",
        "create.cancel": "Cancel",
        "create.create": "Create",
        "create.overview": "Overview",
        "create.coreContributions": "Core Contributions",
        "create.keyIdeas": "Key Ideas",
        "create.relatedLinks": "Related Links",
        "create.definition": "Definition",
        "create.corePoints": "Core Points",
        "create.dimension": "Dimension",
        "create.description": "Description",
        "create.comparisonDimensions": "Comparison Dimensions",
        "create.conclusion": "Conclusion",
        
        // MARK: - Backlinks
        "backlinks.outgoing": "Outgoing Links",
        "backlinks.noOutgoing": "No outgoing links",
        "backlinks.backlinks": "Backlinks",
        "backlinks.noBacklinks": "No backlinks",
        "backlinks.close": "Close",
        
        // MARK: - Index
        "index.overview": "Overview",
        "index.pages": "Pages",
        "index.words": "words",
        
        // MARK: - Log
        "log.noLogs": "No operation logs yet",
        "log.noDetails": "No details available",
        "log.close": "Close",
        
        // MARK: - Tag Cloud
        "tagcloud.selectTag": "Select a tag to view related pages",
        "tagcloud.pagesForTag": "Pages with tag #%@",
        
        // MARK: - Widget / Watch
        "widget.pages": "Pages",
        "widget.words": "Words",
        "widget.active": "Active",
        "widget.stub": "Stub",
        "widget.wordCount": "Word Count",
        "widget.recentUpdates": "Recent Updates",
        "widget.pageCount": "%d pages",
        
        // MARK: - Shortcuts
        "shortcuts.searchWiki": "Search Wiki",
        "shortcuts.searchWikiDesc": "Search content in Knowledge Base",
        "shortcuts.searchKeyword": "Search keyword",
        "shortcuts.noResults": "No results found for \"%@\"",
        "shortcuts.foundResults": "Found %d related pages",
        "shortcuts.wikiStats": "Wiki Stats",
        "shortcuts.wikiStatsDesc": "Get Knowledge Base statistics",
        "shortcuts.createPage": "Create Wiki Page",
        "shortcuts.createPageDesc": "Create a new page in Knowledge Base",
        "shortcuts.pageTitle": "Page Title",
        "shortcuts.pageContent": "Page Content",
        "shortcuts.createdPage": "Created page \"%@\"",
        "shortcuts.statsFormat": "Wiki stats: %d pages, %d words, %d entities, %d concepts, %d stubs",
        
        // MARK: - Lint Messages
        "lint.orphanPage": "Orphan page: \"%@\" has no backlinks",
        "lint.orphanSuggestion": "Consider adding [[%@]] links from related pages",
        "lint.brokenLink": "Broken link: \"%@\" references non-existent page [[%@]]",
        "lint.brokenLinkSuggestion": "Create page \"%@\" or fix the link",
        "lint.stubContent": "Stub content: \"%@\" has less than 100 characters",
        "lint.stubSuggestion": "Add more content or change status to \"Stub\"",
        "lint.outdated": "Possibly outdated: \"%@\" hasn't been updated in 30+ days",
        "lint.outdatedSuggestion": "Check if content needs updating",
        
        // MARK: - Log Actions
        "logAction.create": "Create",
        "logAction.update": "Update",
        "logAction.delete": "Delete",
        "logAction.lint": "Lint",
        "logAction.ingest": "Ingest",
        "logAction.smartIngest": "Smart Import",
        "logAction.importPDF": "Import PDF",
        "logAction.importPDFFailed": "Import PDF Failed",
        "logAction.deletePDF": "Delete PDF",
        "logAction.ingestPDF": "Import PDF",
        "logAction.highlight": "Highlight",
        "logAction.ocrRecognize": "OCR Recognize",
        "logAction.undo": "Undo",
        "logAction.redo": "Redo",
        "logAction.healthCheck": "Health Check",
        "logAction.lintIssuesFound": "Found %d issues",
        
        // MARK: - Export
        "export.header": "Knowledge Base Export",
        "export.exportTime": "Export Time",
        "export.totalPages": "Total Pages",
        "export.type": "Type",
        "export.status": "Status",
        "export.confidence": "Confidence",
        "export.tags": "Tags",
        "export.aliases": "Aliases",
        "export.created": "Created",
        "export.updated": "Updated",
        "export.importedPage": "Imported Page",
        "export.imported": "Imported",
        
        // MARK: - Templates
        "template.overview": "Overview",
        "template.coreContributions": "Core Contributions",
        "template.keyIdeas": "Key Ideas",
        "template.relatedLinks": "Related Links",
        "template.definition": "Definition",
        "template.corePoints": "Core Points",
        "template.dimension": "Dimension",
        "template.description": "Description",
        "template.comparisonDimensions": "Comparison Dimensions",
        "template.conclusion": "Conclusion",
        
        // MARK: - Collaboration
        "collab.title": "Collaboration",
        "collab.subtitle": "Real-time collaboration with others over local network",
        "collab.role.owner": "Owner",
        "collab.role.editor": "Editor",
        "collab.role.viewer": "Viewer",
        "collab.status.ready": "Ready",
        "collab.status.hosting": "Hosting collaboration",
        "collab.status.searching": "Searching for nearby rooms...",
        "collab.status.joining": "Joining...",
        "collab.status.connected": "Connected",
        "collab.status.connecting": "Connecting...",
        "collab.status.disconnected": "Disconnected",
        "collab.status.pageReceived": "Page sync received",
        "collab.status.simulatorNotSupported": "Simulator does not support local collaboration",
        "collab.status.advertiseError": "Advertising failed",
        "collab.status.browseError": "Browsing failed",
        "collab.simulatorWarning": "MultipeerConnectivity is unavailable on the Simulator. Please test collaboration on a real device.",
        "collab.defaultRoom": "Knowledge Base Room",
        "collab.username": "Username",
        "collab.usernamePlaceholder": "Enter your name",
        "collab.hostSession": "Host Session",
        "collab.joinSession": "Join Session",
        "collab.stopSearching": "Stop Searching",
        "collab.nearbyRooms": "Nearby Rooms",
        "collab.searching": "Searching...",
        "collab.hostedBy": "Hosted by",
        "collab.leaveSession": "Leave Session",
        "collab.connectedUsers": "Connected Users",
        "collab.recentEdits": "Recent Edits",
        "collab.noEdits": "No edits yet",
        "collab.hostSetup": "Set Up Collaboration Room",
        "collab.roomName": "Room Name",
        "collab.roomNamePlaceholder": "Enter room name",
        "collab.howItWorks": "How It Works",
        "collab.info.local": "Connect via local Wi-Fi / Bluetooth",
        "collab.info.encrypted": "End-to-end encrypted",
        "collab.info.maxPeers": "Supports up to 8 collaborators",
        "collab.startHosting": "Start Hosting",
        
        // MARK: - Graph 3D
        "graph3d.title": "3D Graph",
        "graph3d.viewPage": "View Page",
        
        // MARK: - Speech / Voice Note
        "speech.title": "Voice Notes",
        "speech.subtitle": "Speech to text — quickly capture ideas and knowledge",
        "speech.language": "Recognition Language",
        "speech.status.ready": "Ready",
        "speech.status.denied": "Microphone access denied",
        "speech.status.restricted": "Speech recognition restricted",
        "speech.status.notDetermined": "Awaiting authorization",
        "speech.status.unknown": "Unknown status",
        "speech.status.recording": "Recording...",
        "speech.status.complete": "Transcription complete",
        "speech.status.error": "Recognition error",
        "speech.status.audioError": "Audio engine error",
        "speech.status.localeNotSupported": "Language not supported",
        "speech.status.simulatorNotSupported": "Voice recording is not supported in Simulator. Please test on a real device.",
        "speech.needPermission": "Microphone permission required to record",
        "speech.requestPermission": "Request Permission",
        "speech.tapToRecord": "Tap to start recording",
        "speech.tapToStop": "Tap to stop recording",
        "speech.audioLevel": "Audio Level",
        "speech.result": "Transcription Result",
        "speech.characters": "characters",
        "speech.saveToWiki": "Save to Wiki",
        "speech.history": "History",
        "speech.saveTitle": "Save Voice Note",
        "speech.noteTitle": "Note Title",
        "speech.noteTitlePlaceholder": "Enter note title",
        "speech.voiceNote": "Voice Note",
        "speech.voiceTag": "voice",
        "speech.error.localeNotSupported": "Language not supported",
        "speech.error.notAuthorized": "Not authorized",
        "speech.error.audioEngine": "Audio engine error",
        
        // MARK: - Spatial (Vision Pro)
        "spatial.title": "Spatial Computing",
        "spatial.subtitle": "Browse knowledge graph in immersive 3D on Apple Vision Pro",
        "spatial.features": "Spatial Features",
        "spatial.feature.3dGraph": "3D Knowledge Graph",
        "spatial.feature.3dGraph.desc": "Browse and interact with knowledge nodes freely in space",
        "spatial.feature.gesture": "Gesture Interaction",
        "spatial.feature.gesture.desc": "Pinch, drag, and rotate knowledge nodes",
        "spatial.feature.gaze": "Eye Tracking",
        "spatial.feature.gaze.desc": "Look to select, natural interaction",
        "spatial.feature.spatialAudio": "Spatial Audio",
        "spatial.feature.spatialAudio.desc": "Node-related audio feedback for immersive experience",
        "spatial.requirement": "Full experience requires Apple Vision Pro. Currently showing iOS preview mode.",
        
        // MARK: - On-Device LLM
        "ondevice.title": "On-Device LLM",
        "ondevice.subtitle": "Run LLM locally — no network needed, fully private",
        "ondevice.available": "On-device inference available",
        "ondevice.unavailable": "On-device inference unavailable",
        "ondevice.requiresIOS17": "Requires iOS 17.0 or later",
        "ondevice.supportsFoundation": "Supports Apple Foundation Models",
        "ondevice.supportsCoreML": "Supports Core ML model inference",
        "ondevice.models": "Available Models",
        "ondevice.noModels": "No local models available. Import a .mlmodelc file.",
        "ondevice.system": "System",
        "ondevice.local": "Local",
        "ondevice.modelLoaded": "Model loaded",
        "ondevice.unload": "Unload",
        "ondevice.loadModel": "Load Model",
        "ondevice.importModel": "Import Model",
        "ondevice.appleIntelligence": "Apple Intelligence",
        "ondevice.test": "Test Inference",
        "ondevice.testGeneration": "Test Text Generation",
        "ondevice.inferenceSpeed": "Inference Speed",
        "ondevice.info": "Info",
        "ondevice.info.privacy": "All inference runs locally — data never leaves your device",
        "ondevice.info.offline": "No network required — fully offline",
        "ondevice.info.ne": "Uses Neural Engine for accelerated inference",
        "ondevice.info.memory": "Models use device memory — large models may affect performance",
        "ondevice.testPrompt": "Enter test prompt",
        "ondevice.generating": "Generating...",
        "ondevice.generate": "Generate",
        "ondevice.result": "Result",
        "ondevice.error.modelNotFound": "Model not found",
        "ondevice.error.modelNotLoaded": "Model not loaded",
        "ondevice.error.notSupported": "Not supported on this system",
        "ondevice.error.inferenceFailed": "Inference failed",
        "ondevice.error.compilationFailed": "Model compilation failed",
        "ondevice.chatContext": "You are a Knowledge Base assistant. Answer based on the following content.",
        "ondevice.chatQuestion": "Question",
        
        // MARK: - Misc
        "misc.text": "Text",
        "misc.confirm": "Confirm",
        "misc.save": "Save",
        "misc.delete": "Delete",
        "misc.edit": "Edit",
        "misc.close": "Close",
        "misc.cancel": "Cancel",
        "misc.ok": "OK",
        "misc.error": "Error",
        "misc.success": "Success",
        "misc.loading": "Loading...",
        "misc.noData": "No data",
        "misc.search": "Search",
        
        // MARK: - Undo
        "undo.undo": "Undo",
        "undo.redo": "Redo",
        "undo.unavailable": "Nothing to undo",
        "undo.redoUnavailable": "Nothing to redo",
        
        // MARK: - Backup
        "backup.title": "Backup & Recovery",
        "backup.settings": "Backup Settings",
        "backup.autoBackup": "Auto Backup",
        "backup.lastBackup": "Last Backup",
        "backup.actions": "Actions",
        "backup.createNow": "Create Backup Now",
        "backup.exportCurrent": "Export Current Data",
        "backup.history": "Backup History",
        "backup.noBackups": "No Backups",
        "backup.noBackupsDesc": "Create a backup to protect your wiki data",
        "backup.restoreTitle": "Restore Backup",
        "backup.restoreMessage": "Are you sure you want to restore from this backup? Current data will be replaced. A safety backup will be created first.",
        "backup.restore": "Restore",
        "backup.pages": "pages",
        "backup.words": "words",
        
        // MARK: - Deep Link
        "deeplink.pageNotFound": "Page not found",
        "deeplink.openedPage": "Opened page",
        
        // MARK: - Accessibility
        "a11y.words": "words",
        "a11y.links": "links",
        "a11y.tags": "Tags",
        "a11y.tapToOpen": "Tap to open",
        "a11y.voiceOver": "VoiceOver",
        "a11y.reduceMotion": "Reduce Motion",
        "a11y.highContrast": "High Contrast",
        
        // MARK: - Performance
        "perf.title": "Performance Monitor",
        "perf.memory": "Memory Usage",
        "perf.pages": "Pages",
        "perf.words": "Total Words",
        "perf.nodes": "Graph Nodes",
        "perf.edges": "Graph Edges",
        "perf.timing": "Timing Analysis",
        "perf.save": "Save",
        "perf.load": "Load",
        "perf.lint": "Lint",
        "perf.graphLayout": "Graph Layout",
        "perf.search": "Search",
        "perf.lastUpdated": "Last Updated",
        
        // MARK: - LLM Errors
        "llm.error.notConfigured": "LLM not configured. Please enter API Key in Settings.",
        "llm.error.invalidURL": "Invalid API URL",
        "llm.error.invalidResponse": "Invalid API response format",
        "llm.error.unauthorized": "API Key invalid or expired",
        "llm.error.rateLimited": "Too many requests, please try again later",
        "llm.error.httpError": "HTTP Error",
        "llm.error.apiError": "API Error",
        "llm.error.cancelled": "Request cancelled",
        
        // MARK: - LLM System Prompt
        "llm.prompt.role": "You are a Knowledge Base assistant, running on the Karpathy LLM Wiki methodology.",
        "llm.prompt.duty1": "1. Answer questions about the knowledge base content",
        "llm.prompt.duty2": "2. Help organize and compile knowledge",
        "llm.prompt.duty3": "3. Suggest connections between pages",
        "llm.prompt.duty4": "4. Discover knowledge gaps and contradictions",
        "llm.prompt.rule1": "- Answer based on knowledge base facts, cite related pages using [[Page Title]] format",
        "llm.prompt.rule2": "- If the knowledge base has no relevant information, state clearly",
        "llm.prompt.rule3": "- Respond in the user's language",
        "llm.prompt.rule4": "- Keep answers concise, accurate, and well-organized",
        "llm.prompt.overview": "Current knowledge base overview:",
        "llm.prompt.totalPages": "- Total pages",
        "llm.prompt.entityCount": "entities",
        "llm.prompt.conceptCount": "concepts",
        "llm.prompt.sourceCount": "sources",
        "llm.prompt.entityList": "Entity list:",
        "llm.prompt.conceptList": "Concept list:",
        "llm.prompt.sourceList": "Source list:",
        "llm.prompt.recentUpdates": "Recent updates:",
        "llm.prompt.relevantPages": "Relevant page content:",
        "llm.prompt.typeLabel": "Type",
        "llm.prompt.statusLabel": "Status",
        
        // MARK: - LLM Smart Ingest Prompt
        "llm.ingest.compileInstruction": "Please compile the following raw material into a structured Wiki page.",
        "llm.ingest.compileRules": "Compilation rules:",
        "llm.ingest.rule1": "1. Use Markdown format",
        "llm.ingest.rule2": "2. Link to existing Wiki pages using [[Page Title]] syntax if content mentions related concepts",
        "llm.ingest.rule3": "3. Extract key concepts as tags",
        "llm.ingest.rule4": "4. Organize content into clear sections",
        "llm.ingest.rule5": "5. Use tables for comparisons or relationships",
        "llm.ingest.rule6": "6. Keep facts accurate, do not add information not in the original",
        "llm.ingest.existingPages": "Existing Wiki pages (link these preferentially)",
        "llm.ingest.rawTitle": "Raw material title",
        "llm.ingest.rawContent": "Raw material content:",
        "llm.ingest.jsonFormat": "Return the compiled result in JSON format:",
        "llm.ingest.jsonCompiledContent": "Compiled Markdown content",
        "llm.ingest.jsonSuggestedTags": "tags",
        "llm.ingest.jsonSummary": "A brief summary",
        "llm.ingest.systemPrompt": "You are a Knowledge Base compiler. Compile raw material into structured content. Return only JSON, no other text.",
        
        // MARK: - LLM Provider Display Name
        "llm.provider.custom": "Custom API",
        
        // MARK: - OCR Errors
        "ocr.error.invalidImage": "Invalid image",
        "ocr.error.noResults": "No text recognized",
        "ocr.error.cameraUnavailable": "Camera unavailable",
        
        // MARK: - iCloud Sync Errors
        "icloud.error.notAvailable": "iCloud unavailable. Please sign in to your iCloud account.",
        "icloud.error.cloudKit": "CloudKit Error",
        "icloud.error.encoding": "Data encoding failed",
        "icloud.error.decoding": "Data decoding failed",
        "icloud.error.conflictResolution": "Conflict resolution failed",
        
        // MARK: - Sync Status Labels
        "sync.idle": "Not synced",
        "sync.syncing": "Syncing...",
        "sync.synced": "Synced",
        "sync.error": "Sync failed",
        
        // MARK: - Speech Language Names
        "speech.lang.zhHans": "Chinese (Simplified)",
        "speech.lang.zhHant": "Chinese (Traditional)",
        
        // MARK: - On-Device LLM Smart Ingest Prompt
        "ondevice.ingest.compileToWiki": "Compile the following content into a structured Wiki page. Existing pages",
        "ondevice.ingest.title": "Title",
        "ondevice.ingest.content": "Content",
        "ondevice.ingest.linkAndFormat": "Link existing pages with [[Page Title]]. Output in Markdown format.",
        
        // MARK: - Splash
        "splash.quote": "The job of humans is to curate sources,\nguide analysis, and ask good questions.\nThe job of LLMs is everything else.",
        "splash.enter": "Enter the Knowledge Universe",
        
        // MARK: - Backup Log
        "backup.log.createFailed": "Backup failed: %@",
        "backup.log.restoreFailed": "Restore backup failed: %@",
        "backup.log.crashRecovery": "Crash recovery detected — dirty flag found",
        "backup.log.saveIndexFailed": "Save backup index failed: %@",
        
        // MARK: - Deep Link Log
        "deepLink.log.indexingFailed": "Spotlight indexing failed: %@",
        
        // MARK: - Log Service
        "log.error.saveFailed": "Failed to save logs: %@",
        
        // MARK: - PageStore
        "pageStore.error.saveFailed": "Failed to save pages: %@",
        
        // MARK: - Performance Summary
        "perf.summary.title": "📊 Performance Summary",
        "perf.summary.pages": "Pages",
        "perf.summary.words": "words",
        "perf.summary.graph": "Graph",
        "perf.summary.nodes": "nodes",
        "perf.summary.edges": "edges",
        "perf.summary.memory": "Memory",
        "perf.summary.save": "Save",
        "perf.summary.load": "Load",
        "perf.summary.lint": "Lint",
        "perf.summary.graphLayout": "Graph Layout",
        "perf.summary.search": "Search",
        
        // MARK: - PDF Page Separator
        "pdf.pageSeparator": "\n\n--- Page %@ ---\n\n",
        
        // MARK: - Speech Language Names (Additional)
        "speech.lang.enUS": "English (US)",
        "speech.lang.enGB": "English (UK)",
        "speech.lang.jaJP": "Japanese",
        "speech.lang.koKR": "Korean",
        "speech.lang.frFR": "French",
        "speech.lang.deDE": "German",
        "speech.lang.esES": "Spanish",
        "speech.lang.ptBR": "Portuguese (BR)",
        
        // MARK: - LLM Provider Display Names
        "llm.provider.openAI": "OpenAI",
        "llm.provider.deepSeek": "DeepSeek",
        
        // MARK: - On-Device Model Name
        "ondevice.model.bundled": "Knowledge Base LLM (Bundled)",
        
        // MARK: - Theme Settings
        "settings.theme.system": "System",
        "settings.theme.light": "Light",
        "settings.theme.dark": "Dark",

        // MARK: - Language Settings
        "settings.language.system": "Follow System",
        "settings.appearanceMode": "Appearance",
        "settings.language": "Language",

        // MARK: - Settings Sections
        "settings.section.appearance": "Appearance",
        "settings.section.ai": "AI",
        "settings.section.data": "Data Management",
        "settings.section.moreFeatures": "More Features",
        "settings.section.stats": "Knowledge Base Statistics",
        "settings.section.maintenance": "Maintenance",
        "settings.section.about": "About",
        "settings.section.danger": "Danger Zone",

        // MARK: - Settings Labels
        "settings.llmConfig": "LLM Settings",
        "settings.llmNotConfigured": "Not Configured",
        "settings.onDeviceLLM": "On-Device LLM",
        "settings.exportMarkdown": "Export as Markdown",
        "settings.importClipboardHint": "Supports JSON array or Markdown separated text",
        "settings.voiceNote": "Voice Recording & Transcription",
        "settings.pdfManager": "Import, Read & Manage PDF Documents",
        "settings.collaboration": "Multi-person Collaboration & Sharing",
        "settings.graph3D": "3D Graph",
        "settings.graph3DHint": "Spherical knowledge nodes, rotate and zoom to explore",
        "settings.spatialComputing": "Spatial Computing",
        "settings.spatialComputingHint": "Immersive browsing in Apple Vision Pro",
        "settings.totalPages": "Total Pages",
        "settings.stubPagesHint": "Pages that are linked but have no content",
        "settings.tagManager": "Tag Manager",
        "settings.tagManagerHint": "Browse all tags and their associated pages",
        "settings.masterIndex": "Master Index",
        "settings.reset": "Reset Knowledge Base",
        "settings.aboutApp": "Knowledge Base",
        "settings.aboutAppDesc": "iOS knowledge management app based on Karpathy's LLM Wiki methodology",
        "settings.confirmReset": "Confirm Reset",
        "settings.cancel": "Cancel",
        "settings.ok": "OK",
        "settings.importSuccess": "Successfully imported %d pages",
        "settings.settings": "Settings",

        // MARK: - Ingest
        "ingest.hero.title": "Knowledge Import",
        "ingest.hero.subtitle": "Compile raw materials into your knowledge base, auto-extract key information and create cross-references",
        "ingest.ocrScan": "OCR Scan",
        "ingest.ocrScanHint": "Recognize text from images",
        "ingest.manualEntry": "Manual Entry",
        "ingest.manualEntryHint": "Paste or type content",
        "ingest.manualTitle": "Manual Entry",
        "ingest.field.title": "Title",
        "ingest.field.type": "Type",
        "ingest.field.titlePlaceholder": "Enter page title",
        "ingest.field.tags": "Tags (comma-separated)",
        "ingest.field.tagsPlaceholder": "AI, Knowledge Management, LLM",
        "ingest.field.content": "Content",
        "ingest.submit": "Import to Wiki",
        "ingest.submitting": "Compiling...",
        "ingest.smartToggle": "Smart Import (LLM)",
        "ingest.smartToggleHint": "LLM will auto-compile raw materials: extract key info, create cross-references, recommend tags and types",
        "ingest.field.icon": "Icon",
        "ingest.iconCustom": "Customized",
        "ingest.iconDefault": "Default",
        "ingest.iconReset": "Reset",
        "ingest.preview": "LLM Compilation Preview",
        "ingest.previewConfirm": "Confirm Import",
        "ingest.previewDiscard": "Discard",
        "ingest.suggestLinks": "Suggested Links",
        "ingest.tips": "Import Process",
        "ingest.tip1": "Paste raw materials into the content area",
        "ingest.tip2": "Select page type, icon and tags",
        "ingest.tip3": "Click Import, system will auto-compile",
        "ingest.tip4": "Auto-detect cross-references with existing pages",
        "ingest.tip5": "Update index and operation log",

        // MARK: - Tooltip Descriptions
        "tooltip.createPage.title": "Create Your First Page",
        "tooltip.createPage.desc": "Tap the + button in the top right, choose a page type, and create your first knowledge entry",
        "tooltip.wikiLink.title": "Page Interlinking",
        "tooltip.wikiLink.desc": "Type [[Page Name]] in the editor to link to other pages and build your knowledge network",
        "tooltip.graphFilter.title": "Graph Filtering",
        "tooltip.graphFilter.desc": "Tap the top labels to filter nodes by type, quickly locate your target",
        "tooltip.ingest.title": "Smart Import",
        "tooltip.ingest.desc": "Import content in bulk via PDF, web pages, or OCR scan",
        "tooltip.chat.title": "AI Assistant",
        "tooltip.chat.desc": "Ask questions based on your knowledge base, AI will answer combining your existing pages",
        "tooltip.tag.title": "Tag Management",
        "tooltip.tag.desc": "Add tags to pages for easy categorization, search and batch management",

        // MARK: - Misc
        "misc.gotIt": "Got it",

        // MARK: - Page Detail
        "page.empty": "This page has no content yet",
        "page.emptyHint": "Tap ✏️ in the top right to start editing, use [[Page Name]] to create links",
        "page.pin": "Pin page",
        "page.unpin": "Unpin",
        "page.backlinks": "Backlinks",
        "page.backlinksCount": "%d pages",
        "page.edit": "Edit page",
        "page.doneEditing": "Done editing",
        "page.type": "Page type",
        "page.icon": "Icon",
        "page.tags": "Tags",
        "page.alias": "Alias",
        "page.confidence": "Confidence",
        "page.status": "Status",
        "page.created": "Created",
        "page.updated": "Updated",
        "page.wordCount": "%d words",
        "page.outLinks": "Out-links (%d)",
        "page.backLinks": "Backlinks (%d)",
        "page.noOutLinks": "No out-links",
        "page.noBackLinks": "No backlinks",
        "page.searchPlaceholder": "Search pages...",
        "page.close": "Close",

        // MARK: - Create Page
        "create.pageTitle": "Page title",
        "create.selectType": "Select type",
        "create.selectIcon": "Select icon",
        "create.contentPlaceholder": "Enter content...",
        "create.creating": "Creating...",
        "create.selectTypeHint": "Choose a suitable type for the new page",

        // MARK: - iCloud Sync
        "icloud.title": "iCloud Sync",
        "icloud.status": "iCloud Sync Status",
        "icloud.upload": "Upload to iCloud",
        "icloud.download": "Download from iCloud",
        "icloud.bidirectional": "Two-way sync",
        "icloud.notConfigured": "Not configured",
        "icloud.enableSync": "Enable iCloud Sync",
        "icloud.disableSync": "Disable iCloud Sync",
        "icloud.syncNow": "Sync now",
        "icloud.neverSynced": "Never synced",

        // MARK: - OCR Scan
        "ocr.scan": "Scan image",
        "ocr.confirm": "Confirm",
        "ocr.scanFailed": "Text recognition failed",
        "ocr.noTextFound": "No text found in image",
        "ocr.usePhoto": "From Library",
        "ocr.useCamera": "Take Photo",
        "ocr.processing": "Recognizing text...",

        // MARK: - LLM Settings
        "llm.title": "LLM Settings",
        "llm.enable": "Enable LLM Assistant",
        "llm.apiKey": "API Key",
        "llm.apiKeyPlaceholder": "Enter API Key",
        "llm.apiAddressPlaceholder": "https://api.openai.com",
        "llm.modelPlaceholder": "gpt-4o-mini",
        "llm.save": "Save",
        "llm.saved": "Saved",
        "llm.notConfigured": "Not configured",
        "llm.configured": "Configured",
        "llm.notEnabled": "Not enabled",
        "llm.enabled": "Enabled",

        // MARK: - Tag Cloud
        "tag.title": "Tag Manager",
        "tag.noTags": "No tags yet",
        "tag.noTagsHint": "Add tags when editing pages, or specify tags when importing",
        "tag.rename": "Rename",
        "tag.delete": "Delete",
        "tag.tagPages": "Pages tagged #%@",
        "tag.allPages": "All pages",
        "tag.manage": "Manage",

        // MARK: - PDF Reader
        "pdf.title": "PDF Documents",
        "pdf.libraryHint": "Add PDF documents, read and highlight, extract content to knowledge base",
        "pdf.add": "Add PDF",
        "pdf.addDocument": "Add Document",
        "pdf.import": "Import",
        "pdf.cancel": "Cancel",
        "pdf.noDocuments": "No PDF documents yet",
        "pdf.noDocumentsHint": "Tap the button above to add a PDF file",

        // MARK: - Chat
        "chat.notConfigured": "Please configure LLM API Key first",
        "chat.error": "Error",
        "chat.ok": "OK",
        "chat.expanding": "Expand full text",
        "chat.collapse": "Collapse",
        "chat.sending": "Sending...",

        // MARK: - Sidebar
        "sidebar.masterIndex": "Master Index",
        "sidebar.backToMain": "Back",

        // MARK: - Search
        "search.title": "Search",
        "search.recentUpdates": "Recently Updated",
        "search.recentCreated": "Recently Created",
        "search.byTitle": "By Title",
        "search.byType": "By Type",

        // MARK: - Index
        "index.entities": "Entities",
        "index.concepts": "Concepts",
        "index.sources": "Sources",
        "index.comparisons": "Comparisons",
        "index.maps": "Maps",
        "index.raw": "Raw",
        "index.total": "Total",
        "index.lastUpdated": "Last Updated",
        "index.viewAll": "View all",

        // MARK: - Markdown Editor
        "editor.searchPage": "Search pages...",
        "editor.tagPlaceholder": "Enter tag",
        "editor.aliasPlaceholder": "Enter alias",

        // MARK: - Lint
        "lint.title": "Health Check",
        "lint.running": "Checking...",
        "lint.noIssues": "Knowledge base is in good health",
        "lint.noIssuesHint": "No broken links, orphaned pages or conflicting content found",
        "lint.ok": "OK",

        // MARK: - Backlinks
        "backlinks.title": "Backlinks",
        "backlinks.noOutLinks": "No out-links",
        "backlinks.noBackLinks": "No backlinks",

        // MARK: - Graph

        // MARK: - Ingest View
        "ingest.smartIngestDone": "Smart Import",
        "ingest.smartIngestDoneDesc": "LLM compilation complete, type: %@",

        // MARK: - Loading
        "loading": "Loading...",

        // MARK: - Log
        "log.title": "Operation Log",

        // MARK: - Widget & Watch
        "widget.title": "Knowledge Base",
        "widget.characters": "chars",
        "widget.placeholder": "Placeholder",

        // MARK: - Collaboration
        "collab.room": "Knowledge Base Room",
        "collab.joining": "Joining room...",

        // MARK: - Page Detail (Format & Accessibility)
        "page.statusFormat": "Status: %@",
        "page.confidenceFormat": "Confidence: %@",
        "page.deletePageTitle": "Delete \"%@\"",
        "page.typeAccessibility": "Page type: %@",
        "page.statusAccessibility": "Status: %@",
        "page.confidenceAccessibility": "Confidence: %@",
        "page.titleAccessibility": "Page title: %@",
        "page.aliasAccessibility": "Aliases: %@",
        "page.tagsAccessibility": "Tags: %@",
        "page.createdFormat": "Created: %@",
        "page.updatedFormat": "Updated: %@",
        "page.outLinksCount": "%d links",
        "page.metaAccessibility": "Meta info, created on %@, %@ words, %d outgoing links",
        "page.doubleTapToNavigate": "Double-tap to navigate",
        "page.confirmDelete": "Confirm Delete",
        "page.deleteMessage": "This action cannot be undone. The page and all references will be deleted.",

        // MARK: - iCloud Sync (Additional)
        "icloud.lastSyncFormat": "Last sync: %@",
        "icloud.pullWillOverwrite": "Downloading from iCloud will overwrite local data",
        "icloud.pullOverwriteMessage": "All local pages will be replaced by remote data, this action cannot be undone.",
        "icloud.autoSyncFailed": "Auto sync failed",

        // MARK: - Sidebar (Additional)
        "sidebar.frequentKnowledge": "Frequent Knowledge",
        "sidebar.linkUnit": " links",

        // MARK: - OCR (Additional)
        "ocr.scanTag": "scan",
        "ocr.addTag": "Add",
        "ocr.changeIcon": "Change",
        "ocr.customIcon": "Custom",
        "ocr.charCountFormat": "Characters: %d",

        // MARK: - PDF (Additional)
        "pdf.noteLabel": "Note: ",
        "pdf.ingestModeFormat": "Mode: %@",
        "pdf.pageCountFormat": "%d pages",
        "pdf.highlightCountFormat": "%d highlights",
        "pdf.createdPage": "Created page %@",
        "pdf.pageNumber": "Page %d",

        // MARK: - Tag (Additional)
        "tag.renameTag": "Rename Tag",
        "tag.newName": "New name",
        "tag.renameMessage": "Rename #%@ to new name",
        "tag.deleteTag": "Delete Tag",
        "tag.deleteMessage": "Will remove #%@ from %d pages, this action cannot be undone",

        // MARK: - Search (Additional)
        "search.noResultsHint": "Try different keywords or adjust filter criteria",
        "search.pagesCount": "%d pages",
        "search.search": "Search",

        // MARK: - Index (Additional)
        "index.entityCount": "Entities (%d)",
        "index.conceptCount": "Concepts (%d)",
        "index.sourceCount": "Sources (%d)",
        "index.comparisonCount": "Comparisons (%d)",
        "index.wordCount": "%d words",

        // MARK: - Icon Picker
        "iconPicker.common": "Common",
        "iconPicker.academic": "Academic",
        "iconPicker.nature": "Nature",
        "iconPicker.transport": "Transport",
        "iconPicker.symbols": "Symbols",
        "iconPicker.selectIcon": "Select Icon",
        "iconPicker.customSelected": "Custom icon selected",
        "iconPicker.useDefault": "Use default icon",
        "iconPicker.reset": "Reset",
        "iconPicker.allIcons": "All Icons",

        // MARK: - Backlinks (Additional)
        "backlinks.outgoingCount": "Outgoing (%d)",
        "backlinks.backlinksCount": "Backlinks (%d)",

        // MARK: - Splash (Additional)
        "splash.appName": "Knowledge Base",

        // MARK: - Collaboration
    ]
}
