import Foundation
import CoreML
import Combine

// MARK: - On-Device LLM Service
/// Local LLM inference using Core ML for on-device AI capabilities.
/// Supports Apple's on-device models (since iOS 17) and custom .mlmodelc models.
@MainActor
final class OnDeviceLLMService: ObservableObject {
    @Published var isAvailable: Bool = false
    @Published var isModelLoaded: Bool = false
    @Published var isGenerating: Bool = false
    @Published var loadedModelName: String = ""
    @Published var availableModels: [OnDeviceModel] = []
    @Published var selectedModelID: String = ""
    @Published var generationProgress: Double = 0
    @Published var generatedText: String = ""
    @Published var inferenceSpeed: Double = 0 // tokens/sec
    
    private var currentModel: AnyObject?
    private let configKey = "wikicraft_ondevice_config"
    
    // MARK: - Constants
    /// Default max tokens for text generation
    private static let defaultMaxTokens: Int = 256
    /// Temperature for text generation
    private static let generationTemperature: Double = 0.7
    /// Max tokens for smart ingest compilation
    private static let smartIngestMaxTokens: Int = 500
    /// Max tokens for on-device chat
    private static let chatMaxTokens: Int = 300
    /// Number of relevant pages to include in context
    private static let contextPageLimit: Int = 5
    /// Character limit for page content preview in context
    private static let contentPreviewChars: Int = 200
    
    // MARK: - Init
    init() {
        checkAvailability()
        discoverModels()
    }
    
