import SwiftUI

// MARK: - Ingest Hero Section
struct IngestHeroSection: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.wikiSource, .wikiAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("知识导入")
                .font(.title2.weight(.bold))
                .foregroundStyle(.wikiText)
            Text("将原始资料编译到 Wiki，自动提取关键信息并建立交叉引用")
                .font(.caption)
                .foregroundStyle(.wikiSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
    }
}

// MARK: - Ingest Entry Cards Section
struct IngestEntryCardsSection: View {
    @Binding var showManualForm: Bool
    @Binding var newType: PageType

    var body: some View {
        HStack(spacing: 12) {
            // OCR entry card (navigation)
            NavigationLink(destination: OCRScanView()) {
                entryCardContent(
                    title: "OCR 扫描",
                    subtitle: "从图片中识别文字",
                    icon: "text.viewfinder",
                    color: .wikiAccent
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("OCR扫描")
            .simultaneousGesture(TapGesture().onEnded {
                showManualForm = false
            })

            // Manual entry card (toggle)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showManualForm.toggle()
                }
            }) {
                entryCardContent(
                    title: "手动录入",
                    subtitle: "粘贴或输入内容",
                    icon: "pencil.and.list.clipboard",
                    color: .wikiSource
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }

    private func entryCardContent(title: String, subtitle: String, icon: String, color: Color) -> some View {
        WikiBorderedCard(cornerRadius: 12, borderColor: color.opacity(0.3)) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.wikiText)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.wikiSecondary)
            }
        }
    }
}

// MARK: - Ingest Manual Form Section
struct IngestManualFormSection: View {
    @Binding var newTitle: String
    @Binding var newContent: String
    @Binding var newType: PageType
    @Binding var newCustomIcon: String?
    @Binding var newTags: String
    @Binding var showIconPicker: Bool
    @Binding var useSmartIngest: Bool
    @Binding var smartResult: SmartIngestResult?
    @Binding var isIngesting: Bool
    @Binding var ingestSuccess: Bool
    @Binding var errorMessage: String?
    @Binding var showError: Bool

    let llmService: LLMService
    let store: KMStore
    let onPerformIngest: () -> Void
    let onConfirmSmartIngest: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Section header
            WikiSectionHeader(title: "手动录入", icon: "pencil.and.list.clipboard")

