import Foundation
import PDFKit
import UIKit
import WebKit
import CoreImage.CIFilterBuiltins

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
    
    // MARK: - Watermark Logic
    
    func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        
        if let outputImage = filter.outputImage {
            // Scale up the QR code to be sharp
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        return nil
    }
    
    func createWatermarkedPDF(from url: URL) -> URL? {
        guard let document = PDFDocument(url: url) else { return nil }
        
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, .zero, nil)
        
        let qrCodeImage = generateQRCode(from: "https://apps.apple.com/app/id6756200466")
        
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            
            let pageBounds = page.bounds(for: .mediaBox)
            let rotation = page.rotation
            
            // Determine visual dimensions
            let isLandscape = (rotation == 90 || rotation == 270)
            let visualWidth = isLandscape ? pageBounds.height : pageBounds.width
            let visualHeight = isLandscape ? pageBounds.width : pageBounds.height
            
            // Add extra height for footer to avoid covering content
            let footerHeight: CGFloat = 80
            let totalHeight = visualHeight + footerHeight
            
            let newBounds = CGRect(x: 0, y: 0, width: visualWidth, height: totalHeight)
            
            UIGraphicsBeginPDFPageWithInfo(newBounds, nil)
            
            guard let context = UIGraphicsGetCurrentContext() else { continue }
            
            // 1. Draw Original Page (Top Section)
            context.saveGState()
            
            // CRITICAL FIX: Force Coordinate Flip
            // We want to draw the page content in the top part: (0, 0) to (visualWidth, visualHeight)
            // In our flipped coordinate system (Top-Left 0,0), this is naturally at the top.
            
            // Flip Y axis to match UIKit coordinates (Top-Left 0,0)
            // Note: We translate by totalHeight because that's the full page height now.
            context.translateBy(x: 0.0, y: totalHeight)
            context.scaleBy(x: 1.0, y: -1.0)
            
            // Now (0,0) is Top-Left.
            // We want to draw the page content.
            // Since we increased the page height, we need to decide where to put the content.
            // We want it at the TOP.
            // In Top-Left coords, Top is Y=0.
            
            // Handle rotation manually
            switch rotation {
            case 0:
                context.translateBy(x: 0, y: 0)
            case 90:
                context.rotate(by: -.pi / 2)
                context.translateBy(x: -visualHeight, y: 0)
            case 180:
                context.rotate(by: .pi)
                context.translateBy(x: -visualWidth, y: -visualHeight)
            case 270:
                context.rotate(by: .pi / 2)
                context.translateBy(x: 0, y: -visualWidth)
            default:
                break
            }
            
            page.draw(with: .mediaBox, to: context)
            context.restoreGState()
            
            // 2. Draw Watermark (Footer Section)
            // We draw this in the standard PDF coordinate system (Bottom-Left 0,0)
            // because we restored the GState.
            // In PDF coords (Bottom-Left 0,0), the "Bottom" of our visual page is actually Y=0.
            // Since we extended the height, the "Footer" is the bottom-most part, which is Y=0 to Y=footerHeight.
            // The original content is above it, from Y=footerHeight to Y=totalHeight.
            
            // Wait, let's double check the flip logic above.
            // We did: translate(0, totalHeight) then scale(1, -1).
            // This maps PDF(0,0) [Bottom-Left] to UIKit(0, totalHeight) [Visual Bottom].
            // And PDF(0, totalHeight) [Top-Left] to UIKit(0, 0) [Visual Top].
            
            // So if we draw the page at (0,0) in the flipped context, it appears at the Visual Top. Correct.
            
            // 2. Draw Watermark (Footer Section)
            // We need to be careful about coordinates.
            // We restored GState, so we are back to the PDF Context's default coordinate system.
            // BUT, UIGraphicsBeginPDFPageWithInfo creates a context where (0,0) is Bottom-Left.
            
            // However, we observed that drawing at (0,0) resulted in the watermark being at the TOP.
            // This implies that despite our manual flip for the page content, the context itself might
            // be behaving differently than standard PDF coords, OR our understanding of "Visual Top" was inverted.
            
            // If (0,0) resulted in Top, then the coordinate system is likely Top-Left (0,0) by default in this context
            // (which is standard for UIGraphics contexts, even PDF ones, on iOS).
            // If so, Y increases downwards.
            
            // If (0,0) is Top, then to draw at the Bottom, we need Y = totalHeight - footerHeight.
            
            context.saveGState()
            
            // Draw at the bottom
            let footerY = totalHeight - footerHeight
            let footerRect = CGRect(x: 0, y: footerY, width: visualWidth, height: footerHeight)
            
            // White background for footer
            UIColor.white.setFill()
            context.fill(footerRect)
            
            // Separator line (at the top of the footer)
            let linePath = UIBezierPath()
            linePath.move(to: CGPoint(x: 0, y: footerY))
            linePath.addLine(to: CGPoint(x: visualWidth, y: footerY))
            linePath.lineWidth = 1
            UIColor.lightGray.withAlphaComponent(0.3).setStroke()
            linePath.stroke()
            
            // Text
            let text = "Scan & Edit with FoxioAI"
            let font = UIFont.systemFont(ofSize: 16, weight: .bold)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.gray
            ]
            let attributedText = NSAttributedString(string: text, attributes: attributes)
            let textSize = attributedText.size()
            
            let textX = (visualWidth - textSize.width) / 2
            let textY = footerY + (footerHeight - textSize.height) / 2
            attributedText.draw(at: CGPoint(x: textX, y: textY))
            
            // QR Code
            if let qr = qrCodeImage {
                let qrSize: CGFloat = 44
                let qrX = visualWidth - qrSize - 20
                let qrY = footerY + (footerHeight - qrSize) / 2
                qr.draw(in: CGRect(x: qrX, y: qrY, width: qrSize, height: qrSize))
            }
            
            context.restoreGState()
        }
        
        UIGraphicsEndPDFContext()
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("FoxioAI_Export_\(Int(Date().timeIntervalSince1970)).pdf")
        
        do {
            try pdfData.write(to: tempURL, options: .atomic)
            return tempURL
        } catch {
            print("Failed to save watermarked PDF: \(error)")
            return nil
        }
    }
    
    func createWatermarkedImage(from image: UIImage) -> UIImage? {
        let qrCodeImage = generateQRCode(from: "https://apps.apple.com/app/id6756200466")
        let footerHeight: CGFloat = 80 // Increased footer height for images
        
        let newSize = CGSize(width: image.size.width, height: image.size.height + footerHeight)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { ctx in
            // Fill background
            UIColor.white.set()
            ctx.fill(CGRect(origin: .zero, size: newSize))
            
            // Draw Original Image at top
            image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
            
            // Draw Footer Content
            // Note: In UIGraphicsImageRenderer (UIKit), (0,0) is Top-Left.
            // So footer is at y = image.height
            
            let footerRect = CGRect(x: 0, y: image.size.height, width: image.size.width, height: footerHeight)
            
            // Text
            let text = "Scan & Edit with FoxioAI"
            let font = UIFont.systemFont(ofSize: 32, weight: .bold) // Much larger font for high-res images
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.gray
            ]
            let attributedText = NSAttributedString(string: text, attributes: attributes)
            let textSize = attributedText.size()
            
            let textX = (image.size.width - textSize.width) / 2
            let textY = image.size.height + (footerHeight - textSize.height) / 2
            attributedText.draw(at: CGPoint(x: textX, y: textY))
            
            // QR Code
            if let qr = qrCodeImage {
                let qrSize: CGFloat = 60 // Larger QR code
                let qrX = image.size.width - qrSize - 40
                let qrY = image.size.height + (footerHeight - qrSize) / 2
                qr.draw(in: CGRect(x: qrX, y: qrY, width: qrSize, height: qrSize))
            }
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
                details += """
• Document is encrypted (Good for privacy).
"""
            } else {
                details += """
• Document is not encrypted.
"""
                // Not a threat, but a note
            }
            
            // 2. Check Metadata
            if let attributes = document.documentAttributes {
                if let author = attributes[PDFDocumentAttribute.authorAttribute] as? String {
                    details += """
• Author: \(author)
"""
                }
                if let creator = attributes[PDFDocumentAttribute.creatorAttribute] as? String {
                    details += """
• Creator: \(creator)
"""
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
                        details += """
⚠️ Found embedded JavaScript. This can be used for malicious actions.
"""
                        score -= 30
                    }
                    
                    if content.contains("/OpenAction") || content.contains("/AA") {
                        threats.append("Auto-Run Actions")
                        details += """
⚠️ Found Auto-Run Actions. The document may execute commands upon opening.
"""
                        score -= 20
                    }
                    
                    if content.contains("/Launch") {
                        threats.append("Launch Command")
                        details += """
⚠️ Found Launch Command. The document may try to open external applications.
"""
                        score -= 40
                    }
                    
                    if content.contains("/URI") {
                        details += """
ℹ️ Contains External Links.
"""
                    }
                }
            } else {
                details += """
• File too large for deep script scanning.
"""
            }
            
        } catch {
            print("Failed to read file for scanning: \(error)")
            details += """
• Could not perform deep scan.
"""
        }
        
        if threats.isEmpty {
            details += """

✅ No active threats detected.
"""
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
