import os
import re

base_dir = "/Users/constantine/Documents/work/code/projects/km"

# 出现严格并发报错的文件名单
targets = [
    "ThemeManager.swift", "PageSchema.swift", "AISynthesisService.swift", "IngestQueue.swift",
    "LLMModels.swift", "PromptService.swift", "ServiceContainer.swift", "PerformanceBenchmarker.swift",
    "CollaborationService.swift", "AccessibilityService.swift", "DataExportService.swift",
    "HapticManager.swift", "LocalAnalyticsService.swift", "LogService.swift", "PencilManager.swift",
    "PerformanceService.swift", "SecurityReinforcement.swift", "SpotlightService.swift",
    "WatchConnectivityService.swift", "PluginMarketService.swift", "OCRService.swift",
    "PDFService.swift", "SpeechService.swift", "VaultSecurityService.swift", "VaultService.swift",
    "iCloudSyncManager.swift", "KMiCloudSyncService.swift", "ActivityService.swift",
    "WikiEventBus.swift", "LLMService.swift", "OnDeviceLLMService.swift", "WikiTooltip.swift",
    "SQLiteStore.swift", "EmbeddingManager.swift", "LLMAdapters.swift",
    
    # 出现 AttributedString 或闭包跨 Actor 报错的 SwiftUI 视图
    "KnowledgeDashboardView.swift", "Graph3DComponents.swift", "MarkdownTextView.swift",
    "MermaidWebView.swift", "OCRScanComponents.swift", "OnDeviceComponents.swift",
    "NavigationView.swift", "MarkdownEditorView.swift", "MarkdownRendererView.swift",
    "OCRScanView.swift", "PDFReaderView.swift", "IngestView.swift", "iCloudSyncView.swift",
    "LLMSettingsView.swift", "OnDeviceLLMSettingsView.swift"
]

swift_files = []
for root, dirs, files in os.walk(base_dir):
    for file in files:
        if file.endswith(".swift"):
            swift_files.append(os.path.join(root, file))

for path in swift_files:
    filename = os.path.basename(path)
    
    with open(path, 'r') as f:
        content = f.read()
    orig_content = content

    # 1. 补充缺失的模块并发导入声明
    if filename == "OCRService.swift":
        content = content.replace("import Vision", "@preconcurrency import Vision")
    if filename == "SpeechService.swift":
        content = content.replace("import Speech", "@preconcurrency import Speech")
    if filename == "MCSessionDelegateImpl.swift":
        content = content.replace("import MultipeerConnectivity", "@preconcurrency import MultipeerConnectivity")
        if "@unchecked Sendable" not in content:
            content += "\n\nextension MCSessionDelegateImpl: @unchecked Sendable {}\nextension MCAdvertiserDelegateImpl: @unchecked Sendable {}\nextension MCBrowserDelegateImpl: @unchecked Sendable {}\n"
            
    # 2. 全局基础类型变量解绑
    if filename == "ShortcutManager.swift":
        content = re.sub(r'static var (title|description|openAppWhenRun)', r'nonisolated(unsafe) static var \1', content)
    if filename == "AppConfig.swift":
        content = re.sub(r'static var configData', r'nonisolated(unsafe) static var configData', content)

    # 3. 为需要的类/结构体注入 @MainActor
    if filename in targets:
        # 如果文件还没有标注 @MainActor，则在顶层类或结构体上方注入
        if "@MainActor" not in content:
            # 匹配 public/internal/final 等修饰符，找到首个 class 或 struct 并加上 @MainActor
            content = re.sub(r'^((?:public\s+|internal\s+)?(?:final\s+)?(?:class|struct)\s+\w+.*)$', 
                             r'@MainActor\n\1', 
                             content, 
                             count=1, 
                             flags=re.MULTILINE)

    if content != orig_content:
        with open(path, 'w') as f:
            f.write(content)

print("Batch Swift 6 Concurrency Refactoring Completed!")
