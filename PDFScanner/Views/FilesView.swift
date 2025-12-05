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
    @AppStorage("isGridView") private var isGridView = true // Default to Grid
    
    var filteredDocuments: [ScannedItem] {
        if searchText.isEmpty {
            return store.documents
        } else {
            return store.documents.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    // 2-Column Grid
    let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
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
            .navigationBarTitleDisplayMode(.large)
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
                        // View Toggle Button
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
                            .offset(x: 8, y: -8)
                            .shadow(radius: 2)
                    }
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink(value: item) {
                    GridItemCard(item: item)
                }
                .buttonStyle(ScaleButtonStyle()) // Add press animation
                .contextMenu {
                    menuActions(for: item)
                }
            }
        }
        .id(item.id)
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
        
        if let url = item.url {
            ShareLink(item: url) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ZStack {
                    Color.white
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "doc.text.fill")
                            .foregroundStyle(.gray.opacity(0.3))
                            .font(.largeTitle)
                    }
                }
            }
        }
        .task(id: url) {
            isLoading = true
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
        
        guard let document = PDFDocument(url: url) else {
            isLoading = false
            return
        }
        guard let page = document.page(at: 0) else {
            isLoading = false
            return
        }
        
        let thumbnailSize = CGSize(width: size.width * 2, height: size.height * 2)
        
        let image = await Task.detached(priority: .userInitiated) {
            return page.thumbnail(of: thumbnailSize, for: .mediaBox)
        }.value
        
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
            ZStack(alignment: .bottomTrailing) {
                PDFPreviewThumbnail(url: item.url, size: CGSize(width: 40, height: 52))
                    .frame(width: 40, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                
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
                Text("\(item.pageCount) Page\(item.pageCount > 1 ? "s" : "") • \(item.creationDate.formatted(date: .numeric, time: .shortened))")
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
        VStack(alignment: .leading, spacing: 10) {
            // Thumbnail Container
            ZStack {
                Color.white
                
                // NOTE: FIX FOR OVERLAPPING LAYOUT - DO NOT REMOVE GEOMETRY READER
                // GeometryReader ensures the image is strictly constrained to the parent frame
                GeometryReader { geo in
                    PDFPreviewThumbnail(url: item.url, size: geo.size)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .frame(height: 180) // Fixed height for thumbnail area
            .frame(maxWidth: .infinity)
            .clipped() // Ensure content doesn't overflow
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3) // Nice shadow
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                if item.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Material.ultraThin)
                        .clipShape(Circle())
                        .padding(8)
                }
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(2) // Allow 2 lines
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
                    .frame(height: 44, alignment: .topLeading) // Fixed height for alignment
                
                HStack(spacing: 4) {
                    Text("\(item.pageCount) Page\(item.pageCount > 1 ? "s" : "")")
                    Text("·")
                    Text(item.creationDate.formatted(date: .omitted, time: .shortened))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    FilesView()
        .environmentObject(FoxDocumentStore())
}
