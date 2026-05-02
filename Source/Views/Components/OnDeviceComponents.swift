import SwiftUI

// MARK: - On-Device Test View
struct OnDeviceTestView: View {
    @ObservedObject var onDeviceService: OnDeviceLLMService
    @Environment(\.dismiss) private var dismiss
    @State private var prompt = ""
    @State private var result = ""
    @State private var isGenerating = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                promptInputSection
                generateButton
                progressIndicator
                resultSection
                Spacer()
            }
            .padding()
            .background(Color.wikiBackground)
            .navigationTitle(Localized.tr("ondevice.test"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Prompt Input
    private var promptInputSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Localized.tr("ondevice.testPrompt"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.wikiSecondary)
            
            TextEditor(text: $prompt)
                .font(.body)
                .frame(height: 80)
                .padding(8)
                .background(Color.wikiCard)
                .clipShape(RoundedRectangle(cornerRadius: WikiUI.standardRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: WikiUI.standardRadius)
                        .strokeBorder(Color.wikiAccent.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    // MARK: - Generate Button
    private var generateButton: some View {
        Button(action: generate) {
            HStack {
                if isGenerating {
                    ProgressView()
                        .tint(.white)
                }
                Text(isGenerating ? Localized.tr("ondevice.generating") : Localized.tr("ondevice.generate"))
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isGenerating ? Color.wikiSecondary : Color.wikiAccent)
            .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
        }
        .disabled(isGenerating || prompt.isEmpty)
    }
    
    // MARK: - Progress
    @ViewBuilder
    private var progressIndicator: some View {
        if isGenerating {
            ProgressView(value: onDeviceService.generationProgress)
                .tint(.wikiAccent)
        }
    }
    
    // MARK: - Result
    @ViewBuilder
    private var resultSection: some View {
        if !result.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(Localized.tr("ondevice.result"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.wikiSecondary)
                    Spacer()
                    Button(action: { WikiPasteboard.string = result }) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundStyle(.wikiAccent)
                    }
                }
                
                ScrollView {
                    Text(result)
                        .font(.body)
                        .foregroundStyle(.wikiText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 300)
                .padding()
                .background(Color.wikiCard)
                .clipShape(RoundedRectangle(cornerRadius: WikiUI.standardRadius))
            }
        }
    }
    
    // MARK: - Generate
    private func generate() {
        isGenerating = true
        result = ""
        
        Task {
            do {
                let generated = try await onDeviceService.generate(prompt: prompt, maxTokens: 128)
                result = generated
            } catch {
                result = "\(Localized.tr("misc.error")): \(error.localizedDescription)"
            }
            isGenerating = false
        }
    }
}

// MARK: - On-Device Model Row
struct OnDeviceModelRow: View {
    let model: OnDeviceModel
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: model.icon)
                .font(.title3)
                .foregroundStyle(.wikiAccent)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(model.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.wikiText)
                
                HStack(spacing: 8) {
                    if model.size > 0 {
                        Text(model.sizeLabel)
                            .font(.caption2)
                    }
                    Text(model.type == .system ? Localized.tr("ondevice.system") : Localized.tr("ondevice.local"))
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.wikiAccent.opacity(0.1))
                        .clipShape(Capsule())
                }
                .foregroundStyle(.wikiSecondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: WikiUI.cardRadius)
                .fill(isSelected ? Color.wikiAccent.opacity(0.08) : Color.wikiCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: WikiUI.cardRadius)
                .strokeBorder(isSelected ? Color.wikiAccent.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .onTapGesture { onSelect() }
    }
}
