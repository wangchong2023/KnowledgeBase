import SwiftUI
@preconcurrency import Vision
import PhotosUI

// MARK: - OCR Service

/// OCR 文字识别服务
///
/// 利用 Vision 框架对图像进行文字识别，支持中文（简体/繁体）、英文、日文、韩文等多种语言。
/// 采用 accurate 识别级别和语言纠正，以获得更高的识别准确率。
///
/// ## 主要功能
/// - 从 UIImage 中提取文字
/// - 支持异步回调和 async/await 两种调用方式
/// - 多语言自动检测（简体中文、繁体中文、英文、日文、韩文）
///
/// ## 使用方式
/// ```swift
/// // 异步回调方式
/// ocrService.recognizeText(from: image) { result in
///     if case .success(let text) = result {
///         print(text)
///     }
/// }
///
/// // async/await 方式
/// let text = try await ocrService.recognizeText(from: image)
/// ```
@MainActor
class OCRService: ObservableObject {
    static let shared = OCRService()
    
    /// Recognize text from a WikiImage
    func recognizeText(from image: WikiImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let cgImage = image.wikiCGImage else {
            completion(.failure(OCRError.invalidImage))
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.failure(OCRError.noResults))
                return
            }
            
            let text = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            completion(.success(text))
        }
        
        // Support Chinese + English + Japanese + Korean
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US", "ja", "ko"]
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    /// Synchronous version using async/await
    func recognizeText(from image: WikiImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            recognizeText(from: image) { result in
                switch result {
                case .success(let text):
                    continuation.resume(returning: text)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - OCR Error

/// OCR 服务错误类型
///
/// - invalidImage: 无法从 UIImage 获取有效的 CGImage
/// - noResults: 识别请求未返回任何结果
/// - cameraUnavailable: 相机不可用（当前未使用，保留扩展）
enum OCRError: LocalizedError {
    case invalidImage
    case noResults
    case cameraUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidImage: return Localized.tr("ocr.error.invalidImage")
        case .noResults: return Localized.tr("ocr.error.noResults")
        case .cameraUnavailable: return Localized.tr("ocr.error.cameraUnavailable")
        }
    }
}
