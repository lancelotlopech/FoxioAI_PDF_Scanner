# AI Development Guide & Technical Retrospective

This document serves as a comprehensive guide for AI assistants and developers working on the **PDFScanner** project. It outlines the project architecture, core technical implementations, known pitfalls, and best practices to ensure consistency and stability in future development.

---

## 1. Project Architecture

- **Framework**: SwiftUI + MVVM
- **Minimum iOS Version**: iOS 16.0+
- **Core Dependencies**: PDFKit, Vision, VisionKit, PencilKit, StoreKit 2, WebKit.

### Key Managers (Singletons)
- **`FoxPDFManager`**: Handles low-level PDF operations (creation, merging, encryption, security scanning).
- **`OCRManager`**: Wraps `Vision` framework for text recognition.
- **`SubscriptionManager`**: Manages StoreKit 2 transactions and VIP status.
- **`DocumentStore`**: Manages file persistence and metadata.
- **`RatingManager`**: Manages smart rating prompts and frequency logic.

---

## 2. Core Technical Implementations

### 2.1 PDF Creation & Manipulation (`FoxPDFManager.swift`)
- **Image to PDF**: Uses `UIGraphicsBeginPDFContextToData`. Each image is drawn into a PDF page context matching the image size.
- **Merging**: Uses `PDFDocument` to insert pages from source documents into a destination document.
- **Office to PDF**:
  - Uses `WKWebView` to load the document.
  - **Critical**: Injects CSS (`-webkit-print-color-adjust: exact`) to ensure background colors are preserved.
  - Uses `WKPDFConfiguration` to generate the PDF data.

### 2.2 OCR (Text Recognition) (`OCRManager.swift`)
- **Framework**: `Vision` (`VNRecognizeTextRequest`).
- **Configuration**:
  - `recognitionLevel = .accurate`
  - `usesLanguageCorrection = true`
  - **Languages**: Prioritizes `["zh-Hans", "zh-Hant", "en-US", "fr-FR", "de-DE", "es-ES"]`.
- **Usage**: Returns a plain string. Future improvements could map text to bounding boxes for overlay.

### 2.3 Electronic Signature (`SignatureCanvasView` & `SignaturePlacementView`)
- **Capture**:
  - Uses `PKCanvasView` (PencilKit) to capture drawing.
  - Converts drawing to `UIImage` using `drawing.image(from: bounds, scale: ...)`.
- **Placement**:
  - **UI**: Uses a transparent overlay on top of the PDF page image.
  - **Gestures**: `DragGesture` for position, `MagnificationGesture` for scaling.
  - **Normalization**:
    - The signature position and size are converted to **normalized coordinates (0.0 - 1.0)** relative to the page image size.
    - This ensures the signature is placed correctly regardless of the actual PDF page resolution.
    - **Formula**: `normX = (position.x - width/2) / pageSize.width`

### 2.4 Subscription System (`SubscriptionManager.swift`)
- **Framework**: StoreKit 2.
- **Status Management**:
  - `isPremium` is the source of truth.
  - **Critical**: Initialization must be **synchronous** for cached values to prevent UI flickering.
  - **Debug VIP**: Allows temporary VIP access via a hidden trigger (stored in `UserDefaults`).

### 2.5 Smart Rating System (`RatingManager.swift` & `RatingPopupView.swift`)
- **Strategy**: Custom in-app popup for pre-screening, then branching based on source.
- **Flow**:
  - **Low Rating (1-3 stars)**: Redirects to internal `FeedbackView` (intercepts bad reviews).
  - **High Rating (4-5 stars)**:
    - **Active Source (Settings)**: Redirects to App Store (`itms-apps://`) to guarantee user can write a review.
    - **Passive Source (Auto-popup)**: Closes custom popup and triggers system `requestReview` (non-intrusive, subject to Apple's frequency limits).
- **Triggers**:
  - **Active**: "Rate Us" button in Settings.
  - **Passive**: After successful document save (7 days interval, once per version).

---

## 3. Troubleshooting & Pitfalls (Avoid These Mistakes)

### 3.1 UI Flickering on Launch (Subscription Status)
- **Problem**: The VIP icon/lock appears briefly on launch and then disappears.
- **Cause**: `SubscriptionManager` initialized `isPremium = false` by default, then started an **asynchronous** `Task` to check status. The UI rendered the default state before the task completed.
- **Fix**:
  - Initialize `isPremium` **synchronously** in `init()` by reading from `UserDefaults` (`cached_is_premium`).
  - Update the cache whenever the status changes.
  - **Rule**: Never rely solely on async tasks for initial UI state if a cached value is available.

### 3.2 App Launch Blocking (Splash Screen)
- **Problem**: App stuck on a yellow screen (SplashView).
- **Cause**:
  - `SplashView` relied on an image asset (`LoadingImage`) that might be missing or corrupt.
  - If the image failed to load or the timer logic was blocked, `isActive` never flipped to `true`.
- **Fix**:
  - **Fallback**: Added a system image fallback (`doc.viewfinder`) if the named asset is missing.
  - **Default State**: In `PDFScannerApp`, `isAppActive` defaults to `false` (to show Splash), but the Splash logic must be robust.
  - **Rule**: Splash screens must have a failsafe timeout to force entry into the main app.

### 3.3 PDF Coordinate Systems
- **Pitfall**: PDF coordinates start at the **bottom-left**. UIKit/SwiftUI coordinates start at the **top-left**.
- **Impact**: When drawing annotations or signatures, the Y-axis must be flipped.
- **Fix**: Use `ctx.cgContext.translateBy(x: 0, y: height)` and `ctx.cgContext.scaleBy(x: 1.0, y: -1.0)` when drawing into a PDF context.

### 3.4 File Paths & Persistence
- **Pitfall**: Hardcoding absolute paths or assuming file existence.
- **Fix**: Always use `FileManager.default.urls(for: .documentDirectory, ...)` to get the current sandbox path.
- **Note**: `FeedbackView` previously attempted to write to a non-existent path. Always ensure directories exist before writing.

### 3.5 App Icon Replacement
- **Pitfall**: Manually resizing and replacing App Icons is error-prone and tedious.
- **Solution**: Use a script (e.g., `generate_icons.py`) to automate the process.
- **Process**:
  1. Place the high-res icon (1024x1024) as `icon.png` in the project root.
  2. Run the script to generate all required sizes based on `Contents.json`.
  3. **Important**: Ensure the script handles file paths correctly relative to its execution location.

---

## 4. Best Practices for AI Assistants

1.  **Context Scanning**: Before modifying a file, scan related Managers and Views to understand dependencies.
2.  **Defensive Coding**:
    - Always handle `nil` optionals for assets (Images, Colors).
    - Use `if let` or `guard` when dealing with file system operations.
3.  **State Management**:
    - Use `@StateObject` for owners of data (e.g., `DocumentStore` in `App`).
    - Use `@ObservedObject` for dependencies.
    - Updates to `@Published` properties must happen on the **Main Actor**.
4.  **User Experience**:
    - Avoid blocking the main thread. Use `Task.detached` for heavy work (like PDF rendering), but update UI on `MainActor`.
    - Provide feedback (loading spinners) for long operations (OCR, Conversion).

---

## 5. Future Roadmap / Pending Tasks

- [ ] **PDF Text Editing**: Implement direct text editing on PDF pages (complex, requires parsing PDF content stream).
- [ ] **Cloud Sync**: Integrate iCloud Drive for document synchronization.
- [ ] **Batch OCR**: Optimize OCR for large documents using background tasks.

---

*Generated by AI Assistant on 2025/12/11*
