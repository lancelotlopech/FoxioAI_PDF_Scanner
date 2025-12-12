import SwiftUI
import PDFKit

struct ExportOptionsView: View {
    let item: ScannedItem
    @Binding var isPresented: Bool
    
    @State private var isWatermarkEnabled: Bool = true
    @State private var isProcessing = false
    @State private var generatedURL: URL?
    
    // Subscription State
    @State private var showSubscription = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Preview Area
                ZStack {
                    Color(uiColor: .systemGroupedBackground)
                        .cornerRadius(12)
                    
                    if isProcessing {
                        ProgressView()
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text(item.name)
                                .font(.headline)
                            
                            if isWatermarkEnabled {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.green)
                                    Text("Watermark Added")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(8)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .frame(height: 200)
                .padding()
                
                // Options
                List {
                    Section {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Add Watermark")
                                    .font(.body)
                                Text("Scan & Edit with FoxioAI")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $isWatermarkEnabled)
                                .onChange(of: isWatermarkEnabled) { newValue in
                                    if !newValue && !SubscriptionManager.shared.isPremium {
                                        // Revert if not premium
                                        isWatermarkEnabled = true
                                        showSubscription = true
                                    }
                                }
                        }
                    } footer: {
                        if !SubscriptionManager.shared.isPremium {
                            Text("Upgrade to Premium to remove watermark.")
                                .foregroundColor(.blue)
                                .onTapGesture {
                                    showSubscription = true
                                }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                
                // Action Button
                Button {
                    exportFile()
                } label: {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Share / Export")
                                .fontWeight(.bold)
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom)
                .disabled(isProcessing)
            }
            .navigationTitle("Export Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .fullScreenCover(isPresented: $showSubscription) {
                SubscriptionView()
            }
        }
        .onAppear {
            // Force enable for free users initially
            if !SubscriptionManager.shared.isPremium {
                isWatermarkEnabled = true
            }
        }
    }
    
    private func exportFile() {
        guard let url = item.url else { return }
        isProcessing = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            var finalURL = url
            
            if isWatermarkEnabled {
                if let watermarked = FoxPDFManager.shared.createWatermarkedPDF(from: url) {
                    finalURL = watermarked
                }
            }
            
            DispatchQueue.main.async {
                isProcessing = false
                shareFile(url: finalURL)
            }
        }
    }
    
    private func shareFile(url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        // Find the top-most view controller to present
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            
            // Dismiss self first if presented as sheet, or present on top?
            // Better to present on top of this sheet
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            
            // For iPad
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = topVC.view
                popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            topVC.present(activityVC, animated: true)
        }
    }
}
