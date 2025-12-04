import Foundation
import PDFKit
import UIKit
import WebKit

struct SecurityScanResult {
    let isSafe: Bool
    let threats: [String]
    let details: String
    let score: Int // 0-100, 100 is safest
}

class FoxPDFManager {
    static let shared = FoxPDFManager()
    
    private init() {}
    
    func createPDF(from images: [UIImage], filename: String = "ScannedDocument") -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let uniqueFilename = "\(filename)_\(Int(Date().timeIntervalSince1970)).pdf"
        let fileURL = documentsDirectory.appendingPathComponent(uniqueFilename)
        
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, .zero, nil)
        
        for image in images {
            // Create a page with the exact size of the image
            let pageBounds = CGRect(origin: .zero, size: image.size)
            UIGraphicsBeginPDFPageWithInfo(pageBounds, nil)
            
            // Draw the image into the full page bounds
            image.draw(in: pageBounds)
        }
        
        UIGraphicsEndPDFContext()
        
        do {
            try pdfData.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            print("Error saving PDF: \(error)")
            return nil
        }
    }
    
    // For when we implement file import (convert imported PDF to our internal storage if needed, or just return URL)
    func copyFileToDocuments(from sourceURL: URL) -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let destinationURL = documentsDirectory.appendingPathComponent(sourceURL.lastPathComponent)
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            print("Error copying file: \(error)")
            return nil
        }
    }
    
    func mergePDFs(urls: [URL], filename: String = "MergedDocument") -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let uniqueFilename = "\(filename)_\(Int(Date().timeIntervalSince1970)).pdf"
        let destinationURL = documentsDirectory.appendingPathComponent(uniqueFilename)
        
        let mergedDocument = PDFDocument()
        var pageIndex = 0
        
        for url in urls {
            if let sourceDocument = PDFDocument(url: url) {
                for i in 0..<sourceDocument.pageCount {
                    if let page = sourceDocument.page(at: i) {
                        mergedDocument.insert(page, at: pageIndex)
                        pageIndex += 1
                    }
                }
            }
        }
        
        if mergedDocument.write(to: destinationURL) {
            return destinationURL
        } else {
            return nil
        }
    }
    
    @MainActor
    func convertOfficeDocToPDF(sourceURL: URL, filename: String) async -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let uniqueFilename = "\(filename)_\(Int(Date().timeIntervalSince1970)).pdf"
        let destinationURL = documentsDirectory.appendingPathComponent(uniqueFilename)
        
        let converter = WebViewConverter()
        do {
            return try await converter.convert(sourceURL: sourceURL, outputURL: destinationURL, fileExtension: sourceURL.pathExtension)
        } catch {
            print("Conversion failed: \(error)")
            return nil
        }
    }
    
    func images(from pdfURL: URL) -> [UIImage] {
        guard let document = PDFDocument(url: pdfURL) else { return [] }
        // If locked, we can't extract images without password. 
        // For now, assume caller handles unlocking or we return empty if locked.
        if document.isLocked { return [] }
        
        var images: [UIImage] = []
        
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            let pageRect = page.bounds(for: .mediaBox)
            let renderer = UIGraphicsImageRenderer(size: pageRect.size)
            let image = renderer.image { ctx in
                UIColor.white.set()
                ctx.fill(pageRect)
                ctx.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
                ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }
            images.append(image)
        }
        return images
    }
    
    func encryptPDF(url: URL, password: String) -> Bool {
        guard let document = PDFDocument(url: url) else { return false }
        
        // If already locked, we might want to unlock first? 
        // Or just overwrite with new password. 
        // But usually we encrypt a non-encrypted file.
        
        let options: [PDFDocumentWriteOption: Any] = [
            .userPasswordOption: password,
            .ownerPasswordOption: password // Set both for simplicity
        ]
        
        return document.write(to: url, withOptions: options)
    }
    
    func decryptPDF(url: URL, password: String) -> Bool {
        guard let document = PDFDocument(url: url) else { return false }
        
        if document.isLocked {
            if !document.unlock(withPassword: password) {
                return false // Wrong password
            }
        }
        
        // Write back without password options to remove encryption
        return document.write(to: url)
    }
    
    // MARK: - Security Scan
    
    func scanPDF(url: URL) async -> SecurityScanResult {
        var threats: [String] = []
        var details = ""
        var score = 100
        
        // 1. Check Encryption
        if let document = PDFDocument(url: url) {
            if document.isLocked {
                details += "• Document is encrypted (Good for privacy).\n"
            } else {
                details += "• Document is not encrypted.\n"
                // Not a threat, but a note
            }
            
            // 2. Check Metadata
            if let attributes = document.documentAttributes {
                if let author = attributes[PDFDocumentAttribute.authorAttribute] as? String {
                    details += "• Author: \(author)\n"
                }
                if let creator = attributes[PDFDocumentAttribute.creatorAttribute] as? String {
                    details += "• Creator: \(creator)\n"
                }
            }
        }
        
        // 3. Deep Scan for Malicious Keywords in Raw Data
        // We read the file as data/string to find PDF keywords that might indicate scripts.
        // Note: This is a heuristic scan.
        do {
            let data = try Data(contentsOf: url)
            // Convert a portion of data to string for searching (searching huge files might be slow, but PDF keywords are usually ASCII)
            // We use a lossy conversion or just search data directly.
            // For simplicity and performance on mobile, let's search the first 1MB and last 1MB if file is huge, or whole file if small.
            
            // Simple approach: Search in the whole file if < 10MB
            if data.count < 10 * 1024 * 1024 {
                if let content = String(data: data, encoding: .ascii) {
                    if content.contains("/JavaScript") || content.contains("/JS") {
                        threats.append("Contains JavaScript")
                        details += "⚠️ Found embedded JavaScript. This can be used for malicious actions.\n"
                        score -= 30
                    }
                    
                    if content.contains("/OpenAction") || content.contains("/AA") {
                        threats.append("Auto-Run Actions")
                        details += "⚠️ Found Auto-Run Actions. The document may execute commands upon opening.\n"
                        score -= 20
                    }
                    
                    if content.contains("/Launch") {
                        threats.append("Launch Command")
                        details += "⚠️ Found Launch Command. The document may try to open external applications.\n"
                        score -= 40
                    }
                    
                    if content.contains("/URI") {
                        details += "ℹ️ Contains External Links.\n"
                    }
                }
            } else {
                details += "• File too large for deep script scanning.\n"
            }
            
        } catch {
            print("Failed to read file for scanning: \(error)")
            details += "• Could not perform deep scan.\n"
        }
        
        if threats.isEmpty {
            details += "\n✅ No active threats detected."
        }
        
        return SecurityScanResult(isSafe: threats.isEmpty, threats: threats, details: details, score: score)
    }
}

