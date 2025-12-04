import SwiftUI
import PDFKit
import Vision

// MARK: - Data Models

struct PlacementData: Identifiable {
    let id = UUID()
    let pageImage: UIImage
    let signatureImage: UIImage
}

struct TextEditData: Equatable {
    var id = UUID()
    var originalText: String
    var newText: String
    var bounds: CGRect // PDF Page Coordinates
    var page: PDFPage
    var attributes: PatchAttributes
    
    static func == (lhs: TextEditData, rhs: TextEditData) -> Bool {
        return lhs.id == rhs.id &&
               lhs.newText == rhs.newText &&
               lhs.bounds == rhs.bounds &&
               lhs.attributes.fontSize == rhs.attributes.fontSize &&
               lhs.attributes.lineSpacing == rhs.attributes.lineSpacing &&
               lhs.attributes.letterSpacing == rhs.attributes.letterSpacing &&
               lhs.attributes.colorHex == rhs.attributes.colorHex &&
               lhs.attributes.isTransparent == rhs.attributes.isTransparent
    }
}

enum StyleTool: String, CaseIterable {
    case font = "textformat.size"
    case spacing = "arrow.left.and.right.text.vertical"
    case background = "square.dashed"
}

// MARK: - Main View

struct FoxPDFViewer: View {
    let item: ScannedItem
    var showSignInstruction: Bool = false
    var autoStartScanning: Bool = false
    var autoShowPageEditor: Bool = false
    
    @Environment(\.dismiss) var dismiss
    
    @State private var pdfDocument: PDFDocument?
    @State private var isShowingSignatureCanvas = false
    @State private var isShowingPageEditor = false
    @State private var isShowingSaveAlert = false
    @State private var isShowingDiscardAlert = false
    @State private var isShowingSignInstructionAlert = false
    @State private var isShowingEditInstruction = false
    @State private var pdfView = PDFView()
    
    // Data-driven presentation
    @State private var placementData: PlacementData?
    @State private var tempPlacementData: PlacementData?
    
    // Edit Mode State
    @State private var isEditMode = false
    @State private var isDrawMode = false // True = Draw Box, False = Scroll/Select
    @State private var textEditData: TextEditData?
    @State private var activeStyleTool: StyleTool?
    @State private var isDiscarding = false // Flag to discard changes on exit
    @FocusState private var isInputFocused: Bool
    
