import SwiftUI
import PhotosUI
import PDFKit
import UniformTypeIdentifiers

enum ActiveTool: Identifiable {
    case importPhotos
    case importFiles
    case extractText
    case signPDF
    case mergePDFs
    case organizePages
    case editText
    case protectPDF
    case unlockPDF
    case securityScan
    
    var id: Self { self }
}

enum PasswordSheetMode {
    case protect
    case unlock
}

struct PasswordSheetData: Identifiable {
    let id = UUID()
    let mode: PasswordSheetMode
    let onConfirm: (String) -> Void
}

enum ImportFileType: String, CaseIterable {
    case pdf = "PDF Document"
    case word = "Word Document"
    case excel = "Excel Spreadsheet"
    case ppt = "PowerPoint"
    case other = "Other Files"
    
    var icon: String {
        switch self {
        case .pdf: return "doc.text.fill"
        case .word: return "doc.text.fill"
        case .excel: return "tablecells.fill"
        case .ppt: return "rectangle.on.rectangle.angled.fill"
        case .other: return "folder.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .pdf: return .red
        case .word: return .blue
        case .excel: return .green
        case .ppt: return .orange
        case .other: return .gray
        }
    }
    
    var types: [UTType] {
        switch self {
        case .pdf: return [.pdf]
        case .word: return [UTType(filenameExtension: "doc")!, UTType(filenameExtension: "docx")!]
        case .excel: return [UTType(filenameExtension: "xls")!, UTType(filenameExtension: "xlsx")!]
        case .ppt: return [UTType(filenameExtension: "ppt")!, UTType(filenameExtension: "pptx")!]
        case .other: 
            let extensions = [
                "doc", "docx", "dot", "dotx", "docm", "dotm",
                "xls", "xlsx", "xlt", "xltx", "xlsm", "xltm",
                "ppt", "pptx", "pps", "ppsx", "pot", "potx", "pptm", "potm", "ppsm", "thmx",
                "txt", "rtf", "rtfd",
                "xml", "html", "htm", "mht", "mhtml",
                "pages", "numbers", "key"
            ]
            var types: [UTType] = [.pdf, .image]
            types.append(contentsOf: extensions.compactMap { UTType(filenameExtension: $0) })
            return types
        }
    }
}

enum OCRSourceType: String, CaseIterable {
    case camera = "Camera Scan"
    case photos = "Photos"
    case files = "Files"
    case internalPDF = "App Documents"
    
    var icon: String {
        switch self {
        case .camera: return "camera.fill"
        case .photos: return "photo.fill"
        case .files: return "folder.fill"
        case .internalPDF: return "doc.text.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .camera: return .blue
        case .photos: return .purple
        case .files: return .orange
        case .internalPDF: return .red
        }
    }
}

struct PDFViewerDestination: Hashable {
    let item: ScannedItem
    var showSignInstruction: Bool = false
    var autoStartScanning: Bool = false
    var autoShowPageEditor: Bool = false
}

struct SecurityScanDestination: Hashable {
    let item: ScannedItem
}

struct OCRResultData: Identifiable {
    let id = UUID()
    let text: String
    let images: [UIImage]
}

struct DashboardView: View {
    @EnvironmentObject var store: FoxDocumentStore
    @Binding var selectedTab: Int
    
    // Sheet States
    @State private var isShowingScanner = false
    @State private var isShowingPhotoPicker = false
    @State private var isShowingFilePicker = false
    @State private var isShowingImportTypeModal = false
    
    // Tool States
    @State private var activeTool: ActiveTool?
    @State private var internalPickerTool: ActiveTool? // Controls Internal File Picker Sheet
    @State private var selectedImportType: ImportFileType = .other
    @State private var currentAllowedContentTypes: [UTType] = []
    @State private var allowsMultipleSelection = false
    
    // OCR States
    @State private var isShowingOCRScanner = false
    @State private var isShowingOCRSourceModal = false
    @State private var ocrResultData: OCRResultData? // Controls OCR Result Sheet
    
    // Password Sheet State
    @State private var passwordSheetData: PasswordSheetData?
    
