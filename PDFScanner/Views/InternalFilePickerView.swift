import SwiftUI

struct InternalFilePickerView: View {
    @EnvironmentObject var store: FoxDocumentStore
    @Environment(\.dismiss) private var dismiss
    
    let allowMultiple: Bool
    let title: String
    let onSelect: ([ScannedItem]) -> Void
    
    @State private var selectedItems: Set<ScannedItem> = []
    @State private var searchText = ""
    
    var filteredDocuments: [ScannedItem] {
        if searchText.isEmpty {
            return store.documents
        } else {
            return store.documents.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if store.documents.isEmpty {
                    ContentUnavailableView(
                        "No Documents",
                        systemImage: "doc.on.doc",
                        description: Text("Scan or import documents first.")
                    )
                } else {
                    List {
                        ForEach(filteredDocuments) { item in
                            Button {
                                toggleSelection(for: item)
                            } label: {
                                HStack {
                                    Image(systemName: selectedItems.contains(item) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedItems.contains(item) ? .blue : .gray)
                                        .font(.title2)
                                    
                                    VStack(alignment: .leading) {
                                        HStack {
                                            Text(item.name)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            
                                            if item.isLocked {
                                                Image(systemName: "lock.fill")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Text("\(item.pageCount) pages • \(item.creationDate.formatted(date: .numeric, time: .shortened))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search files")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        let items = store.documents.filter { selectedItems.contains($0) }
                        onSelect(items)
                        dismiss()
                    }
                    .disabled(selectedItems.isEmpty)
                    .fontWeight(.bold)
                }
            }
        }
    }
    
    private func toggleSelection(for item: ScannedItem) {
        if allowMultiple {
            if selectedItems.contains(item) {
                selectedItems.remove(item)
            } else {
                selectedItems.insert(item)
            }
        } else {
            // Single selection mode
            selectedItems = [item]
        }
    }
}

#Preview {
    InternalFilePickerView(allowMultiple: true, title: "Select Files") { _ in }
        .environmentObject(FoxDocumentStore())
}