    // Scanning Effect State
    @State private var isScanning = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if isEditMode {
                    // Edit Mode Top Bar
                    HStack(spacing: 12) {
                        Button("Exit") {
                            isShowingDiscardAlert = true
                        }
                        .foregroundStyle(.red)
                        .font(.subheadline)
                        
                        Spacer()
                        
                        // Style Tools (Split)
                        if textEditData != nil {
                            HStack(spacing: 20) {
                                // Font Size
                                Button {
                                    withAnimation { activeStyleTool = (activeStyleTool == .font) ? nil : .font }
                                } label: {
                                    Image(systemName: "textformat.size")
                                        .font(.system(size: 16))
                                        .foregroundColor(activeStyleTool == .font ? .blue : .primary)
                                        .padding(6)
                                        .background(activeStyleTool == .font ? Color.blue.opacity(0.1) : Color.clear)
                                        .cornerRadius(6)
                                }
                                
                                // Spacing
                                Button {
                                    withAnimation { activeStyleTool = (activeStyleTool == .spacing) ? nil : .spacing }
                                } label: {
                                    Image(systemName: "arrow.left.and.right.text.vertical")
                                        .font(.system(size: 16))
                                        .foregroundColor(activeStyleTool == .spacing ? .blue : .primary)
                                        .padding(6)
                                        .background(activeStyleTool == .spacing ? Color.blue.opacity(0.1) : Color.clear)
                                        .cornerRadius(6)
                                }
                                
                                // Background Transparency (Direct Toggle)
                                Button {
                                    if var data = textEditData {
                                        data.attributes.isTransparent.toggle()
                                        textEditData = data
                                    }
                                } label: {
                                    Image(systemName: (textEditData?.attributes.isTransparent ?? false) ? "square.slash" : "square.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.primary)
                                        .padding(6)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Select/Draw Mode Button
                        Button {
                            if textEditData != nil {
                                // If box exists, clicking this clears it (Done editing)
                                textEditData = nil
                                isDrawMode = false
                            } else {
                                // Toggle Draw Mode
                                isDrawMode.toggle()
                            }
                        } label: {
                            Image(systemName: "viewfinder")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(isDrawMode || textEditData != nil ? .white : .blue)
                                .padding(6)
                                .background(isDrawMode || textEditData != nil ? Color.blue : Color.clear)
                                .clipShape(Circle())
                        }
                        
                        Button("Save") {
                            saveChanges()
                        }
                        .fontWeight(.bold)
                        .font(.subheadline)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(uiColor: .systemBackground))
                    .shadow(radius: 1)
                    
                    // Mini Slider Overlay
                    if let tool = activeStyleTool, let data = textEditData {
                        VStack {
                            switch tool {
                            case .font:
                                HStack {
                                    Text("Size").font(.caption)
                                    Slider(value: Binding(
                                        get: { data.attributes.fontSize },
                                        set: { textEditData?.attributes.fontSize = $0 }
                                    ), in: 8...72, step: 1)
                                    Text("\(Int(data.attributes.fontSize))").font(.caption).frame(width: 25)
                                }
                            case .spacing:
                                HStack {
                                    Text("Space").font(.caption)
                                    Slider(value: Binding(
                                        get: { data.attributes.letterSpacing },
                                        set: { textEditData?.attributes.letterSpacing = $0 }
                                    ), in: -2...10, step: 0.5)
                                    Text(String(format: "%.1f", data.attributes.letterSpacing)).font(.caption).frame(width: 25)
                                }
                            default: EmptyView()
                            }
                        }
                        .padding(10)
                        .background(.regularMaterial)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                
                ZStack(alignment: .bottom) {
                    PDFKitRepresentedView(
                        pdfView: $pdfView,
                        url: item.url,
                        isEditMode: $isEditMode,
                        isDrawMode: $isDrawMode,
                        textEditData: $textEditData,
                        isDiscarding: $isDiscarding,
                        onSelection: handleSelection,
                        onEditRequest: handleEditRequest
                    )
                    
                    // Scanning Effect Overlay
                    if isScanning {
                        ScanningEffectView()
                            .transition(.opacity)
                            .zIndex(100)
                    }
                    
                    // Bottom Edit Toolbar (Input Field)
                    if let data = textEditData {
                        VStack(spacing: 0) {
                            Divider()
                            HStack(spacing: 12) {
                                // Delete Button
                                Button {
                                    isDiscarding = true
                                    textEditData = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.red)
                                }
                                
                                TextField("Enter text...", text: Binding(
                                    get: { data.newText },
                                    set: { textEditData?.newText = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .focused($isInputFocused)
                                .submitLabel(.done)
                                
                                // Done Button
                                Button {
                                    isInputFocused = false
                                    // Commit changes (handled by textEditData binding updates)
                                    textEditData = nil // Exit edit mode for this box
                                } label: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.green)
                                }
                            }
                            .padding()
                            .background(Color(uiColor: .systemBackground))
                        }
                        .transition(.move(edge: .bottom))
                        .onAppear {
                            isInputFocused = true
                        }
                    }
                }
            }
        }
        .onAppear {
            setupDocument()
            if showSignInstruction {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isShowingSignInstructionAlert = true
                }
            }
            if autoStartScanning {
                // Delay slightly to ensure view is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    startScanningEffect()
                }
            }
            if autoShowPageEditor {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isShowingPageEditor = true
                }
            }
        }
        .navigationTitle(isEditMode ? "" : item.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(isEditMode)
        .toolbar {
            if !isEditMode {
                ToolbarItem(placement: .primaryAction) {
                    HStack {
                        Button {
                            startScanningEffect()
                        } label: {
                            Label("Edit Text", systemImage: "pencil.and.scribble")
                        }
                        
                        Button {
                            if pdfDocument == nil, let url = item.url {
                                pdfDocument = PDFDocument(url: url)
                            }
                            if pdfDocument == nil { pdfDocument = pdfView.document }
                            isShowingPageEditor = true
                        } label: {
                            Label("Pages", systemImage: "square.grid.2x2")
                        }
                        
                        Button {
                            isShowingSignatureCanvas = true
                        } label: {
                            Label("Sign", systemImage: "signature")
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ShareLink(item: item.url!) {
                            Label(String(localized: "Share PDF"), systemImage: "square.and.arrow.up")
                        }
                        
                        Button {
                            printPDF()
                        } label: {
                            Label(String(localized: "Print"), systemImage: "printer")
                        }
                        
                        Button {
                            saveToPhotos()
                        } label: {
                            Label(String(localized: "Export as Images"), systemImage: "photo")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .alert(String(localized: "Saved"), isPresented: $isShowingSaveAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(String(localized: "Changes saved successfully."))
        }
        .alert(String(localized: "Discard Changes?"), isPresented: $isShowingDiscardAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Discard", role: .destructive) {
                exitEditMode()
            }
        } message: {
            Text(String(localized: "You have unsaved changes. Are you sure you want to discard them?"))
        }
        .sheet(isPresented: $isShowingPageEditor) {
            if let document = pdfDocument ?? pdfView.document ?? (item.url != nil ? PDFDocument(url: item.url!) : nil) {
                PDFPageEditorView(document: document)
            }
        }
        .sheet(isPresented: $isShowingSignatureCanvas, onDismiss: {
            if let data = tempPlacementData {
                placementData = data
                tempPlacementData = nil
            }
        }) {
            SignatureCanvasView { signatureImage in
                preparePlacement(with: signatureImage)
            }
        }
        .fullScreenCover(item: $placementData) { data in
            SignaturePlacementView(
                pageImage: data.pageImage,
                signatureImage: data.signatureImage,
                onConfirm: { normalizedRect, rotatedImage in
                    addSignatureToPDF(image: rotatedImage, normalizedRect: normalizedRect)
                    placementData = nil
                },
                onCancel: {
                    placementData = nil
                }
            )
        }
        .overlay {
            if isShowingSignInstructionAlert {
                SignInstructionView(isPresented: $isShowingSignInstructionAlert)
            }
            if isShowingEditInstruction {
                EditModeInstructionView(isPresented: $isShowingEditInstruction)
                    .zIndex(200)
            }
        }
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
    }
    
    func setupDocument() {
        if let url = item.url {
            pdfDocument = PDFDocument(url: url)
            pdfView.document = pdfDocument
            pdfView.autoScales = true
            pdfView.maxScaleFactor = 4.0
            pdfView.minScaleFactor = pdfView.scaleFactorForSizeToFit
        }
    }
    
    func startScanningEffect() {
        // Haptic Feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        withAnimation {
            isScanning = true
        }
        
        // Delay entering edit mode slightly to let animation start
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isEditMode = true
            isDrawMode = false
        }
        
        // End scanning after animation (1 loop * 2.0s = 2.0s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                isScanning = false
                isShowingEditInstruction = true
            }
        }
    }
    
    // MARK: - Logic
    
    func handleSelection(rect: CGRect, page: PDFPage) {
        // Called when user draws a new box
        detectTextAndStyle(in: rect, on: page) { text, fontSize in
            let attributes = PatchAttributes(
                text: text,
                fontSize: fontSize,
                fontName: "Helvetica",
                colorHex: "#000000",
                lineSpacing: 0,
                letterSpacing: 0,
                isTransparent: false
            )
            
            self.textEditData = TextEditData(
                originalText: text,
                newText: text,
                bounds: rect,
                page: page,
                attributes: attributes
            )
        }
    }
    
    func handleEditRequest(annotation: PatchAnnotation) {
        // Called when user double taps an existing patch
        guard let page = annotation.page,
              let json = annotation.contents,
              let data = json.data(using: .utf8),
              let attributes = try? JSONDecoder().decode(PatchAttributes.self, from: data) else { return }
        
        self.textEditData = TextEditData(
            originalText: attributes.text,
            newText: attributes.text,
            bounds: annotation.bounds,
            page: page,
            attributes: attributes
        )
        
        // Remove the annotation temporarily while editing
        page.removeAnnotation(annotation)
    }
    
    func detectTextAndStyle(in rect: CGRect, on page: PDFPage, completion: @escaping (String, CGFloat) -> Void) {
        let pageBounds = page.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageBounds.size)
        let pageImage = renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(pageBounds)
            ctx.cgContext.translateBy(x: 0.0, y: pageBounds.size.height)
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
        
        let scale = pageImage.scale
        let imageY = pageBounds.height - (rect.origin.y + rect.height)
        let cropRect = CGRect(x: rect.origin.x, y: imageY, width: rect.width, height: rect.height)
        let scaledCropRect = CGRect(x: cropRect.origin.x * scale, y: cropRect.origin.y * scale, width: cropRect.width * scale, height: cropRect.height * scale)
        
        guard let cgImage = pageImage.cgImage?.cropping(to: scaledCropRect) else {
            completion("", 12)
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion("", 12)
                return
            }
            
            let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            
            var totalHeight: CGFloat = 0
            var count: CGFloat = 0
            
            for obs in observations {
                let h = obs.boundingBox.height * rect.height
                totalHeight += h
                count += 1
            }
            
            let avgHeight = count > 0 ? totalHeight / count : 12
            // Use raw height as font size (User feedback: 0.8 was too small)
            let adjustedFontSize = avgHeight
            
            DispatchQueue.main.async {
                completion(text, adjustedFontSize > 0 ? adjustedFontSize : 12)
            }
        }
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US", "fr-FR", "de-DE", "es-ES", "it-IT", "pt-BR"]
        
        try? VNImageRequestHandler(cgImage: cgImage, options: [:].self).perform([request])
    }
    
