import SwiftUI

struct OCRResultView: View {
    let recognizedText: String
    let images: [UIImage]
    
    @Environment(\.dismiss) private var dismiss
    @State private var isCopied = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !images.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<images.count, id: \.self) { index in
                                Image(uiImage: images[index])
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .shadow(radius: 2)
                            }
                        }
                        .padding()
                    }
                    .frame(height: 230)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    
                    Divider()
                }
                
                if recognizedText.isEmpty {
                    ContentUnavailableView(
                        "No Text Found",
                        systemImage: "doc.text.viewfinder",
                        description: Text("Could not extract any text from the scanned document.")
                    )
                } else {
                    TextEditor(text: .constant(recognizedText))
                        .font(.body)
                        .padding()
                        .background(Color(uiColor: .systemGroupedBackground)) // Changed to match parent background for contrast
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Extracted Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        UIPasteboard.general.string = recognizedText
                        isCopied = true
                        
                        // Reset copy state after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            isCopied = false
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            Text(isCopied ? "Copied" : "Copy")
                        }
                    }
                    .disabled(recognizedText.isEmpty)
                }
            }
        }
    }
}

#Preview {
    OCRResultView(recognizedText: "This is a sample extracted text.\nIt spans multiple lines.", images: [])
}
