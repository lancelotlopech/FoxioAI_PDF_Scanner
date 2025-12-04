import SwiftUI
import PDFKit

struct FilesView: View {
    @EnvironmentObject var store: FoxDocumentStore
    @State private var searchText = ""
    @State private var isSelectionMode = false
    @State private var selectedItems: Set<ScannedItem> = []
    
    // Rename State
    @State private var renamingItem: ScannedItem?
    @State private var newName = ""
    @State private var isRenaming = false
    
    // Delete Confirmation
    @State private var itemToDelete: ScannedItem?
    @State private var showDeleteConfirmation = false
    @State private var isDeletingSelection = false
    
    // View Mode Preference (Persisted)
    @AppStorage("isGridView") private var isGridView = false
    
    var filteredDocuments: [ScannedItem] {
        if searchText.isEmpty {
            return store.documents
        } else {
            return store.documents.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    let gridColumns = [
        GridItem(.adaptive(minimum: 100), spacing: 16, alignment: .top)
    ]
    
    var body: some View {
        NavigationStack {
            Group {
                if store.documents.isEmpty {
                    ContentUnavailableView(
                        "No Documents",
                        systemImage: "doc.on.doc",
                        description: Text("Scanned documents will appear here.")
                    )
                } else {
                    Group {
                        if isGridView {
                            // Grid View Layout
                            ScrollView {
                                LazyVGrid(columns: gridColumns, spacing: 16) {
                                    ForEach(filteredDocuments) { item in
                                        gridItem(for: item)
                                    }
                                }
                                .padding()
                            }
                        } else {
                            // List View Layout
                            List {
                                ForEach(filteredDocuments) { item in
                                    listItem(for: item)
                                }
                                .onDelete(perform: confirmDelete)
                            }
                            .listStyle(.plain)
                        }
                    }
                }
            }
            .alert("Rename Document", isPresented: $isRenaming) {
                TextField("New Name", text: $newName)
                Button("Cancel", role: .cancel) { }
                Button("Rename") {
                    if let item = renamingItem, !newName.isEmpty {
                        store.renameDocument(item, to: newName)
                    }
                }
            }
            .alert("Delete Document", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    itemToDelete = nil
                    isDeletingSelection = false
                }
                Button("Delete", role: .destructive) {
                    if isDeletingSelection {
                        performDeleteSelection()
                    } else if let item = itemToDelete {
                        store.deleteDocument(item)
                    }
                    itemToDelete = nil
                    isDeletingSelection = false
                }
            } message: {
                if isDeletingSelection {
                    Text("Are you sure you want to delete \(selectedItems.count) items? This action cannot be undone.")
                } else {
                    Text("Are you sure you want to delete '\(itemToDelete?.name ?? "this document")'? This action cannot be undone.")
                }
            }
            .searchable(text: $searchText, prompt: "Search files")
            .navigationTitle(isSelectionMode ? String(localized: "\(selectedItems.count) Selected") : String(localized: "My Files"))
            .navigationBarTitleDisplayMode(isSelectionMode ? .inline : .large)
            .toolbar {
                // Leading Toolbar
                ToolbarItem(placement: .topBarLeading) {
                    if isSelectionMode {
                        Button(role: .destructive) {
                            isDeletingSelection = true
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .disabled(selectedItems.isEmpty)
                    } else {
                        // View Toggle Button (Only when not selecting)
                        Button {
                            withAnimation {
                                isGridView.toggle()
                            }
                        } label: {
                            Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                        }
                    }
                }
                
                // Trailing Toolbar
                ToolbarItem(placement: .topBarTrailing) {
                    if isSelectionMode {
                        HStack {
                            Button("Merge") {
                                mergeSelectedItems()
                            }
                            .disabled(selectedItems.count < 2)
                            
                            Button("Done") {
                                isSelectionMode = false
                                selectedItems.removeAll()
                            }
                            .fontWeight(.bold)
                        }
                    } else {
                        Button("Select") {
                            isSelectionMode = true
                        }
                    }
                }
            }
            .navigationDestination(for: ScannedItem.self) { item in
                FoxPDFViewer(item: item)
            }
        }
    }
    
    // MARK: - List & Grid Builders
    
    @ViewBuilder
    private func listItem(for item: ScannedItem) -> some View {
        if isSelectionMode {
            Button {
                toggleSelection(for: item)
            } label: {
                HStack {
                    Image(systemName: selectedItems.contains(item) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedItems.contains(item) ? .blue : .gray)
                        .font(.title2)
                    
                    ItemRow(item: item)
                }
            }
            .foregroundStyle(.primary)
        } else {
            NavigationLink(value: item) {
                ItemRow(item: item)
            }
            .contextMenu {
                menuActions(for: item)
            }
            .swipeActions(edge: .leading) {
                Button {
                    renamingItem = item
                    newName = item.name
                    isRenaming = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                .tint(.orange)
            }
        }
    }
    
    @ViewBuilder
    private func gridItem(for item: ScannedItem) -> some View {
        Group {
            if isSelectionMode {
                Button {
                    toggleSelection(for: item)
                } label: {
                    ZStack(alignment: .topTrailing) {
                        GridItemCard(item: item)
                        
                        Image(systemName: selectedItems.contains(item) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedItems.contains(item) ? .blue : .gray)
                            .font(.title3)
                            .background(Circle().fill(.white))
                            .offset(x: 5, y: -5)
                    }
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink(value: item) {
                    GridItemCard(item: item)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    menuActions(for: item)
                }
            }
        }
        .id(item.id) // Force identity to prevent layout reuse issues
    }
    
    @ViewBuilder
    private func menuActions(for item: ScannedItem) -> some View {
        Button {
            renamingItem = item
            newName = item.name
            isRenaming = true
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        
        Button(role: .destructive) {
            itemToDelete = item
            isDeletingSelection = false
            showDeleteConfirmation = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    
    // MARK: - Actions
    
    private func toggleSelection(for item: ScannedItem) {
        if selectedItems.contains(item) {
            selectedItems.remove(item)
        } else {
            selectedItems.insert(item)
        }
    }
    
    private func confirmDelete(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        itemToDelete = filteredDocuments[index]
        isDeletingSelection = false
        showDeleteConfirmation = true
    }
    
    private func performDeleteSelection() {
        for item in selectedItems {
            store.deleteDocument(item)
        }
        selectedItems.removeAll()
        isSelectionMode = false
    }
    
    private func mergeSelectedItems() {
        let itemsToMerge = store.documents.filter { selectedItems.contains($0) }
        let urls = itemsToMerge.compactMap { $0.url }
        
        if let mergedURL = FoxPDFManager.shared.mergePDFs(urls: urls) {
            let dateString = Date().formatted(date: .numeric, time: .omitted)
            var newItem = ScannedItem(
                name: String(localized: "Merged \(dateString)"),
                url: mergedURL
            )
            
            if let document = PDFDocument(url: mergedURL) {
                newItem.pageCount = document.pageCount
            }
            
            store.addDocument(newItem)
            
            isSelectionMode = false
            selectedItems.removeAll()
        }
    }
}

// MARK: - Helper Views

struct PDFPreviewThumbnail: View {
    let url: URL?
    let size: CGSize
    @State private var thumbnail: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.gray.opacity(0.1)
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "doc.text.fill")
                            .foregroundStyle(.gray.opacity(0.5))
                            .font(.title2)
                    }
                }
            }
        }
        .task(id: url) {
            isLoading = true
            // Check cache first
            if let url = url, let cached = ThumbnailCache.shared.image(for: url) {
                self.thumbnail = cached
                isLoading = false
                return
            }
            await generateThumbnail()
        }
    }
    
    private func generateThumbnail() async {
        guard let url = url else {
            isLoading = false
            return
        }
        
        // Check if thumbnail is already generated or perform generation
        // For simple list performance, we generate on task start
        guard let document = PDFDocument(url: url) else {
            isLoading = false
            return
        }
        guard let page = document.page(at: 0) else {
            isLoading = false
            return
        }
        
        // Calculate thumbnail size maintaining aspect ratio
        // We use a slightly larger scale for crispness
        let thumbnailSize = CGSize(width: size.width * 2, height: size.height * 2)
        
        // Run on background thread to avoid blocking UI
        let image = await Task.detached(priority: .userInitiated) {
            return page.thumbnail(of: thumbnailSize, for: .mediaBox)
        }.value
        
        // Cache the image
        ThumbnailCache.shared.insert(image, for: url)
        
        await MainActor.run {
            self.thumbnail = image
            self.isLoading = false
        }
    }
}

struct ItemRow: View {
    let item: ScannedItem
    
    var body: some View {
        HStack(spacing: 12) {
            // PDF Preview Thumbnail
            ZStack(alignment: .bottomTrailing) {
                PDFPreviewThumbnail(url: item.url, size: CGSize(width: 40, height: 52))
                    .frame(width: 40, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                if item.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Circle())
                        .offset(x: 4, y: 4)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(item.pageCount) pages • \(item.creationDate.formatted(date: .numeric, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct GridItemCard: View {
    let item: ScannedItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Large Preview
            // Use a base container to strictly define the cell size, then overlay the image.
            // This prevents the image's natural size from expanding the cell and causing overlaps.
            Color.gray.opacity(0.1)
                .frame(height: 160)
                .overlay {
                    PDFPreviewThumbnail(url: item.url, size: CGSize(width: 120, height: 160))
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .overlay(alignment: .bottomTrailing) {
                    if item.isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(Color.black.opacity(0.7))
                            .clipShape(Circle())
                            .padding(6)
                    }
                }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                
                Text("\(item.pageCount) pages")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Text(item.creationDate.formatted(date: .numeric, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top) // Ensure alignment
        .contentShape(Rectangle()) // Better tap area
    }
}

#Preview {
    FilesView()
        .environmentObject(FoxDocumentStore())
}