class WebViewConverter: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var continuation: CheckedContinuation<URL?, Error>?
    private var outputURL: URL?
    
    @MainActor
    func convert(sourceURL: URL, outputURL: URL, fileExtension: String) async throws -> URL? {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.outputURL = outputURL
            
            // Determine initial frame based on file type to prevent layout squeezing
            let landscapeExtensions = ["ppt", "pptx", "pps", "ppsx", "pot", "potx", "pptm", "potm", "ppsm", "thmx", "xls", "xlsx", "xlt", "xltx", "xlsm", "xltm"]
            let isLandscapeDefault = landscapeExtensions.contains(fileExtension.lowercased())
            
            // Use a large enough frame to prevent mobile-view squeezing
            // Landscape: 1920x1080 (Full HD) - Standard presentation size
            // Portrait: 1024x1366 (iPad Pro Portrait) - Standard tablet size
            let frame = isLandscapeDefault ? CGRect(x: 0, y: 0, width: 1920, height: 1080) : CGRect(x: 0, y: 0, width: 1024, height: 1366)
            
            let webView = WKWebView(frame: frame)
            // Fix grey border by ensuring white background
            webView.isOpaque = false
            webView.backgroundColor = .white
            webView.scrollView.backgroundColor = .white
            
            webView.navigationDelegate = self
            self.webView = webView
            webView.loadFileURL(sourceURL, allowingReadAccessTo: sourceURL.deletingLastPathComponent())
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Inject CSS to:
        // 1. Force background printing (fix missing background colors)
        // 2. Disable text size adjustment (fix text squeezing/overlapping)
        let css = "body { -webkit-print-color-adjust: exact !important; print-color-adjust: exact !important; -webkit-text-size-adjust: none !important; }"
        let js = "var style = document.createElement('style'); style.innerHTML = '\(css)'; document.head.appendChild(style);"
        
        webView.evaluateJavaScript(js) { _, _ in
            // Give a small delay to ensure layout is complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.createLongPDFAndSlice(webView: webView)
            }
        }
    }
    
    private func createLongPDFAndSlice(webView: WKWebView) {
        let config = WKPDFConfiguration()
        // We don't set rect here, letting it capture the full scrollable content
        
        webView.createPDF(configuration: config) { result in
            switch result {
            case .success(let data):
                // Directly save the "Long PDF" (single page) without slicing
                // This preserves the original layout and avoids cutting issues
                do {
                    if let url = self.outputURL {
                        try data.write(to: url, options: .atomic)
                        self.continuation?.resume(returning: url)
                    } else {
                        self.continuation?.resume(returning: nil)
                    }
                } catch {
                    self.continuation?.resume(throwing: error)
                }
                
            case .failure(let error):
                self.continuation?.resume(throwing: error)
            }
            self.webView = nil
        }
    }
    
    private func sliceLongPDF(data: Data) -> Data? {
        guard let document = PDFDocument(data: data),
              let page = document.page(at: 0) else { return nil }
        
        let pageBounds = page.bounds(for: .mediaBox)
        let width = pageBounds.width
        let height = pageBounds.height
        
        // Determine orientation based on width
        // Standard A4 width is ~595. If width is much larger (e.g. > 800), assume Landscape intent
        let isLandscape = width > 800
        
        // Target A4 size (for aspect ratio calculation)
        let a4Width: CGFloat = 595.2
        let a4Height: CGFloat = 841.8
        
        // Smart Slice Height Detection
        // PPTs usually have standard aspect ratios (16:9 or 4:3)
        // If the total height is a multiple of these slide heights, we should use that to avoid cutting slides in half.
        
        let h16_9 = width * 9.0 / 16.0
        let h4_3 = width * 3.0 / 4.0
        
        func isMultiple(total: CGFloat, unit: CGFloat) -> Bool {
            let count = round(total / unit)
            if count == 0 { return false }
            let expected = count * unit
            let diff = abs(total - expected)
            // 5% tolerance for gaps/rendering differences
            return diff < (unit * 0.05)
        }
        
        let sliceHeight: CGFloat
        
        if isMultiple(total: height, unit: h16_9) {
            // It's likely a 16:9 PPT
            // Adjust slice height to exactly match the division
            let count = round(height / h16_9)
            sliceHeight = height / count
        } else if isMultiple(total: height, unit: h4_3) {
            // It's likely a 4:3 PPT
            let count = round(height / h4_3)
            sliceHeight = height / count
        } else {
            // Fallback to A4 logic for Word/Text or non-standard PPTs
            if isLandscape {
                // Landscape A4 Ratio: Height / Width = 595.2 / 841.8
                sliceHeight = width * (a4Width / a4Height)
            } else {
                // Portrait A4 Ratio: Height / Width = 841.8 / 595.2
                sliceHeight = width * (a4Height / a4Width)
            }
        }
        
        let numberOfPages = Int(ceil(height / sliceHeight))
        let outputDocument = PDFDocument()
        
        for i in 0..<numberOfPages {
            // Create a copy of the original page
            // Note: PDFPage.copy() is not directly available as a method that returns PDFPage in all versions,
            // but PDFPage conforms to NSCopying.
            guard let newPage = page.copy() as? PDFPage else { continue }
            
            // Calculate the crop rectangle for this slice
            // PDF Coordinates: (0,0) is bottom-left.
            // Top of document is y = height.
            // Slice 0 (Top) is from [height - sliceHeight] to [height]
            // Slice i is from [height - (i+1)*sliceHeight] to [height - i*sliceHeight]
            
            let y = height - CGFloat(i + 1) * sliceHeight
            // Ensure y doesn't go below 0 (for the last page)
            let adjustedY = max(0, y)
            let adjustedHeight = (y < 0) ? (sliceHeight + y) : sliceHeight
            
            let cropRect = CGRect(x: 0, y: adjustedY, width: width, height: adjustedHeight)
            
            // Set the MediaBox (physical page size) to the crop rect
            // This effectively "crops" the page to this view
            newPage.setBounds(cropRect, for: .mediaBox)
            
            // Also set CropBox to be safe
            newPage.setBounds(cropRect, for: .cropBox)
            
            // Insert into output document
            outputDocument.insert(newPage, at: i)
        }
        
        return outputDocument.dataRepresentation()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        self.webView = nil
    }
}
