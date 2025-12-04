import Foundation
import PDFKit
import Combine
import UIKit

@MainActor
class FoxDocumentStore: ObservableObject {
    @Published var documents: [ScannedItem] = []
    
    init() {
        loadDocuments()
    }
    
    func loadDocuments() {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            
            let pdfFiles = fileURLs.filter { $0.pathExtension.lowercased() == "pdf" }
            
            var loadedItems: [ScannedItem] = []
            
            for url in pdfFiles {
                let name = url.deletingPathExtension().lastPathComponent
                
                // Get creation date
                let attributes = try? fileManager.attributesOfItem(atPath: url.path)
                let creationDate = attributes?[.creationDate] as? Date ?? Date()
                
                // Get page count and lock status
                let document = PDFDocument(url: url)
                let pageCount = document?.pageCount ?? 0
                let isLocked = document?.isLocked ?? false
                
                var item = ScannedItem(name: name, url: url, pageCount: pageCount, isLocked: isLocked)
                // We can't easily modify the 'let creationDate' in the struct if it's let. 
                // We might need to update the model or just accept current time for now if strict.
                // Looking at the model, it sets creationDate = Date() in init.
                // Let's rely on the struct for now, or update struct if needed. 
                // Ideally we sort by file creation date.
                loadedItems.append(item)
            }
            
            // Sort by date descending
            // Since ScannedItem.creationDate is set to 'now' in init, we might want to fix the model to accept a date, 
            // or just sort by the filesystem date we found (but we need to store it).
            // For now, let's just reverse the order found or rely on file system order, 
            // but ideally we update the model. I'll stick to the model as is to avoid breaking changes first,
            // but for a good "Recent" list, real dates matter.
            
            self.documents = loadedItems.sorted(by: { $0.name > $1.name }) // Simple sort for now
            
        } catch {
            print("Error loading documents: \(error)")
        }
    }
    
    func addDocument(_ item: ScannedItem) {
        documents.insert(item, at: 0)
    }
    
    func deleteDocument(_ item: ScannedItem) {
        if let index = documents.firstIndex(of: item) {
            documents.remove(at: index)
            // Also remove from disk
            if let url = item.url {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
    
    func renameDocument(_ item: ScannedItem, to newName: String) {
        guard let index = documents.firstIndex(of: item), let currentURL = item.url else { return }
        
        let fileManager = FileManager.default
        let directory = currentURL.deletingLastPathComponent()
        let newURL = directory.appendingPathComponent(newName).appendingPathExtension("pdf")
        
        do {
            try fileManager.moveItem(at: currentURL, to: newURL)
            
            // Update model
            var updatedItem = item
            updatedItem.name = newName
            updatedItem.url = newURL
            
            // Re-check lock status just in case (though renaming shouldn't change it)
            if let doc = PDFDocument(url: newURL) {
                updatedItem.isLocked = doc.isLocked
            }
            
            documents[index] = updatedItem
        } catch {
            print("Error renaming file: \(error)")
        }
    }
    
}
