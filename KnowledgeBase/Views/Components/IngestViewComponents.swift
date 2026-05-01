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
            Text(Localized.tr("ingest.hero.title"))
                .font(.title2.weight(.bold))
                .foregroundStyle(.wikiText)
            Text(Localized.tr("ingest.hero.subtitle"))
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
                    title: Localized.tr("ingest.ocrScan"),
                    subtitle: Localized.tr("ingest.ocrScanHint"),
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
                withAnimation(.easeInOut(duration: 0.25)) {
                    showManualForm.toggle()
                }
            }) {
                entryCardContent(
                    title: Localized.tr("ingest.manualEntry"),
                    subtitle: Localized.tr("ingest.manualEntryHint"),
                    icon: "pencil.and.list.clipboard",
                    color: .wikiSource
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }

    private func entryCardContent(title: String, subtitle: String, icon: String, color: Color) -> some View {
        WikiBorderedCard(borderColor: color.opacity(0.3)) {
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
            WikiSectionHeader(title: Localized.tr("ingest.manualTitle"), icon: "pencil.and.list.clipboard")

            // Title field
            VStack(alignment: .leading, spacing: 6) {
                Text(Localized.tr("ingest.field.title"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.wikiSecondary)
                WikiTextField(placeholder: Localized.tr("ingest.field.titlePlaceholder"), text: $newTitle)
                    .accessibilityIdentifier("输入页面标题")
            }

            // Type selector
            pageTypeSelector

            // Icon picker
            iconPickerSection

            // Tags field
            VStack(alignment: .leading, spacing: 6) {
                Text(Localized.tr("ingest.field.tags"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.wikiSecondary)
                WikiTagField(placeholder: Localized.tr("ingest.field.tagsPlaceholder"), text: $newTags)
            }

            // Content editor
            VStack(alignment: .leading, spacing: 6) {
                Text(Localized.tr("ingest.field.content"))
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
            title: isIngesting ? Localized.tr("ingest.submitting") : Localized.tr("ingest.submit"),
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
            WikiSuccessBanner(message: Localized.tr("ingest.success"))
                .padding(.horizontal)
        }
    }

    private var smartIngestToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $useSmartIngest) {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile.fill")
                        .foregroundStyle(.wikiAccent)
                    Text(Localized.tr("ingest.smartToggle"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.wikiText)
                }
            }
            .tint(.wikiAccent)
            .accessibilityIdentifier("智能导入")

            if useSmartIngest {
                Text(Localized.tr("ingest.smartToggleHint"))
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
            }
        }
        .wikiCard()
        .padding(.horizontal)
    }

    private var pageTypeSelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Localized.tr("ingest.field.type"))
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
            Text(Localized.tr("ingest.field.icon"))
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
                    Text(newCustomIcon != nil ? Localized.tr("ingest.iconCustom") : Localized.tr("ingest.iconDefault"))
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
                    Text(Localized.tr("ingest.iconReset"))
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
                    Text(Localized.tr("ingest.suggestLinks"))
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
            Text(Localized.tr("ingest.tips"))
                .font(.headline)
                .foregroundStyle(.wikiText)

            WikiStepRow(number: 1, text: Localized.tr("ingest.tip1"))
            WikiStepRow(number: 2, text: Localized.tr("ingest.tip2"))
            WikiStepRow(number: 3, text: Localized.tr("ingest.tip3"))
            WikiStepRow(number: 4, text: Localized.tr("ingest.tip4"))
            WikiStepRow(number: 5, text: Localized.tr("ingest.tip5"))
        }
        .wikiCard()
        .padding(.horizontal)
    }
}
