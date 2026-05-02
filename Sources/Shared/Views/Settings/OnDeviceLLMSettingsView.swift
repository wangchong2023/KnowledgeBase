@preconcurrency import SwiftUI
import UniformTypeIdentifiers

// MARK: - On-Device LLM Settings View
@MainActor
struct OnDeviceLLMSettingsView: View {
    @StateObject private var onDeviceService = OnDeviceLLMService()
    @Environment(KMStore.self) var store
    @State private var testPrompt = ""
    @State private var testResult = ""
    @State private var showImportPicker = false
    @State private var showTestSheet = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                availabilitySection
                modelSelectionSection
                modelManagementSection
                testSection
                infoSection
            }
            .padding()
        }
        .background(Color.wikiBackground)
        .navigationTitle(Localized.tr("ondevice.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showTestSheet) {
            OnDeviceTestView(onDeviceService: onDeviceService)
        }
        .alert(Localized.tr("ondevice.error.inferenceFailed"), isPresented: $showError) {
            Button(Localized.tr("misc.ok"), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "cpu.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.wikiSource, .wikiAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(Localized.tr("ondevice.subtitle"))
                .font(.subheadline)
                .foregroundStyle(.wikiSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 10)
    }
    
    // MARK: - Availability
    private var availabilitySection: some View {
        HStack(spacing: 12) {
            Image(systemName: onDeviceService.isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(onDeviceService.isAvailable ? .green : .red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(onDeviceService.isAvailable ? Localized.tr("ondevice.available") : Localized.tr("ondevice.unavailable"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.wikiText)
                
                if onDeviceService.isAvailable {
                    if #available(iOS 18.2, *) {
                        Text(Localized.tr("ondevice.supportsFoundation"))
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else if #available(iOS 17.0, *) {
                        Text(Localized.tr("ondevice.supportsCoreML"))
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                } else {
                    Text(Localized.tr("ondevice.requiresIOS17"))
                        .font(.caption)
                        .foregroundStyle(.wikiSecondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
    }
    
    // MARK: - Model Selection
    private var modelSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Localized.tr("ondevice.models"))
                .font(.headline)
                .foregroundStyle(.wikiText)
            
            if onDeviceService.availableModels.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "cube.box")
                        .font(.title2)
                        .foregroundStyle(.wikiSecondary)
                    Text(Localized.tr("ondevice.noModels"))
                        .font(.subheadline)
                        .foregroundStyle(.wikiSecondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.wikiCard)
                .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
            } else {
                ForEach(onDeviceService.availableModels) { model in
                    OnDeviceModelRow(
                        model: model,
                        isSelected: onDeviceService.selectedModelID == model.id,
                        onSelect: { onDeviceService.selectedModelID = model.id }
                    )
                }
            }
        }
    }
    
    // MARK: - Model Management
    private var modelManagementSection: some View {
        VStack(spacing: 12) {
            if onDeviceService.isModelLoaded {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("\(Localized.tr("ondevice.modelLoaded")): \(onDeviceService.loadedModelName)")
                        .font(.subheadline)
                        .foregroundStyle(.wikiText)
                    Spacer()
                    Button(Localized.tr("ondevice.unload")) {
                        onDeviceService.unloadModel()
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                }
                .padding()
                .background(Color.wikiAccent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
            } else {
                Button(action: loadModel) {
                    HStack {
                        if onDeviceService.isGenerating {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(Localized.tr("ondevice.loadModel"))
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.wikiAccent)
                    .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
                }
                .disabled(onDeviceService.selectedModelID.isEmpty)
            }
            
            Button(action: { showImportPicker = true }) {
                HStack {
                    Image(systemName: "square.and.arrow.down.fill")
                    Text(Localized.tr("ondevice.importModel"))
                }
                .font(.subheadline)
                .foregroundStyle(.wikiAccent)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.wikiAccent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: {
                    var types: [UTType] = []
                    if let ml = UTType(filenameExtension: "mlmodel") { types.append(ml) }
                    if let mlc = UTType(filenameExtension: "mlmodelc") { types.append(mlc) }
                    return types.isEmpty ? [.data] : types
                }(),
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        Task {
                            do {
                                try await onDeviceService.importModel(from: url)
                            } catch {
                                errorMessage = error.localizedDescription
                                showError = true
                            }
                        }
                    }
                case .failure:
                    break
                }
            }
        }
    }
    
    // MARK: - Test Section
    private var testSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Localized.tr("ondevice.test"))
                .font(.headline)
                .foregroundStyle(.wikiText)
            
            Button(action: { showTestSheet = true }) {
                HStack {
                    Image(systemName: "text.bubble.fill")
                    Text(Localized.tr("ondevice.testGeneration"))
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(onDeviceService.isModelLoaded ? Color.green : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
            }
            .disabled(!onDeviceService.isModelLoaded)
            
            if onDeviceService.inferenceSpeed > 0 {
                HStack {
                    Text(Localized.tr("ondevice.inferenceSpeed"))
                        .font(.caption)
                        .foregroundStyle(.wikiSecondary)
                    Spacer()
                    Text(String(format: "%.1f tok/s", onDeviceService.inferenceSpeed))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Info
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Localized.tr("ondevice.info"))
                .font(.headline)
                .foregroundStyle(.wikiText)
            
            InfoRow(icon: "lock.shield.fill", text: Localized.tr("ondevice.info.privacy"))
            InfoRow(icon: "wifi.slash", text: Localized.tr("ondevice.info.offline"))
            InfoRow(icon: "bolt.fill", text: Localized.tr("ondevice.info.ne"))
            InfoRow(icon: "memorychip", text: Localized.tr("ondevice.info.memory"))
        }
        .padding()
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
    }
    
    // MARK: - Actions
    private func loadModel() {
        Task {
            do {
                try await onDeviceService.loadModel()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
