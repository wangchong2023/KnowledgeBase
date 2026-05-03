import SwiftUI

// MARK: - Notification Names
extension Notification.Name {
    static let importFromClipboard = Notification.Name("importFromClipboard")
}

// MARK: - Ingest Hero Section
struct IngestHeroSection: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.wikiSource, .wikiText],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            // 移除重复的标题，因为导航栏已经有了
            Text(Localized.tr("ingest.hero.subtitle"))
                .font(.caption)
                .foregroundStyle(.wikiSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Ingest Entry Cards Section
struct IngestEntryCardsSection: View {
    @Binding var showManualForm: Bool
    @Binding var showOCRScan: Bool
    @Binding var newType: PageType
    @Binding var showFileImporter: Bool
    @Binding var showVoiceNote: Bool
    @Binding var showURLImport: Bool
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// iPad 大屏幕下副标题从 10pt 升到 12pt
    private var subtitleFont: Font {
        horizontalSizeClass == .regular ? .caption : .caption2
    }

    /// 响应式列配置：iPhone 2列，iPad 自适应多列
    private var columns: [GridItem] {
        if horizontalSizeClass == .regular {
            Array(repeating: GridItem(.flexible(minimum: 80, maximum: 180), spacing: 12), count: 5)
        } else {
            [GridItem(.flexible()), GridItem(.flexible())]
        }
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            // 1. File import card
            Button(action: {
                showFileImporter = true
            }) {
                entryCardContent(
                    title: Localized.tr("ingest.fileImport"),
                    subtitle: Localized.tr("ingest.fileImportHint"),
                    icon: "doc.badge.plus",
                    color: .wikiText
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("ingest.file")

            // 2. Manual entry card (toggle)
            Button(action: {
                showManualForm = true
            }) {
                entryCardContent(
                    title: Localized.tr("ingest.manualEntry"),
                    subtitle: Localized.tr("ingest.manualEntryHint"),
                    icon: "pencil.and.list.clipboard",
                    color: .wikiText
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("ingest.manual")

            // 3. URL import card
            Button(action: {
                showURLImport = true
            }) {
                entryCardContent(
                    title: Localized.tr("ingest.urlImport"),
                    subtitle: Localized.tr("ingest.urlImportHint"),
                    icon: "link.badge.plus",
                    color: .wikiText
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("ingest.url")

            // 4. OCR entry card
            Button(action: {
                showOCRScan = true
            }) {
                entryCardContent(
                    title: Localized.tr("ingest.ocrScan"),
                    subtitle: Localized.tr("ingest.ocrScanHint"),
                    icon: "text.viewfinder",
                    color: .wikiText
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("ingest.ocr")

            // 5. Clipboard import card
            Button(action: {
                // Trigger clipboard import via notification to parent
                NotificationCenter.default.post(name: .importFromClipboard, object: nil)
            }) {
                entryCardContent(
                    title: Localized.tr("ingest.clipboardImport"),
                    subtitle: Localized.tr("ingest.clipboardImportHint"),
                    icon: "doc.on.clipboard",
                    color: .wikiText
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("ingest.clipboard")

            // 6. Voice note card
            Button(action: {
                showVoiceNote = true
            }) {
                entryCardContent(
                    title: Localized.tr("ingest.voiceNote"),
                    subtitle: Localized.tr("ingest.voiceNoteHint"),
                    icon: "waveform",
                    color: .wikiText
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("ingest.voice")
        }
        .padding(.horizontal)
    }

    private func entryCardContent(title: String, subtitle: String, icon: String, color: Color) -> some View {
        WikiBorderedCard(borderColor: color.opacity(0.3)) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .frame(width: 32, height: 32)
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.wikiText)
                Text(subtitle)
                    .font(subtitleFont)
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
    @Binding var newTags: [String]
    @Binding var showIconPicker: Bool
    @Binding var useSmartIngest: Bool
    @Binding var smartResult: SmartIngestResult?
    @Binding var isIngesting: Bool
    @Binding var ingestSuccess: Bool
    @Binding var errorMessage: String?
    @Binding var showError: Bool
    @Binding var useDeepScan: Bool

    let llmService: LLMService
    let store: KMStore
    let onPerformIngest: () -> Void
    let onConfirmSmartIngest: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// iPad 大屏幕下表单字段标签从 12pt 升到 15pt
    private var fieldLabelFont: Font {
        horizontalSizeClass == .regular ? .subheadline.weight(.medium) : .caption.weight(.medium)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Section header
            WikiSectionHeader(title: Localized.tr("ingest.manualTitle"), icon: "pencil.and.list.clipboard")

            // Title field
            VStack(alignment: .leading, spacing: 6) {
                Text(Localized.tr("ingest.field.title"))
                    .font(fieldLabelFont)
                    .foregroundStyle(.wikiSecondary)
                WikiTextField(placeholder: Localized.tr("ingest.field.titlePlaceholder"), text: $newTitle)
                    .accessibilityIdentifier("ingest.titleInput")
            }

            // Type selector
            pageTypeSelector

            // Icon picker
            iconPickerSection

            // Tags field
            VStack(alignment: .leading, spacing: 6) {
                Text(Localized.tr("ingest.field.tags"))
                    .font(fieldLabelFont)
                    .foregroundStyle(.wikiSecondary)
                WikiTagField(placeholder: Localized.tr("ingest.field.tagsPlaceholder"), tags: $newTags)
            }

            // Content editor
            VStack(alignment: .leading, spacing: 6) {
                Text(Localized.tr("ingest.field.content"))
                    .font(fieldLabelFont)
                    .foregroundStyle(.wikiSecondary)
                WikiMonospacedEditor(text: $newContent, minHeight: 200)
            }
        }
        .padding(.horizontal)

        // Advanced Options Card
        VStack(spacing: 0) {
            if llmService.isEnabled && !llmService.apiKey.isEmpty {
                Toggle(isOn: $useSmartIngest) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.wikiAccent)
                            .frame(width: 20)
                        Text(Localized.tr("ingest.smartToggle"))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.wikiText)
                    }
                }
                .tint(.wikiAccent)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .accessibilityIdentifier("ingest.smartToggleAction")
                
                Divider().padding(.leading, 44)
            }
            
            Toggle(isOn: $useDeepScan) {
                HStack(spacing: 8) {
                    Image(systemName: "cpu")
                        .foregroundStyle(.wikiSource)
                        .frame(width: 20)
                    Text(Localized.tr("ingest.deepScan"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.wikiText)
                }
            }
            .tint(.wikiSource)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            
            if useSmartIngest || useDeepScan {
                VStack(alignment: .leading, spacing: 4) {
                    if useSmartIngest {
                        Text(Localized.tr("ingest.smartToggleHint"))
                            .font(.caption)
                            .foregroundStyle(.wikiSecondary)
                    }
                    if useDeepScan {
                        Text(Localized.tr("ingest.deepScanDesc"))
                            .font(.caption)
                            .foregroundStyle(.wikiSource)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.opacity)
            }
        }
        .background(Color.wikiCard.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: WikiUI.cardRadius)
                .stroke(Color.wikiBorder.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)

        // Smart preview
        if let result = smartResult {
            SmartIngestPreview(result: result, onConfirm: onConfirmSmartIngest, onDiscard: { smartResult = nil })
                .padding(.horizontal)
        }

        // Submit button
        WikiPrimaryButton(
            title: isIngesting ? Localized.tr("ingest.submitting") : Localized.tr("ingest.submit"),
            icon: "tray.and.arrow.down.fill",
            isLoading: isIngesting
        ) {
            onPerformIngest()
        }
        .disabled(newTitle.isEmpty || newContent.isEmpty || isIngesting)
        .opacity(newTitle.isEmpty || newContent.isEmpty ? 0.5 : 1)
        .padding(.horizontal)

    }

    private var smartIngestToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $useSmartIngest) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.wikiAccent)
                    Text(Localized.tr("ingest.smartToggle"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.wikiText)
                }
            }
            .tint(.wikiAccent)
            .accessibilityIdentifier("ingest.smartToggleAction")

            if useSmartIngest {
                Text(Localized.tr("ingest.smartToggleHint"))
                    .font(horizontalSizeClass == .regular ? .subheadline : .caption)
                    .foregroundStyle(.wikiSecondary)
            }
        }
        .padding(.horizontal)
    }

    private var deepScanToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $useDeepScan) {
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .foregroundStyle(.wikiSource)
                    Text(Localized.tr("ingest.deepScan"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.wikiText)
                }
            }
            .tint(.wikiSource)
            
            if useDeepScan {
                Text(Localized.tr("ingest.deepScanDesc"))
                    .font(horizontalSizeClass == .regular ? .subheadline : .caption)
                    .foregroundStyle(.wikiSource)
                    .padding(.leading, 30)
            }
        }
        .padding()
        .background(useDeepScan ? Color.wikiSource.opacity(0.1) : Color.wikiCard.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
        .padding(.horizontal)
    }

    private var pageTypeSelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Localized.tr("ingest.field.type"))
                .font(fieldLabelFont)
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
            Text(Localized.tr("ingest.field.icon"))
                .font(fieldLabelFont)
                .foregroundStyle(.wikiSecondary)

            Button(action: { showIconPicker = true }) {
                HStack(spacing: 6) {
                    Image(systemName: newCustomIcon ?? newType.icon)
                        .font(.caption)
                        .foregroundStyle(newCustomIcon != nil ? .wikiAccent : .wikiSecondary)
                        .frame(width: 20, height: 20)
                        .background((newCustomIcon != nil ? Color.wikiAccent : newType.themedColor).opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: WikiUI.tinyRadius))
                    Text(newCustomIcon != nil ? Localized.tr("ingest.iconCustom") : Localized.tr("ingest.iconDefault"))
                        .font(horizontalSizeClass == .regular ? .subheadline : .caption)
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
                    Text(Localized.tr("ingest.iconReset"))
                        .font(horizontalSizeClass == .regular ? .caption : .caption2)
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// iPad 大屏幕下从 12pt 升到 15pt
    private var previewFont: Font {
        horizontalSizeClass == .regular ? .subheadline : .caption
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.wikiAccent)
                Text(Localized.tr("ingest.preview"))
                    .font(.headline)
                    .foregroundStyle(.wikiText)
                Spacer()
                Button(action: onConfirm) {
                    WikiCapsuleButton(title: Localized.tr("ingest.previewConfirm"), icon: "checkmark", isPrimary: true, color: .wikiAccent)
                }
                .buttonStyle(.plain)
                Button(action: onDiscard) {
                    WikiCapsuleButton(title: Localized.tr("ingest.previewDiscard"), icon: nil, isPrimary: false)
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
                    .font(previewFont)
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
                    Text(Localized.tr("ingest.suggestLinks"))
                        .font(previewFont.weight(.medium))
                        .foregroundStyle(.wikiSecondary)

                    ForEach(result.relatedTitles, id: \.self) { title in
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.caption2)
                            Text("[[\(title)]]")
                                .font(previewFont)
                        }
                        .foregroundStyle(.wikiAccent)
                    }
                }
            }
        }
        .padding()
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
    }
}