    func saveChanges() {
        if let document = pdfView.document, let url = item.url {
            document.write(to: url)
            isShowingSaveAlert = true
        }
    }
    
    func exitEditMode() {
        isDiscarding = true
        textEditData = nil // Trigger cancel
        isEditMode = false
        isDrawMode = false
        activeStyleTool = nil
        setupDocument() // Reload to discard unsaved changes
    }
    
    // ... (Signature methods kept same)
    func preparePlacement(with signature: UIImage) {
        guard let currentPage = pdfView.currentPage ?? pdfView.document?.page(at: 0) else { return }
        let pageBounds = currentPage.bounds(for: .mediaBox)
        let screenSize = UIScreen.main.bounds.size
        let scale = UIScreen.main.scale
        let maxDimension = max(screenSize.width, screenSize.height) * scale
        let aspectRatio = pageBounds.width / pageBounds.height
        var targetSize: CGSize
        if aspectRatio > 1 {
            targetSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            targetSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let thumbnail = renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(CGRect(origin: .zero, size: targetSize))
            ctx.cgContext.translateBy(x: 0.0, y: targetSize.height)
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
            ctx.cgContext.scaleBy(x: targetSize.width / pageBounds.width, y: targetSize.height / pageBounds.height)
            currentPage.draw(with: .mediaBox, to: ctx.cgContext)
        }
        tempPlacementData = PlacementData(pageImage: thumbnail, signatureImage: signature)
    }
    