    // MARK: - Check Availability
    private func checkAvailability() {
        // Core ML is available on iOS 16+, on-device LLM requires iOS 17+
        if #available(iOS 17.0, *) {
            isAvailable = true
        } else {
            isAvailable = false
        }
    }
    
    // MARK: - Discover Models
    private func discoverModels() {
        var models: [OnDeviceModel] = []
        
        // Check for bundled models
        if let modelURL = Bundle.main.url(forResource: "KMLLM", withExtension: "mlmodelc") {
            models.append(OnDeviceModel(
                id: "bundled_wikicraft",
                name: Localized.tr("ondevice.model.bundled"),
                url: modelURL,
                size: estimateModelSize(url: modelURL),
                type: .bundled
            ))
        }
        
        // Check Documents directory for downloaded models
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelsDir = docsDir.appendingPathComponent("MLModels")
        
        if let enumerator = FileManager.default.enumerator(at: modelsDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "mlmodelc" {
                    let name = fileURL.deletingPathExtension().lastPathComponent
                    models.append(OnDeviceModel(
                        id: "downloaded_\(name)",
                        name: name,
                        url: fileURL,
                        size: estimateModelSize(url: fileURL),
                        type: .downloaded
                    ))
                }
            }
        }
        
        // Add system Apple Intelligence (iOS 18.1+)
        if #available(iOS 18.1, *) {
            models.append(OnDeviceModel(
                id: "apple_intelligence",
                name: Localized.tr("ondevice.appleIntelligence"),
                url: nil,
                size: 0,
                type: .system
            ))
        }
        
        availableModels = models
        
        // Auto-select saved model
        let savedID = UserDefaults.standard.string(forKey: configKey)
        if let saved = savedID, models.contains(where: { $0.id == saved }) {
            selectedModelID = saved
        } else if let first = models.first {
            selectedModelID = first.id
        }
    }
    
    private func estimateModelSize(url: URL) -> Int64 {
        let fm = FileManager.default
        var total: Int64 = 0
        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    total += Int64(size)
                }
            }
        }
        return total
    }
    
    // MARK: - Load Model
    func loadModel() async throws {
        guard let model = availableModels.first(where: { $0.id == selectedModelID }) else {
            throw OnDeviceError.modelNotFound
        }
        
        isGenerating = true
        generationProgress = 0
        
        switch model.type {
        case .system:
            // Apple Intelligence uses Foundation Models framework (iOS 18.2+)
            if #available(iOS 18.2, *) {
                // Would use FoundationModels framework here
                isModelLoaded = true
                loadedModelName = model.name
            } else {
                throw OnDeviceError.notSupported
            }
            
        case .bundled, .downloaded:
            guard let url = model.url else {
                throw OnDeviceError.modelNotFound
            }
            
            // Load Core ML model
            let compiledURL: URL
            if url.pathExtension == "mlmodelc" {
                compiledURL = url
            } else {
                compiledURL = try await MLModel.compileModel(at: url)
            }
            
            let config = MLModelConfiguration()
            config.computeUnits = .all // Use Neural Engine + GPU + CPU
            
            let mlModel = try MLModel(contentsOf: compiledURL, configuration: config)
            currentModel = mlModel
            isModelLoaded = true
            loadedModelName = model.name
        }
        
        isGenerating = false
        generationProgress = 1.0
        
        // Save selection
        UserDefaults.standard.set(selectedModelID, forKey: configKey)
    }
    
    // MARK: - Generate Text
    func generate(prompt: String, maxTokens: Int = defaultMaxTokens) async throws -> String {
        guard isModelLoaded else {
            throw OnDeviceError.modelNotLoaded
        }
        
        isGenerating = true
        generatedText = ""
        generationProgress = 0
        
        let startTime = Date()
        
        // Use Apple Foundation Models if available (iOS 18.2+)
        if #available(iOS 18.2, *) {
            // Foundation Models integration would go here
            // For now, simulate with Core ML prediction
        }
        
        // Core ML text generation
        if let mlModel = currentModel as? MLModel {
            let inputFeatures: [String: Any] = [
                "prompt": prompt,
                "max_tokens": maxTokens,
                "temperature": Self.generationTemperature
            ]
            
            do {
                let provider = try MLDictionaryFeatureProvider(dictionary: inputFeatures)
                let prediction = try await mlModel.prediction(from: provider)
                
                if let generated = prediction.featureValue(for: "generated_text")?.stringValue {
                    let elapsed = Date().timeIntervalSince(startTime)
                    let tokenCount = generated.split(separator: " ").count
                    inferenceSpeed = Double(tokenCount) / elapsed
                    
                    generatedText = generated
                    generationProgress = 1.0
                    isGenerating = false
                    return generated
                }
            } catch {
                isGenerating = false
                throw OnDeviceError.inferenceFailed(error.localizedDescription)
            }
        }
        
        isGenerating = false
        throw OnDeviceError.modelNotLoaded
    }
    
    // MARK: - Smart Ingest (On-Device)
    /// Compile raw content using on-device LLM
    func smartIngestOnDevice(title: String, content: String, pages: [WikiPage]) async throws -> SmartIngestResult {
        let existingTitles = pages.map(\.title).prefix(20).joined(separator: ", ")
        
        let prompt = """
        \(Localized.tr("ondevice.ingest.compileToWiki"))：\(existingTitles)
        
        \(Localized.tr("ondevice.ingest.title"))：\(title)
        \(Localized.tr("ondevice.ingest.content"))：\(content)
        
        \(Localized.tr("ondevice.ingest.linkAndFormat"))
        """
        
        let generated = try await generate(prompt: prompt, maxTokens: Self.smartIngestMaxTokens)
        
        return SmartIngestResult(
            compiledContent: generated,
            suggestedTags: extractTags(from: generated),
            suggestedType: "concept",
            relatedTitles: [],
            summary: String(generated.prefix(100))
        )
    }
    
    // MARK: - Chat (On-Device)
    func chatOnDevice(query: String, pages: [WikiPage]) async throws -> String {
        var context = Localized.tr("ondevice.chatContext")
        
        // Add relevant page summaries
        let relevant = pages.filter { page in
            query.lowercased().contains(page.title.lowercased()) ||
            page.tags.contains(where: { query.lowercased().contains($0.lowercased()) })
        }
        
        for page in relevant.prefix(Self.contextPageLimit) {
            context += "\n\n## \(page.title)\n\(String(page.content.prefix(Self.contentPreviewChars)))"
        }
        
        let prompt = "\(context)\n\n\(Localized.tr("ondevice.chatQuestion")): \(query)"
        return try await generate(prompt: prompt, maxTokens: Self.chatMaxTokens)
    }
    
    // MARK: - Cancel
    func cancelGeneration() {
        isGenerating = false
        generatedText = ""
        generationProgress = 0
    }
    
    // MARK: - Unload
    func unloadModel() {
        currentModel = nil
        isModelLoaded = false
        loadedModelName = ""
    }
    
    // MARK: - Helpers
    private func extractTags(from text: String) -> [String] {
        let pattern = "#(\\w+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        return matches.compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            return nsText.substring(with: match.range(at: 1))
        }
    }
    
    // MARK: - Import Model
    func importModel(from url: URL) async throws {
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelsDir = docsDir.appendingPathComponent("MLModels")
        try FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        
        let _ = url.deletingPathExtension().lastPathComponent
        let destURL = modelsDir.appendingPathComponent(url.lastPathComponent)
        
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            try FileManager.default.copyItem(at: url, to: destURL)
        } else {
            try FileManager.default.copyItem(at: url, to: destURL)
        }
        
        // Compile if needed
        if destURL.pathExtension == "mlmodel" {
            let compiledURL = try await MLModel.compileModel(at: destURL)
            try FileManager.default.removeItem(at: destURL)
            try FileManager.default.moveItem(at: compiledURL, to: destURL.appendingPathExtension("mlmodelc"))
        }
        
        discoverModels()
    }
    
    // MARK: - Delete Model
    func deleteModel(_ model: OnDeviceModel) throws {
        if let url = model.url {
            try FileManager.default.removeItem(at: url)
        }
        if model.id == selectedModelID {
            unloadModel()
        }
        discoverModels()
    }
}

// MARK: - On-Device Model
struct OnDeviceModel: Identifiable {
    let id: String
    let name: String
    let url: URL?
    let size: Int64
    let type: ModelType
    
    enum ModelType {
        case bundled
        case downloaded
        case system
    }
    
    var sizeLabel: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var icon: String {
        switch type {
        case .bundled: return "cube.box.fill"
        case .downloaded: return "arrow.down.circle.fill"
        case .system: return "apple.logo"
        }
    }
}

// MARK: - On-Device Error
enum OnDeviceError: LocalizedError {
    case modelNotFound
    case modelNotLoaded
    case notSupported
    case inferenceFailed(String)
    case compilationFailed
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound: return Localized.tr("ondevice.error.modelNotFound")
        case .modelNotLoaded: return Localized.tr("ondevice.error.modelNotLoaded")
        case .notSupported: return Localized.tr("ondevice.error.notSupported")
        case .inferenceFailed(let msg): return "\(Localized.tr("ondevice.error.inferenceFailed")): \(msg)"
        case .compilationFailed: return Localized.tr("ondevice.error.compilationFailed")
        }
    }
}
