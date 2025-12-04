import UIKit
import Vision

class OCRManager {
    static let shared = OCRManager()
    
    private init() {}
    
    func recognizeText(from image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let text = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                continuation.resume(returning: text)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            // Prioritize Chinese and English, but support others
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US", "fr-FR", "de-DE", "es-ES", "it-IT", "pt-BR"]
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    func recognizeText(from images: [UIImage]) async -> String {
        var fullText = ""
        for (index, image) in images.enumerated() {
            if let text = await recognizeText(from: image) {
                if index > 0 {
                    fullText += "\n\n--- Page \(index + 1) ---\n\n"
                }
                fullText += text
            }
        }
        return fullText
    }
}