    func addSignatureToPDF(image: UIImage, normalizedRect: CGRect) {
        guard let document = pdfView.document, let currentPage = pdfView.currentPage else { return }
        let pageBounds = currentPage.bounds(for: .mediaBox)
        let width = normalizedRect.width * pageBounds.width
        let height = normalizedRect.height * pageBounds.height
        let x = normalizedRect.origin.x * pageBounds.width
        let viewBottomY = normalizedRect.origin.y + normalizedRect.height
        let y = pageBounds.height * (1.0 - viewBottomY)
        let bounds = CGRect(x: x, y: y, width: width, height: height)
        let annotation = ImageStampAnnotation(bounds: bounds, image: image)
        currentPage.addAnnotation(annotation)
        pdfView.setNeedsDisplay()
        if let url = item.url { document.write(to: url) }
    }
    
    func saveToPhotos() {
        guard let document = pdfView.document else { return }
        for i in 0..<document.pageCount {
            if let page = document.page(at: i) {
                let pageBounds = page.bounds(for: .mediaBox)
                let renderer = UIGraphicsImageRenderer(size: pageBounds.size)
                let image = renderer.image { ctx in
                    UIColor.white.set()
                    ctx.fill(pageBounds)
                    ctx.cgContext.translateBy(x: 0.0, y: pageBounds.size.height)
                    ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
                    page.draw(with: .mediaBox, to: ctx.cgContext)
                }
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            }
        }
        isShowingSaveAlert = true
    }
    
