import Foundation
import SwiftData
import PDFKit

// Since we might want to persist data later, we can prepare a model. 
// For now, let's just use a simple struct for runtime state.

struct ScannedItem: Identifiable, Hashable {
    let id = UUID()
    let creationDate: Date
    var name: String
    var pageCount: Int
    var url: URL? // Location of the saved PDF
    var isLocked: Bool = false
    
    init(name: String, url: URL? = nil, pageCount: Int = 0, isLocked: Bool = false) {
        self.creationDate = Date()
        self.name = name
        self.url = url
        self.pageCount = pageCount
        self.isLocked = isLocked
    }
}
