import SwiftUI
import Vision
import PhotosUI

// MARK: - OCR Service
class OCRService {
    static let shared = OCRService()
    
    /// Recognize text from a UIImage
    func recognizeText(from image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let cgImage = image.cgImage else {
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
    func recognizeText(from image: UIImage) async throws -> String {
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
enum OCRError: LocalizedError {
    case invalidImage
    case noResults
    case cameraUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidImage: return L.tr("ocr.error.invalidImage")
        case .noResults: return L.tr("ocr.error.noResults")
        case .cameraUnavailable: return L.tr("ocr.error.cameraUnavailable")
        }
    }
}