    func printPDF() {
        guard let url = item.url else { return }
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = item.name
        printController.printInfo = printInfo
        printController.printingItem = url
        printController.present(animated: true, completionHandler: nil)
    }
}

// MARK: - PDFKit Represented View

struct PDFKitRepresentedView: UIViewRepresentable {
    @Binding var pdfView: PDFView
    var url: URL?
    @Binding var isEditMode: Bool
    @Binding var isDrawMode: Bool
    @Binding var textEditData: TextEditData?
    @Binding var isDiscarding: Bool
    
    var onSelection: (CGRect, PDFPage) -> Void
    var onEditRequest: (PatchAnnotation) -> Void
    
    func makeUIView(context: Context) -> PDFView {
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        // Setup Drawing Overlay (Transparent layer for gestures)
        let overlay = UIView()
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = .clear
        overlay.isHidden = true
        pdfView.addSubview(overlay)
        context.coordinator.drawingOverlay = overlay
        
        // Gestures (Attached to Overlay, NOT PDFView)
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        overlay.addGestureRecognizer(panGesture)
        
        // Tap Gesture (Still on PDFView for selecting existing boxes)
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tapGesture.delegate = context.coordinator
        tapGesture.cancelsTouchesInView = false // Critical: Don't block PDFView's internal gestures
        pdfView.addGestureRecognizer(tapGesture)
        
        // Observers for Layout Changes
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.handleLayoutChange), name: .PDFViewPageChanged, object: pdfView)
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.handleLayoutChange), name: .PDFViewScaleChanged, object: pdfView)
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.handleLayoutChange), name: .PDFViewVisiblePagesChanged, object: pdfView)
        
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updateState()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate, UITextViewDelegate, UIScrollViewDelegate {
        var parent: PDFKitRepresentedView
        var selectionView: ResizableSelectionView?
        var initialPoint: CGPoint = .zero
        var selectedAnnotation: PatchAnnotation?
        var drawingOverlay: UIView?
        
        // Editing Overlay
        var editOverlayView: ResizableSelectionView?
        var currentEditData: TextEditData? // Local copy to track state transitions
        
        init(parent: PDFKitRepresentedView) {
            self.parent = parent
        }
        
        func updateState() {
            let pdfView = parent.pdfView
            
            // Strict Mode Switching via Overlay
            let isDrawing = parent.isDrawMode && parent.textEditData == nil
            
            // 1. Toggle Overlay Visibility
            drawingOverlay?.isHidden = !isDrawing
            drawingOverlay?.isUserInteractionEnabled = isDrawing
            if let overlay = drawingOverlay {
                pdfView.bringSubviewToFront(overlay)
            }
            
            // Handle Edit Mode State
            if let data = parent.textEditData {
                // We are editing
                currentEditData = data // Sync local copy
                if editOverlayView == nil {
                    startEditing(data)
                } else {
                    updateEditing(data)
                }
            } else {
                // Not editing (Parent set data to nil)
                if let overlay = editOverlayView, let data = currentEditData {
                    if parent.isDiscarding {
                        cancelEditing(overlay)
                        // Reset discard flag after processing
                        DispatchQueue.main.async {
                            self.parent.isDiscarding = false
                        }
                    } else {
                        endEditing(overlay, with: data)
                    }
                }
                currentEditData = nil
            }
            
            // Clear selection if exiting edit mode completely
            if !parent.isEditMode {
                clearSelection()
            }
        }
        
        // MARK: - Editing Logic
        
        func startEditing(_ data: TextEditData) {
            let viewRect = parent.pdfView.convert(data.bounds, from: data.page)
            
            let overlay = ResizableSelectionView(frame: viewRect)
            overlay.isEditing = true
            overlay.onFrameChange = { [weak self] newFrame in
                guard let self = self, let page = self.parent.textEditData?.page else { return }
                let pageRect = self.parent.pdfView.convert(newFrame, to: page)
                self.parent.textEditData?.bounds = pageRect
            }
            
            parent.pdfView.addSubview(overlay)
            editOverlayView = overlay
            
            // Initial Update
            updateEditing(data)
        }
        
        func updateEditing(_ data: TextEditData) {
            guard let overlay = editOverlayView else { return }
            
            // Update Frame
            let viewRect = parent.pdfView.convert(data.bounds, from: data.page)
            if abs(viewRect.width - overlay.frame.width) > 1 || abs(viewRect.height - overlay.frame.height) > 1 {
                 // Only update if significantly different
            }
            
            // Update Preview Image (WYSIWYG)
            // We render the patch image using the current attributes and text
            // But we need to render it for the SCREEN size (scaled), or render high-res and let ImageView scale it?
            // Rendering at PDF size and letting ImageView scale is better for consistency with final output.
            let image = FoxPDFViewer.renderPatchImage(data: data)
            overlay.imageView.image = image
            
            // Update Transparency (Overlay Alpha)
            overlay.alpha = data.attributes.isTransparent ? 0.7 : 1.0
        }
        
        func endEditing(_ overlay: ResizableSelectionView, with data: TextEditData) {
            // 1. Generate Image
            let image = FoxPDFViewer.renderPatchImage(data: data)
            
            // 2. Create Annotation
            let annotation = PatchAnnotation(bounds: data.bounds, image: image, attributes: data.attributes)
            data.page.addAnnotation(annotation)
            
            // 3. Cleanup
            cleanupEditing(overlay)
        }
        
        func cancelEditing(_ overlay: ResizableSelectionView) {
            cleanupEditing(overlay)
        }
        
        func cleanupEditing(_ overlay: ResizableSelectionView) {
            overlay.removeFromSuperview()
            editOverlayView = nil
            parent.pdfView.setNeedsDisplay()
        }
        
        @objc func handleLayoutChange() {
            updateOverlayPosition()
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            updateOverlayPosition()
        }
        
        func updateOverlayPosition() {
            guard let data = parent.textEditData, let overlay = editOverlayView else { return }
            let viewRect = parent.pdfView.convert(data.bounds, from: data.page)
            overlay.frame = viewRect
            
            // Update Font Size on Zoom
            updateEditing(data)
        }
        
        // MARK: - UITextViewDelegate
        // Removed as we use SwiftUI TextField now
        
        // MARK: - Gestures (Selection)
        
        func clearSelection() {
            selectionView?.removeFromSuperview()
            selectionView = nil
            selectedAnnotation = nil
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard parent.isEditMode else { return false }
            // If touching the edit overlay, let it handle touches (it has its own gestures)
            if let overlay = editOverlayView, touch.view?.isDescendant(of: overlay) == true {
                return false
            }
            if let selectionView = selectionView, touch.view?.isDescendant(of: selectionView) == true {
                return false
            }
            return true
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard parent.isEditMode, !parent.isDrawMode else { return }
            
            // If keyboard is showing, dismiss it first
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            
            let location = gesture.location(in: parent.pdfView)
            guard let page = parent.pdfView.page(for: location, nearest: true) else { return }
            let pagePoint = parent.pdfView.convert(location, to: page)
            
            if let annotation = page.annotation(at: pagePoint) as? PatchAnnotation {
                parent.onEditRequest(annotation)
            }
        }
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            // Drawing logic (Happens on Overlay)
            let location = gesture.location(in: parent.pdfView)
            
            switch gesture.state {
            case .began:
                clearSelection()
                initialPoint = location
                let view = ResizableSelectionView(frame: CGRect(origin: location, size: .zero))
                parent.pdfView.addSubview(view)
                selectionView = view
                
            case .changed:
                guard let view = selectionView else { return }
                let rect = CGRect(x: min(initialPoint.x, location.x),
                                  y: min(initialPoint.y, location.y),
                                  width: abs(location.x - initialPoint.x),
                                  height: abs(location.y - initialPoint.y))
                view.frame = rect
                
            case .ended:
                guard let view = selectionView else { return }
                if view.frame.width > 20 && view.frame.height > 20 {
                    let rect = view.frame
                    let center = CGPoint(x: rect.midX, y: rect.midY)
                    if let page = parent.pdfView.page(for: center, nearest: true) {
                        let pageRect = parent.pdfView.convert(rect, to: page)
                        parent.onSelection(pageRect, page)
                    }
                    clearSelection()
                } else {
                    clearSelection()
                }
            default: break
            }
        }
    }
}

