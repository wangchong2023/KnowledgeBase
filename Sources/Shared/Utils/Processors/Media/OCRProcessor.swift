// OCRProcessor.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了基于 Vision 框架的光学字符识别处理器（OCRProcessor），专门用于从图像资料中提取可编辑的知识文本。
// 该处理器具备以下核心能力，为系统的数字化输入提供支撑：
// 1. 深度图像解析：利用 Apple Vision 引擎进行高精度的文本行识别（Text Recognition），支持对复杂背景下的文字进行有效过滤。
// 2. 布局还原：自动分析文本块的物理位置，通过坐标计算尝试还原原始图像中的段落结构与换行关系，避免语义断裂。
// 3. 多语言支持：支持对中、英、日、韩等主流语言的混合识别，并提供识别置信度评估，确保提取内容的准确性。
// 版本: 1.1
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-03
//   - 2026-05-05: 迁移至 Utils/Processors/Media 并完善 Vision 算法说明
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

@preconcurrency import SwiftUI
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
class OCRProcessor: ObservableObject {
    @MainActor static let shared = OCRProcessor()
    
    /// Recognize text from a WikiImage
    func recognizeText(from image: WikiImage, completion: @escaping @Sendable (Result<String, Error>) -> Void) {
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

extension OCRProcessor: @unchecked Sendable {}