            // Title field
            VStack(alignment: .leading, spacing: 6) {
                Text("标题")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.wikiSecondary)
                WikiTextField(placeholder: "输入页面标题", text: $newTitle)
                    .accessibilityIdentifier("输入页面标题")
            }

            // Type selector
            pageTypeSelector

            // Icon picker
            iconPickerSection

            // Tags field
            VStack(alignment: .leading, spacing: 6) {
                Text("标签（逗号分隔）")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.wikiSecondary)
                WikiTagField(placeholder: "AI, 知识管理, LLM", text: $newTags)
            }

            // Content editor
            VStack(alignment: .leading, spacing: 6) {
                Text("内容")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.wikiSecondary)
                WikiMonospacedEditor(text: $newContent, minHeight: 200)
            }
        }
        .padding(.horizontal)

        // Smart ingest toggle
        if llmService.isEnabled && !llmService.apiKey.isEmpty {
            smartIngestToggle
        }

        // Smart preview
        if let result = smartResult {
            SmartIngestPreview(result: result, onConfirm: onConfirmSmartIngest, onDiscard: { smartResult = nil })
                .padding(.horizontal)
        }

        // Submit button
        WikiPrimaryButton(
            title: isIngesting ? "编译中..." : "导入到 Wiki",
            icon: "tray.and.arrow.down.fill",
            isLoading: isIngesting
        ) {
            onPerformIngest()
        }
        .disabled(newTitle.isEmpty || newContent.isEmpty || isIngesting)
        .opacity(newTitle.isEmpty || newContent.isEmpty ? 0.5 : 1)
        .padding(.horizontal)

        // Success banner
        if ingestSuccess {
            WikiSuccessBanner(message: "导入成功！知识已编译到 Wiki")
                .padding(.horizontal)
        }
    }

    private var smartIngestToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $useSmartIngest) {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile.fill")
                        .foregroundStyle(.wikiAccent)
                    Text("智能导入 (LLM)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.wikiText)
                }
            }
            .tint(.wikiAccent)
            .accessibilityIdentifier("智能导入")

            if useSmartIngest {
                Text("LLM 将自动编译原始资料：提取关键信息、建立交叉引用、推荐标签和类型")
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
            }
        }
        .wikiCard()
        .padding(.horizontal)
    }

    private var pageTypeSelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("类型")
                .font(.caption.weight(.medium))
                .foregroundStyle(.wikiSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PageType.allCases) { type in
                        Button(action: { newType = type }) {
                            WikiIconChip(
                                icon: type.icon,
                                text: type.displayName,
                                color: type.themedColor,
                                isSelected: newType == type
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var iconPickerSection: some View {
        HStack(spacing: 10) {
            Text("图标")
                .font(.caption.weight(.medium))
                .foregroundStyle(.wikiSecondary)

            Button(action: { showIconPicker = true }) {
                HStack(spacing: 6) {
                    Image(systemName: newCustomIcon ?? newType.icon)
                        .font(.caption)
                        .foregroundStyle(newCustomIcon != nil ? .wikiAccent : .wikiSecondary)
                        .frame(width: 20, height: 20)
                        .background((newCustomIcon != nil ? Color.wikiAccent : newType.themedColor).opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: WikiUI.tinyRadius))
                    Text(newCustomIcon != nil ? "已自定义" : "默认")
                        .font(.caption)
                        .foregroundStyle(newCustomIcon != nil ? .wikiAccent : .wikiSecondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9))
                        .foregroundStyle(.wikiSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.wikiCard)
                .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: WikiUI.smallRadius)
                        .stroke(newCustomIcon != nil ? Color.wikiAccent.opacity(0.5) : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .fixedSize()

            if newCustomIcon != nil {
                Button(action: { newCustomIcon = nil }) {
                    Text("重置")
                        .font(.caption2)
                        .foregroundStyle(.wikiSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.wikiCard)
                        .clipShape(RoundedRectangle(cornerRadius: WikiUI.microRadius))
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }
}

// MARK: - Smart Ingest Preview
struct SmartIngestPreview: View {
    let result: SmartIngestResult
    let onConfirm: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.wikiAccent)
                Text("LLM 编译预览")
                    .font(.headline)
                    .foregroundStyle(.wikiText)
                Spacer()
                Button(action: onConfirm) {
                    WikiCapsuleButton(title: "确认导入", icon: "checkmark", isPrimary: true, color: .wikiAccent)
                }
                .buttonStyle(.plain)
                Button(action: onDiscard) {
                    WikiCapsuleButton(title: "放弃", icon: nil, isPrimary: false)
                }
                .buttonStyle(.plain)
            }

            // Type + Tags chips
            HStack(spacing: 8) {
                if let type = PageType(rawValue: result.suggestedType) {
                    WikiChip(text: type.displayName, color: type.themedColor)
                }
                ForEach(result.suggestedTags.prefix(5), id: \.self) { tag in
                    WikiChip(text: "#\(tag)", color: .wikiAccent, backgroundOpacity: 0.1)
                }
            }

            if !result.summary.isEmpty {
                Text(result.summary)
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
                    .italic()
            }

            // Compiled content preview
            ScrollView {
                Text(result.compiledContent)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.wikiText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
            .padding(8)
            .background(Color.wikiBackground)
            .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))

            // Related titles
            if !result.relatedTitles.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("建议关联")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.wikiSecondary)

                    ForEach(result.relatedTitles, id: \.self) { title in
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.caption2)
                            Text("[[\(title)]]")
                                .font(.caption)
                        }
                        .foregroundStyle(.wikiAccent)
                    }
                }
            }
        }
        .wikiCard()
    }
}

// MARK: - Ingest Tips Section
struct IngestTipsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("导入流程")
                .font(.headline)
                .foregroundStyle(.wikiText)

            WikiStepRow(number: 1, text: "将原始资料粘贴到内容区域")
            WikiStepRow(number: 2, text: "选择页面类型、图标和标签")
            WikiStepRow(number: 3, text: "点击导入，系统自动编译")
            WikiStepRow(number: 4, text: "自动检测已有页面的交叉引用")
            WikiStepRow(number: 5, text: "更新索引和操作日志")
        }
        .wikiCard()
        .padding(.horizontal)
    }
}