// MARK: - Resizable Selection View (Upgraded)

class ResizableSelectionView: UIView {
    var isEditing = false
    var onFrameChange: ((CGRect) -> Void)?
    
    let imageView = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupUI() {
        // Image View for Content (Only used when NOT editing text directly)
        imageView.contentMode = .scaleToFill // Stretch to fit box
        imageView.frame = bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(imageView)
        
        // Border (Red Dashed)
        let borderLayer = CAShapeLayer()
        borderLayer.strokeColor = UIColor.red.cgColor
        borderLayer.lineDashPattern = [4, 2]
        borderLayer.frame = bounds
        borderLayer.fillColor = nil
        borderLayer.path = UIBezierPath(rect: bounds).cgPath
        layer.addSublayer(borderLayer)
        
        // Handles
        addHandles()
        
        // Top-Right Move Handle (Arrow Icon)
        let moveHandle = UIImageView(image: UIImage(systemName: "arrow.up.and.down.and.arrow.left.and.right"))
        moveHandle.tintColor = .white
        moveHandle.backgroundColor = .red
        moveHandle.layer.cornerRadius = 10
        moveHandle.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        moveHandle.contentMode = .center
        moveHandle.preferredSymbolConfiguration = UIImage.SymbolConfiguration(scale: .small)
        addSubview(moveHandle)
        moveHandle.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            moveHandle.centerXAnchor.constraint(equalTo: trailingAnchor),
            moveHandle.centerYAnchor.constraint(equalTo: topAnchor),
            moveHandle.widthAnchor.constraint(equalToConstant: 24),
            moveHandle.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        // Gestures for Dragging
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
    }
    