    // Pending States (for onDismiss handling)
    @State private var pendingScanImages: [UIImage]?
    @State private var pendingOCRImages: [UIImage]?
    
    // Error States
    @State private var errorMessage: String?
    @State private var showError = false
    
    // Navigation States
    @State private var navigationPath = NavigationPath()
    
    // Subscription Sheet
    @State private var isShowingSubscription = false
    
    @State private var selectedPhotos: [PhotosPickerItem] = []
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        // 1. Header
                        headerView
                        
                        // 2. Hero Scan Button
                        heroScanButton
                        
                        // 3. Tools Grid (Bento Style)
                        toolsGrid
                        
                        // 4. Recent Files (Horizontal Scroll)
                        recentFilesSection
                    }
                    .padding()
                }
                .background(Color(uiColor: .systemGroupedBackground))
                .navigationBarHidden(true)
                .navigationDestination(for: ScannedItem.self) { item in
                    FoxPDFViewer(item: item)
                }
                .navigationDestination(for: PDFViewerDestination.self) { dest in
                    FoxPDFViewer(
                        item: dest.item,
                        showSignInstruction: dest.showSignInstruction,
                        autoStartScanning: dest.autoStartScanning,
                        autoShowPageEditor: dest.autoShowPageEditor
                    )
                }
                .navigationDestination(for: SecurityScanDestination.self) { dest in
                    SecurityScanView(item: dest.item)
                }
                
                // Custom Modal Overlay
                if isShowingImportTypeModal {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .zIndex(1) // Ensure it's on top
                        .onTapGesture {
                            withAnimation { isShowingImportTypeModal = false }
                        }
                    
                    importTypeModalView
                        .zIndex(2) // Ensure content is on top of background
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
                
                if isShowingOCRSourceModal {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .zIndex(1)
                        .onTapGesture {
                            withAnimation { isShowingOCRSourceModal = false }
                        }
                    
                    ocrSourceModalView
                        .zIndex(2)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
        }
        // -- Modifiers moved to NavigationStack level --
        .fullScreenCover(isPresented: $isShowingScanner, onDismiss: {
            if let images = pendingScanImages {
                processImages(images, source: "Camera Scan")
                pendingScanImages = nil
            }
        }) {
            ScannerView { result in
                isShowingScanner = false
                switch result {
                case .success(let images):
                    self.pendingScanImages = images
                case .failure(let error):
                    print("Scanning failed: \(error.localizedDescription)")
                    errorMessage = String(localized: "Scanning failed: \(error.localizedDescription)")
                    showError = true
                }
            } didCancelScanning: {
                isShowingScanner = false
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $isShowingPhotoPicker, selection: $selectedPhotos, matching: .images)
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: currentAllowedContentTypes,
            allowsMultipleSelection: allowsMultipleSelection,
            onCompletion: { result in
                // Delay processing to allow modal dismissal (Increased to 0.8s for safety)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    handleFileImport(result: result)
                }
            }
        )
        .sheet(item: $internalPickerTool) { tool in
            InternalFilePickerView(
                allowMultiple: tool == .mergePDFs,
                title: tool == .mergePDFs ? String(localized: "Select Files to Merge") : String(localized: "Select File"),
                onSelect: { items in
                    handleInternalFileSelection(items: items, tool: tool)
                }
            )
            .environmentObject(store)
        }
        .onChange(of: selectedPhotos) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                var images: [UIImage] = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        images.append(image)
                    }
                }
                
                // Delay processing to allow picker dismissal (Increased to 0.8s)
                try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s
                
                await MainActor.run {
                    if activeTool == .extractText {
                        processOCRImages(images)
                    } else {
                        processImages(images, source: "Photo Import")
                    }
                    selectedPhotos.removeAll()
                }
            }
        }
        // OCR Scanner
        .fullScreenCover(isPresented: $isShowingOCRScanner, onDismiss: {
            if let images = pendingOCRImages {
                processOCRImages(images)
                pendingOCRImages = nil
            }
        }) {
            ScannerView { result in
                isShowingOCRScanner = false
                switch result {
                case .success(let images):
                    self.pendingOCRImages = images
                case .failure(let error):
                    print("OCR Scanning failed: \(error.localizedDescription)")
                    errorMessage = String(localized: "OCR Scanning failed: \(error.localizedDescription)")
                    showError = true
                }
            } didCancelScanning: {
                isShowingOCRScanner = false
            }
            .ignoresSafeArea()
        }
        .sheet(item: $ocrResultData) { data in
            OCRResultView(recognizedText: data.text, images: data.images)
        }
        .sheet(item: $passwordSheetData) { data in
            PasswordInputView(mode: data.mode, onConfirm: data.onConfirm)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
        .fullScreenCover(isPresented: $isShowingSubscription) {
            SubscriptionView()
        }
    }
    
    // MARK: - Views
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("FoxioAI")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                Text("PDF Assistant")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            
            Button {
                isShowingSubscription = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(.yellow)
                    Text("Pro")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.05), radius: 2)
            }
        }
        .padding(.top, 8)
    }
    
    private var greetingMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good Morning"
        case 12..<18: return "Good Afternoon"
        default: return "Good Evening"
        }
    }
    
    private var heroScanButton: some View {
        Button {
            isShowingScanner = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Smart Scan")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("AI-Powered Capture")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.9))
                }
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 70, height: 70)
                    Image(systemName: "doc.viewfinder")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.2, blue: 0.4), .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Tech Glow Effect
                    Circle()
                        .fill(.white.opacity(0.1))
                        .frame(width: 200, height: 200)
                        .offset(x: 100, y: -50)
                        .blur(radius: 30)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: Color(red: 1.0, green: 0.2, blue: 0.4).opacity(0.4), radius: 15, x: 0, y: 8)
        }
    }
    
    private var toolsGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tools")
                .font(.title3.bold())
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                // Row 1: Import
                BentoCard(title: "Import Photos", icon: "photo.stack", color: .blue) {
                    activeTool = .importPhotos
                    isShowingPhotoPicker = true
                }
                
                BentoCard(title: "Import Files", icon: "folder.badge.plus", color: .indigo) {
                    activeTool = .importFiles
                    withAnimation { isShowingImportTypeModal = true }
                }
                
                // Row 2: Edit
                BentoCard(title: "Edit Text", icon: "pencil.and.scribble", color: .teal) {
                    activeTool = .editText
                    internalPickerTool = .editText
                }
                
                BentoCard(title: "Sign PDF", icon: "signature", color: .pink) {
                    activeTool = .signPDF
                    internalPickerTool = .signPDF
                }
                
                // Row 3: Manage
                BentoCard(title: "Organize Pages", icon: "doc.on.doc", color: .green) {
                    activeTool = .organizePages
                    internalPickerTool = .organizePages
                }
                
                BentoCard(title: "Merge PDFs", icon: "square.and.arrow.down.on.square", color: .orange) {
                    activeTool = .mergePDFs
                    internalPickerTool = .mergePDFs
                }
                
                // Row 4: AI & Security
                BentoCard(title: "Extract Text", icon: "text.viewfinder", color: .purple) {
                    activeTool = .extractText
                    withAnimation { isShowingOCRSourceModal = true }
                }
                
                BentoCard(title: "Protect PDF", icon: "lock.fill", color: .red) {
                    activeTool = .protectPDF
                    internalPickerTool = .protectPDF
                }
                
                // Row 5: More Security
                BentoCard(title: "Unlock PDF", icon: "lock.open.fill", color: .blue) {
                    activeTool = .unlockPDF
                    internalPickerTool = .unlockPDF
                }
                
                BentoCard(title: "Security Scan", icon: "checkmark.shield.fill", color: .mint) {
                    activeTool = .securityScan
                    internalPickerTool = .securityScan
                }
            }
        }
    }
    
    private var recentFilesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Files")
                    .font(.title3.bold())
                Spacer()
                Button("See All") {
                    selectedTab = 1
                }
                .font(.subheadline)
            }
            
            if store.documents.isEmpty {
                ContentUnavailableView("No Recent Files", systemImage: "doc.on.doc")
                    .frame(height: 150)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(store.documents.prefix(5)) { item in
                            NavigationLink(value: item) {
                                RecentFileCard(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
    
    private var importTypeModalView: some View {
        VStack(spacing: 20) {
            Text("Import File")
                .font(.title3.bold())
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(ImportFileType.allCases, id: \.self) { type in
                    Button {
                        withAnimation { isShowingImportTypeModal = false }
                        // Delay slightly to allow animation to finish
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            selectedImportType = type
                            startFileImport(type: type)
                        }
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: type.icon)
                                .font(.title)
                                .foregroundStyle(type.color)
                                .frame(width: 50, height: 50)
                                .background(type.color.opacity(0.1))
                                .clipShape(Circle())
                            
                            Text(LocalizedStringKey(type.rawValue))
                                .font(.caption.bold())
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 120) // Flexible height
                        .padding()
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.05), radius: 2)
                    }
                }
            }
            
            Button("Cancel") {
                withAnimation { isShowingImportTypeModal = false }
            }
            .font(.headline)
            .foregroundStyle(.red)
            .padding(.top, 8)
        }
        .padding(24)
        .background(Color(uiColor: .systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(radius: 20)
        .padding(32)
    }
    
    private var ocrSourceModalView: some View {
        VStack(spacing: 20) {
            Text("Extract Text From")
                .font(.title3.bold())
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(OCRSourceType.allCases, id: \.self) { type in
                    Button {
                        withAnimation { isShowingOCRSourceModal = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            handleOCRSourceSelection(type)
                        }
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: type.icon)
                                .font(.title)
                                .foregroundStyle(type.color)
                                .frame(width: 50, height: 50)
                                .background(type.color.opacity(0.1))
                                .clipShape(Circle())
                            
                            Text(type.rawValue)
                                .font(.caption.bold())
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 120)
                        .padding()
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.05), radius: 2)
                    }
                }
            }
            
            Button("Cancel") {
                withAnimation { isShowingOCRSourceModal = false }
            }
            .font(.headline)
            .foregroundStyle(.red)
            .padding(.top, 8)
        }
        .padding(24)
        .background(Color(uiColor: .systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(radius: 20)
        .padding(32)
    }
    
    // MARK: - Logic
    
    private func handleOCRSourceSelection(_ type: OCRSourceType) {
        switch type {
        case .camera:
            isShowingOCRScanner = true
        case .photos:
            isShowingPhotoPicker = true
        case .files:
            currentAllowedContentTypes = [.pdf, .image]
            allowsMultipleSelection = false
            isShowingFilePicker = true
        case .internalPDF:
            // For OCR from internal PDF, we set activeTool to .extractText (already set by BentoCard)
            // But we need to trigger the picker.
            // Since internalPickerTool drives the sheet, we set it to .extractText
            internalPickerTool = .extractText
        }
    }
    
    private func startFileImport(type: ImportFileType, multiple: Bool = true) {
        currentAllowedContentTypes = type.types
        allowsMultipleSelection = multiple
        isShowingFilePicker = true
    }
    
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            
            Task {
                // Standard Import Logic
                for url in urls {
                    guard url.startAccessingSecurityScopedResource() else { continue }
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                    try? FileManager.default.copyItem(at: url, to: tempURL)
                    url.stopAccessingSecurityScopedResource()
                    
                    let extensionName = url.pathExtension.lowercased()
                    
                    if activeTool == .extractText {
                        // OCR Logic
                        var images: [UIImage] = []
                        
                        if UTType(filenameExtension: extensionName)?.conforms(to: .image) == true {
                            if let data = try? Data(contentsOf: tempURL), let image = UIImage(data: data) {
                                images.append(image)
                            }
                        } else if extensionName == "pdf" {
                            // Extract images from PDF
                            images = FoxPDFManager.shared.images(from: tempURL)
                        }
                        
                        if !images.isEmpty {
                            await MainActor.run {
                                processOCRImages(images)
                            }
                        } else {
                            await MainActor.run {
                                errorMessage = String(localized: "Could not extract images from file for OCR.")
                                showError = true
                            }
                        }
                        
                    } else {
                        // Standard Document Import
                        if UTType(filenameExtension: extensionName)?.conforms(to: .image) == true {
                            if let data = try? Data(contentsOf: tempURL), let image = UIImage(data: data) {
                                await MainActor.run {
                                    processImages([image], source: "File Import")
                                }
                            }
                        } else if extensionName == "pdf" {
                            if let savedURL = FoxPDFManager.shared.copyFileToDocuments(from: tempURL) {
                                if let document = PDFDocument(url: savedURL) {
                                    let item = ScannedItem(name: savedURL.lastPathComponent, url: savedURL, pageCount: document.pageCount)
                                    await MainActor.run { 
                                        store.addDocument(item)
                                        navigationPath.append(item)
                                    }
                                }
                            } else {
                                await MainActor.run {
                                    errorMessage = String(localized: "Failed to save PDF file.")
                                    showError = true
                                }
                            }
                        } else {
                            // Office Docs
                            if let pdfURL = await FoxPDFManager.shared.convertOfficeDocToPDF(sourceURL: tempURL, filename: url.deletingPathExtension().lastPathComponent) {
                                if let document = PDFDocument(url: pdfURL) {
                                    let item = ScannedItem(name: pdfURL.lastPathComponent, url: pdfURL, pageCount: document.pageCount)
                                    await MainActor.run { 
                                        store.addDocument(item)
                                        navigationPath.append(item)
                                    }
                                }
                            } else {
                                await MainActor.run {
                                    errorMessage = String(localized: "Failed to convert document.")
                                    showError = true
                                }
                            }
                        }
                    }
                    try? FileManager.default.removeItem(at: tempURL)
                }
            }
            
        case .failure(let error):
            print("Import failed: \(error.localizedDescription)")
            errorMessage = String(localized: "Import failed: \(error.localizedDescription)")
            showError = true
        }
    }
    
    private func handleInternalFileSelection(items: [ScannedItem], tool: ActiveTool) {
        guard !items.isEmpty else { return }
        
        // Add delay to allow sheet to dismiss before navigating
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Task {
                if tool == .mergePDFs {
                    let urls = items.compactMap { $0.url }
                    if let mergedURL = FoxPDFManager.shared.mergePDFs(urls: urls) {
                        let dateString = Date().formatted(date: .numeric, time: .omitted)
                        var item = ScannedItem(name: String(localized: "Merged \(dateString)"), url: mergedURL)
                        if let doc = PDFDocument(url: mergedURL) { item.pageCount = doc.pageCount }
                        await MainActor.run {
                            store.addDocument(item)
                            navigationPath.append(item)
                        }
                    } else {
                        await MainActor.run {
                            errorMessage = String(localized: "Failed to merge PDFs.")
                            showError = true
                        }
                    }
                } else if tool == .signPDF {
                    if let item = items.first {
                        await MainActor.run {
                            // Navigate with Sign Instruction
                            navigationPath.append(PDFViewerDestination(item: item, showSignInstruction: true))
                        }
                    }
                } else if tool == .editText {
                    if let item = items.first {
                        await MainActor.run {
                            // Navigate with Auto Start Scanning
                            navigationPath.append(PDFViewerDestination(item: item, autoStartScanning: true))
                        }
                    }
                } else if tool == .organizePages {
                    if let item = items.first {
                        await MainActor.run {
                            // Navigate with Auto Show Page Editor
                            navigationPath.append(PDFViewerDestination(item: item, autoShowPageEditor: true))
                        }
                    }
                } else if tool == .extractText {
                    if let item = items.first, let url = item.url {
                        let images = FoxPDFManager.shared.images(from: url)
                        if !images.isEmpty {
                            await MainActor.run {
                                processOCRImages(images)
                            }
                        } else {
                            await MainActor.run {
                                errorMessage = String(localized: "Could not extract images from PDF.")
                                showError = true
                            }
                        }
                    }
                } else if tool == .protectPDF {
                    if let item = items.first, let url = item.url {
                        await MainActor.run {
                            passwordSheetData = PasswordSheetData(mode: .protect) { password in
                                if FoxPDFManager.shared.encryptPDF(url: url, password: password) {
                                    // Refresh item
                                    if let index = store.documents.firstIndex(where: { $0.id == item.id }) {
                                        store.documents[index].isLocked = true
                                    }
                                } else {
                                    errorMessage = String(localized: "Failed to encrypt PDF.")
                                    showError = true
                                }
                            }
                        }
                    }
                } else if tool == .unlockPDF {
                    if let item = items.first, let url = item.url {
                        if !item.isLocked {
                            await MainActor.run {
                                errorMessage = String(localized: "This file is not encrypted.")
                                showError = true
                            }
                            return
                        }
                        
                        await MainActor.run {
                            passwordSheetData = PasswordSheetData(mode: .unlock) { password in
                                if FoxPDFManager.shared.decryptPDF(url: url, password: password) {
                                    // Refresh item
                                    if let index = store.documents.firstIndex(where: { $0.id == item.id }) {
                                        store.documents[index].isLocked = false
                                    }
                                } else {
                                    errorMessage = String(localized: "Incorrect password or failed to decrypt.")
                                    showError = true
                                }
                            }
                        }
                    }
                } else if tool == .securityScan {
                    if let item = items.first {
                        await MainActor.run {
                            navigationPath.append(SecurityScanDestination(item: item))
                        }
                    }
                }
            }
        }
    }
    
    private func processImages(_ images: [UIImage], source: String) {
        guard !images.isEmpty else { return }
        if let pdfURL = FoxPDFManager.shared.createPDF(from: images, filename: "Scan") {
            let item = ScannedItem(name: pdfURL.deletingPathExtension().lastPathComponent, url: pdfURL, pageCount: images.count)
            store.addDocument(item)
            navigationPath.append(item)
        } else {
            errorMessage = String(localized: "Failed to create PDF from images.")
            showError = true
        }
    }
    
    private func processOCRImages(_ images: [UIImage]) {
        guard !images.isEmpty else { return }
        Task {
            let text = await OCRManager.shared.recognizeText(from: images)
            await MainActor.run {
                if !text.isEmpty {
                    self.ocrResultData = OCRResultData(text: text, images: images)
                } else {
                    self.errorMessage = String(localized: "No text recognized.")
                    self.showError = true
                }
            }
        }
    }
}