// MARK: - Ingest Tips Section
struct IngestTipsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Localized.tr("ingest.tips"))
                .font(.headline)
                .foregroundStyle(.wikiText)

            // Three import method cards
            HStack(spacing: 10) {
                importMethodCard(
                    icon: "doc.badge.plus",
                    title: Localized.tr("ingest.method.file"),
                    desc: Localized.tr("ingest.method.fileDesc")
                )
                importMethodCard(
                    icon: "text.viewfinder",
                    title: Localized.tr("ingest.method.ocr"),
                    desc: Localized.tr("ingest.method.ocrDesc")
                )
                importMethodCard(
                    icon: "pencil.and.list.clipboard",
                    title: Localized.tr("ingest.method.manual"),
                    desc: Localized.tr("ingest.method.manualDesc")
                )
            }
        }
        .padding(.horizontal)
    }

    private func importMethodCard(icon: String, title: String, desc: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.wikiAccent)
                .frame(maxWidth: .infinity)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.wikiText)
            Text(desc)
                .font(.caption2)
                .foregroundStyle(.wikiSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))
    }
}

// MARK: - URL Import Sheet
struct URLImportSheet: View {
    @Binding var urlText: String
    let onImport: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(Localized.tr("ingest.urlImportPlaceholder"))
                        .font(.caption)
                        .foregroundStyle(.wikiSecondary)
                    
                    TextEditor(text: $urlText)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(8)
                        .background(Color.wikiBackground)
                        .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: WikiUI.smallRadius)
                                .stroke(Color.wikiAccent.opacity(0.2), lineWidth: 1)
                        )
                }
                .padding()
                
                VStack(alignment: .leading, spacing: 12) {
                    Label(Localized.tr("ingest.webDesc"), systemImage: "info.circle")
                        .font(.caption2)
                        .foregroundStyle(.wikiSecondary)
                    
                    WikiPrimaryButton(
                        title: Localized.tr("misc.import"),
                        icon: "arrow.down.doc.fill",
                        isLoading: false
                    ) {
                        onImport()
                    }
                    .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                .background(Color.wikiCard)
            }
            .navigationTitle(Localized.tr("ingest.urlImport"))
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(Localized.tr("misc.cancel")) {
                        dismiss()
                    }
                }
            }
            .background(Color.wikiBackground)
        }
    }
}