    func addHandles() {
        let positions: [CGPoint] = [
            CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0),
            CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1)
        ]
        for pos in positions {
            let handle = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
            handle.backgroundColor = .white
            handle.layer.borderColor = UIColor.red.cgColor
            handle.layer.borderWidth = 1
            handle.layer.cornerRadius = 5
            addSubview(handle)
            handle.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                NSLayoutConstraint(item: handle, attribute: .centerX, relatedBy: .equal, toItem: self, attribute: pos.x == 0 ? .leading : .trailing, multiplier: 1, constant: 0),
                NSLayoutConstraint(item: handle, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: pos.y == 0 ? .top : .bottom, multiplier: 1, constant: 0)
            ])
        }
    }
    
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard isEditing else { return }
        let translation = gesture.translation(in: superview)
        
        switch gesture.state {
        case .changed:
            center = CGPoint(x: center.x + translation.x, y: center.y + translation.y)
            gesture.setTranslation(.zero, in: superview)
            onFrameChange?(frame)
            
            // Update border path
            if let borderLayer = layer.sublayers?.first(where: { $0 is CAShapeLayer }) as? CAShapeLayer {
                borderLayer.frame = bounds
                borderLayer.path = UIBezierPath(rect: bounds).cgPath
            }
        default: break
        }
    }
    
    override var frame: CGRect {
        didSet {
            if let borderLayer = layer.sublayers?.first(where: { $0 is CAShapeLayer }) as? CAShapeLayer {
                borderLayer.frame = bounds
                borderLayer.path = UIBezierPath(rect: bounds).cgPath
            }
        }
    }
}

// MARK: - Scanning Effect View (Dynamic)

struct ScanningEffectView: View {
    @State private var offset: CGFloat = -UIScreen.main.bounds.height / 2
    @State private var progress: CGFloat = 0.0
    @State private var gridOffset: CGFloat = 0.0
    
    var body: some View {
        ZStack {
            // Dynamic Scrolling Grid
            GeometryReader { geo in
                GridBackground()
                    .stroke(Color.red.opacity(0.4), lineWidth: 0.5)
                    .offset(y: gridOffset)
                    .onAppear {
                        withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                            gridOffset = 40 // Scroll by one grid cell height
                        }
                    }
            }
            .mask(
                GeometryReader { geo in
                    Rectangle()
                        .frame(height: geo.size.height * progress)
                        .frame(maxWidth: .infinity, alignment: .top)
                }
            )
            
            Color.black.opacity(0.2).ignoresSafeArea()
            
            // Scanning Line with Glow
            VStack(spacing: 0) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .red.opacity(0.8)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 80)
                