// MARK: - Components

struct BentoCard: View {
    let title: LocalizedStringKey
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(Circle())
                    .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
                    .padding(.leading, 8) // Shift icon right
                
                Text(title)
                    .font(.headline.bold()) // Larger font
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5) // Allow scaling down if needed
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 90) // Reduced height for compactness
            .padding(10)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

struct RecentFileCard: View {
    let item: ScannedItem
    
    var body: some View {
        VStack(alignment: .leading) {
            ZStack {
                Color.white
                Image(systemName: "doc.text.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.red.opacity(0.8))
                
                if item.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.05), radius: 2)
            
            Text(item.name)
                .font(.subheadline.bold())
                .lineLimit(1)
                .foregroundStyle(.primary)
            
            Text(item.creationDate.formatted(date: .numeric, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 140)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct PasswordInputView: View {
    let mode: PasswordSheetMode
    let onConfirm: (String) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var error: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Password", text: $password)
                    if mode == .protect {
                        SecureField("Confirm Password", text: $confirmPassword)
                    }
                } footer: {
                    if let error = error {
                        Text(LocalizedStringKey(error))
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(mode == .protect ? "Set Password" : "Enter Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        if mode == .protect {
                            if password.isEmpty {
                                error = String(localized: "Password cannot be empty")
                                return
                            }
                            if password != confirmPassword {
                                error = String(localized: "Passwords do not match")
                                return
                            }
                        }
                        onConfirm(password)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(300)])
    }
}

#Preview {
    DashboardView(selectedTab: .constant(0))
        .environmentObject(FoxDocumentStore())
}
