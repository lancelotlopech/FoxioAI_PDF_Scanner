import SwiftUI
import PDFKit
import VisionKit

struct PDFPageEditorView_Backup: View {
    let document: PDFDocument
    @Environment(\.dismiss) var dismiss
    
    @State private var isShowingScanner = false
    @State private var selectedPages: Set<PDFPage> = []
    @State private var refreshID = UUID() // Force refresh when needed
    
    var body: some View {
        NavigationStack {
            VStack {
                PDFThumbnailViewRepresentable_Backup(document: document, selectedPages: $selectedPages)
                    .id(refreshID) // Force redraw if needed
            }
            .navigationTitle("Page Manager")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Button(role: .destructive) {
                            deleteSelectedPages()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .disabled(selectedPages.isEmpty)
                        
                        Spacer()
                        
                        Button {
                            isShowingScanner = true
                        } label: {
                            Label("Add Page", systemImage: "plus.circle.fill")
                                .font(.title2)
                        }
                        
                        Spacer()
                        
                        // Placeholder for balance
                        Color.clear.frame(width: 40)
                    }
                }
            }
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
        }
    }
    
    func deleteSelectedPages() {
        // Sort by index descending to avoid index shifting issues
        let pagesToDelete = selectedPages.compactMap { document.index(for: $0) }.sorted(by: >)
        
        for index in pagesToDelete {
            document.removePage(at: index)
        }
        
        // Clear selection
        selectedPages.removeAll()
        
        // Refresh view
        refreshID = UUID()
    }
    
    func addImagesToDocument(_ images: [UIImage]) {
        let insertIndex = document.pageCount
        
        for (index, image) in images.enumerated() {
            if let page = PDFPage(image: image) {
                document.insert(page, at: insertIndex + index)
            }
        }
        
        // Refresh view
        refreshID = UUID()
    }
}

struct PDFThumbnailViewRepresentable_Backup: UIViewRepresentable {
    let document: PDFDocument
    @Binding var selectedPages: Set<PDFPage>
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        
        // Create a PDFView to link with
        // It MUST be visible (isHidden = false) for ThumbnailView to work reliably.
        // We will place it behind the ThumbnailView.
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.isHidden = false
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(pdfView)
        
        let thumbnailView = PDFThumbnailView()
        thumbnailView.pdfView = pdfView
        thumbnailView.layoutMode = .vertical
        thumbnailView.thumbnailSize = CGSize(width: 80, height: 120)
        thumbnailView.backgroundColor = UIColor.systemBackground // Opaque to cover PDFView
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(thumbnailView)
        
        // Layout Constraints
        NSLayoutConstraint.activate([
            // PDFView fills container (behind)
            pdfView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            pdfView.topAnchor.constraint(equalTo: containerView.topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            // ThumbnailView fills container (front)
            thumbnailView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            thumbnailView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            thumbnailView.topAnchor.constraint(equalTo: containerView.topAnchor),
            thumbnailView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Store references in Coordinator
        context.coordinator.pdfView = pdfView
        context.coordinator.thumbnailView = thumbnailView
        
        // Observe selection changes using KVO
        thumbnailView.addObserver(context.coordinator, forKeyPath: "selectedPages", options: [.new, .old], context: nil)
        
        return containerView
    }
    
    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.thumbnailView?.removeObserver(coordinator, forKeyPath: "selectedPages")
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Ensure document is up to date
        if context.coordinator.pdfView?.document != document {
            context.coordinator.pdfView?.document = document
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: PDFThumbnailViewRepresentable_Backup
        var pdfView: PDFView?
        weak var thumbnailView: PDFThumbnailView?
        
        init(_ parent: PDFThumbnailViewRepresentable_Backup) {
            self.parent = parent
        }
        
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            if keyPath == "selectedPages" {
                guard let thumbnailView = object as? PDFThumbnailView else { return }
                if let selected = thumbnailView.selectedPages {
                    DispatchQueue.main.async {
                        self.parent.selectedPages = Set(selected)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.parent.selectedPages = []
                    }
                }
            }
        }
    }
}
