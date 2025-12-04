import SwiftUI
import PDFKit
import VisionKit

struct PDFPageEditorView: View {
    let document: PDFDocument
    @Environment(\.dismiss) var dismiss
    
    @State private var isShowingScanner = false
    @State private var pages: [PDFPage] = []
    @State private var editMode: EditMode = .inactive
    
    var body: some View {
        NavigationStack {
            Group {
                if pages.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No pages found")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                } else {
                    List {
                        ForEach(0..<pages.count, id: \.self) { index in
                            HStack(spacing: 16) {
                                // Thumbnail
                                let page = pages[index]
                                let thumbnail = page.thumbnail(of: CGSize(width: 60, height: 80), for: .mediaBox)
                                Image(uiImage: thumbnail)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 60, height: 80)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(4)
                                    .shadow(radius: 1)
                                
                                Text("Page \(index + 1)")
                                    .font(.headline)
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .onMove(perform: movePages)
                        .onDelete(perform: deletePages)
                    }
                }
            }
            .navigationTitle("Page Manager")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
                
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        isShowingScanner = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Page")
                        }
                        .font(.title2)
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .sheet(isPresented: $isShowingScanner) {
                ScannerView(didFinishScanning: { result in
                    switch result {
                    case .success(let images):
                        addImagesToDocument(images)
                    case .failure(let error):
                        print("Scanning failed: \(error.localizedDescription)")
                    }
                    isShowingScanner = false
                }, didCancelScanning: {
                    isShowingScanner = false
                })
            }
            .onAppear {
                loadPages()
            }
        }
    }
    
    func loadPages() {
        var newPages: [PDFPage] = []
        for i in 0..<document.pageCount {
            if let page = document.page(at: i) {
                newPages.append(page)
            }
        }
        pages = newPages
    }
    
    func movePages(from source: IndexSet, to destination: Int) {
        // Update local state
        pages.move(fromOffsets: source, toOffset: destination)
        
        // Update PDF Document
        // We need to be careful here. The easiest way is to reconstruct the document order.
        // But removing and inserting is tricky because indices shift.
        // Actually, since we have the `pages` array in the new order,
        // we can just re-construct the PDF document logic?
        // No, that's heavy.
        
        // Better approach:
        // 1. Get the pages that are moving.
        // 2. Remove them from document.
        // 3. Insert them at new index.
        
        // However, `PDFDocument` operations are immediate.
        // Let's try to map the move operation.
        
        // To avoid index confusion, let's just rebuild the document page order?
        // No, that might lose annotations if not careful (though PDFPage retains them).
        
        // Let's do it step by step based on the move.
        // SwiftUI's `move` is complex.
        
        // Alternative:
        // Since `pages` array is already updated by `pages.move(...)`,
        // we can just iterate through `pages` and ensure `document` matches.
        // But `document` is the source of truth.
        
        // Let's use a temporary document approach to be safe?
        // Or just remove all pages from document and re-insert them from `pages` array?
        // This is safe because `PDFPage` objects are retained in `pages` array.
        
        // Remove all pages
        while document.pageCount > 0 {
            document.removePage(at: 0)
        }
        
        // Re-insert in new order
        for (index, page) in pages.enumerated() {
            document.insert(page, at: index)
        }
    }
    
    func deletePages(at offsets: IndexSet) {
        // Update local state
        pages.remove(atOffsets: offsets)
        
        // Update PDF Document
        // Since we have indices, we can just remove from document?
        // But we must remove in descending order to avoid index shifts.
        // AND we must use the indices relative to the *current* document state.
        // Since `pages` and `document` were synced before this call, the indices in `offsets` should match `document`.
        
        for index in offsets.sorted(by: >) {
            document.removePage(at: index)
        }
    }
    
    func addImagesToDocument(_ images: [UIImage]) {
        let insertIndex = document.pageCount
        
        for (index, image) in images.enumerated() {
            if let page = PDFPage(image: image) {
                document.insert(page, at: insertIndex + index)
            }
        }
        
        // Reload pages
        loadPages()
    }
}
