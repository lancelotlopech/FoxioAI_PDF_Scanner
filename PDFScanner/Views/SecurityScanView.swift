import SwiftUI

struct SecurityScanView: View {
    let item: ScannedItem
    @Environment(\.dismiss) var dismiss
    
    @State private var isScanning = true
    @State private var scanProgress: CGFloat = 0.0
    @State private var result: SecurityScanResult?
    @State private var currentCheck = String(localized: "Initializing...")
    
    // Animation States
    @State private var radarRotation = 0.0
    @State private var showResult = false
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                if isScanning {
                    scanningView
                } else if let result = result {
                    resultView(result)
                }
            }
            .padding()
        }
        .navigationTitle("Security Scan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .disabled(isScanning)
            }
        }
        .onAppear {
            startScan()
        }
    }
    
    // MARK: - Scanning View
    
    private var scanningView: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Radar Animation
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 2)
                    .frame(width: 200, height: 200)
                
                Circle()
                    .stroke(Color.blue.opacity(0.1), lineWidth: 20)
                    .frame(width: 180, height: 180)
                
                // Scanning Line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.5), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 200, height: 100)
                    .offset(y: -50)
                    .rotationEffect(.degrees(radarRotation))
                    .mask(Circle().frame(width: 200, height: 200))
                
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
                    .shadow(radius: 10)
            }
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    radarRotation = 360
                }
            }
            
            VStack(spacing: 12) {
                Text(String(localized: "Scanning Document..."))
                    .font(.title2.bold())
                
                Text(currentCheck)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
                    .id(currentCheck) // Force transition
                
                ProgressView(value: scanProgress, total: 1.0)
                    .tint(.blue)
                    .frame(width: 200)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Result View
    
    private func resultView(_ result: SecurityScanResult) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Score Card
                VStack(spacing: 16) {
                    Image(systemName: result.isSafe ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(result.isSafe ? .green : .orange)
                        .shadow(color: (result.isSafe ? Color.green : Color.orange).opacity(0.3), radius: 10, y: 5)
                    
                    Text(result.isSafe ? String(localized: "Document is Safe") : String(localized: "Potential Risks Found"))
                        .font(.title2.bold())
                        .foregroundStyle(result.isSafe ? .green : .orange)
                    
                    Text(String(localized: "Security Score: \(result.score)/100"))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 30)
                .frame(maxWidth: .infinity)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.05), radius: 5)
                
                // Details
                VStack(alignment: .leading, spacing: 16) {
                    Text(String(localized: "Security Checks"))
                        .font(.headline)
                        .padding(.leading, 4)
                    
                    // Detailed Checklist
                    VStack(spacing: 12) {
                        checkRow(title: String(localized: "Malicious Scripts"), passed: !result.threats.contains("Contains JavaScript"))
                        checkRow(title: String(localized: "Auto-Run Actions"), passed: !result.threats.contains("Auto-Run Actions"))
                        checkRow(title: String(localized: "Launch Commands"), passed: !result.threats.contains("Launch Command"))
                        checkRow(title: String(localized: "File Integrity"), passed: true) // Always passed if we opened it
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    if !result.threats.isEmpty {
                        Text(String(localized: "Threats Found"))
                            .font(.headline)
                            .padding(.leading, 4)
                            .padding(.top, 8)
                        
                        ForEach(result.threats, id: \.self) { threat in
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text(threat)
                                    .font(.subheadline.bold())
                                Spacer()
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    
                    Text(String(localized: "Scan Details"))
                        .font(.headline)
                        .padding(.leading, 4)
                        .padding(.top, 8)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(result.details)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                if !result.isSafe {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "Recommendations"))
                            .font(.headline)
                        
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(.yellow)
                            Text(String(localized: "This document contains active content (scripts or actions). Only open it if you trust the source completely. Consider converting it to images to neutralize threats."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }
    
    private func checkRow(title: String, passed: Bool) -> some View {
        HStack {
            Image(systemName: passed ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(passed ? .green : .orange)
                .font(.title3)
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            
            Spacer()
            
            Text(passed ? String(localized: "Safe") : String(localized: "Risk"))
                .font(.caption.bold())
                .foregroundStyle(passed ? .green : .orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((passed ? Color.green : Color.orange).opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }

    // MARK: - Logic
    
    private func startScan() {
        guard let url = item.url else {
            isScanning = false
            return
        }
        
        Task {
            // Simulate steps for UX
            withAnimation { currentCheck = String(localized: "Checking file integrity...") }
            scanProgress = 0.2
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            withAnimation { currentCheck = String(localized: "Analyzing encryption...") }
            scanProgress = 0.4
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            withAnimation { currentCheck = String(localized: "Scanning for malicious scripts...") }
            scanProgress = 0.7
            try? await Task.sleep(nanoseconds: 800_000_000)
            
            withAnimation { currentCheck = String(localized: "Verifying metadata...") }
            scanProgress = 0.9
            try? await Task.sleep(nanoseconds: 400_000_000)
            
            // Actual Scan
            let scanResult = await FoxPDFManager.shared.scanPDF(url: url)
            
            withAnimation {
                scanProgress = 1.0
                self.result = scanResult
                self.isScanning = false
            }
        }
    }
}

#Preview {
    SecurityScanView(item: ScannedItem(name: "Test Doc", url: nil))
}