                Rectangle()
                    .fill(Color.red)
                    .frame(height: 2)
                    .shadow(color: .red, radius: 10, x: 0, y: 0)
                    .shadow(color: .white, radius: 2, x: 0, y: 0)
            }
            .offset(y: offset)
            .onAppear {
                // 1 Loop, 2.0s
                withAnimation(.linear(duration: 2.0)) {
                    offset = UIScreen.main.bounds.height / 2 + 100
                    progress = 1.0
                }
            }
            
            Text("Analyzing Document...")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.red.opacity(0.7))
                .cornerRadius(10)
        }
    }
}

struct GridBackground: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 40
        
        // Draw extra height for scrolling
        for x in stride(from: 0, to: rect.width, by: spacing) {
            path.move(to: CGPoint(x: x, y: -spacing))
            path.addLine(to: CGPoint(x: x, y: rect.height + spacing))
        }
        
        for y in stride(from: -spacing, to: rect.height + spacing, by: spacing) {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        return path
    }
}

// MARK: - Helpers

extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

struct SignInstructionView: View {
    @Binding var isPresented: Bool
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea().onTapGesture { isPresented = false }
            VStack(spacing: 24) {
                Text("Sign Document")
                    .font(.title3.bold())
                
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "signature")
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                        
                        Text("Tap the signature icon in the top right corner to start signing.")
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Text("You can scroll to the desired page before signing.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Button {
                    isPresented = false
                } label: {
                    Text("Got it")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
            .padding(24)
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(20)
            .padding(32)
        }
        .transition(.opacity)
    }
}

struct EditModeInstructionView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
                .onTapGesture { isPresented = false }
            
            VStack(spacing: 24) {
                Text("Edit Mode Guide")
                    .font(.title2.bold())
                
                VStack(alignment: .leading, spacing: 16) {
                    instructionRow(icon: "viewfinder", color: .blue, text: String(localized: "Tap Blue Box to frame text to modify."))
                    instructionRow(icon: "square.dashed", color: .primary, text: String(localized: "Toggle background transparency."))
                    instructionRow(icon: "textformat.size", color: .blue, text: String(localized: "Adjust font size & spacing."))
                }
                
                Text(String(localized: "Tap the blue box in the top right to frame the text you want to modify. Use the transparency toggle to see the original text underneath for alignment. Then, adjust the font size and spacing to match the original document."))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                
                Button {
                    isPresented = false
                } label: {
                    Text("Got it")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
            .padding(24)
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(20)
            .padding(32)
        }
        .transition(.opacity)
    }
    
    func instructionRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}

class ImageStampAnnotation: PDFAnnotation {
    var image: UIImage?
    init(bounds: CGRect, image: UIImage) {
        self.image = image
        super.init(bounds: bounds, forType: .stamp, withProperties: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        guard let image = image, let cgImage = image.cgImage else { return }
        context.saveGState()
        context.draw(cgImage, in: bounds)
        context.restoreGState()
    }
}

// Helper for Rendering
extension FoxPDFViewer {
    static func renderPatchImage(data: TextEditData) -> UIImage {
        let width = data.bounds.width
        let height = data.bounds.height
        let font = UIFont(name: data.attributes.fontName, size: data.attributes.fontSize) ?? UIFont.systemFont(ofSize: data.attributes.fontSize)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineSpacing = data.attributes.lineSpacing
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(hex: data.attributes.colorHex) ?? .black,
            .paragraphStyle: paragraphStyle,
            .kern: data.attributes.letterSpacing
        ]
        
        let attributedText = NSAttributedString(string: data.newText, attributes: attrs)
        let size = CGSize(width: width, height: height)
        
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            // Always fill with opaque white (User requirement: Final result is opaque)
            UIColor.white.set()
            ctx.fill(CGRect(origin: .zero, size: size))
            
            attributedText.draw(in: CGRect(origin: CGPoint(x: 0, y: 2), size: size))
        }
    }
}
