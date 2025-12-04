import SwiftUI

struct SignaturePlacementView: View {
    let pageImage: UIImage
    let signatureImage: UIImage
    var onConfirm: (CGRect, UIImage) -> Void
    var onCancel: () -> Void
    
    @State private var position: CGPoint = .zero
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var imageSize: CGSize = .zero
    @State private var showInstructions = true
    
    // Rotation State
    @State private var currentSignatureImage: UIImage?
    
    private let initialWidthRatio: CGFloat = 0.4
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    Image(uiImage: pageImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .background(GeometryReader { proxy in
                            Color.clear.onAppear {
                                imageSize = proxy.size
                            }
                            .onChange(of: proxy.size) { _, newSize in
                                imageSize = newSize
                            }
                        })
                        .overlay {
                            // We use a transparent overlay to host the signature
                            ZStack {
                                if let signature = currentSignatureImage {
                                    Image(uiImage: signature)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: imageSize.width * initialWidthRatio)
                                        .background(Color.red.opacity(0.1)) // Highlight background
                                        .overlay(
                                            Rectangle()
                                                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6])) // Dashed border
                                                .foregroundStyle(.red)
                                        )
                                        .contentShape(Rectangle())
                                        .scaleEffect(scale)
                                        .position(position)
                                        .gesture(
                                            DragGesture()
                                                .onChanged { value in
                                                    position = value.location
                                                }
                                        )
                                        .gesture(
                                            MagnificationGesture()
                                                .onChanged { value in
                                                    scale = lastScale * value
                                                }
                                                .onEnded { _ in
                                                    lastScale = scale
                                                }
                                        )
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .clipped()
                            
                            // Instructions Overlay
                            if showInstructions {
                                VStack {
                                    HStack(alignment: .top, spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Single finger to drag and move")
                                            Text("Pinch with two fingers to zoom")
                                        }
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.red.opacity(0.8))
                                        
                                        Button {
                                            withAnimation {
                                                showInstructions = false
                                            }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(Color.red.opacity(0.8))
                                        }
                                    }
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(12)
                                    .padding(.top, 20)
                                    
                                    Spacer()
                                }
                            }
                        }
                }
            }
            .navigationTitle("Place Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Button {
                            rotateSignature(left: true)
                        } label: {
                            Label("Rotate Left", systemImage: "arrow.counterclockwise")
                        }
                        .foregroundStyle(.white)
                        
                        Spacer()
                        
                        Button {
                            rotateSignature(left: false)
                        } label: {
                            Label("Rotate Right", systemImage: "arrow.clockwise")
                        }
                        .foregroundStyle(.white)
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        confirmPlacement()
                    }
                }
            }
            .onAppear {
                currentSignatureImage = signatureImage
            }
            .onChange(of: imageSize) { _, newSize in
                if position == .zero && newSize != .zero {
                    position = CGPoint(x: newSize.width / 2, y: newSize.height / 2)
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.black, for: .bottomBar)
            .toolbarBackground(.visible, for: .bottomBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .bottomBar)
        }
    }
    
    func rotateSignature(left: Bool) {
        guard let current = currentSignatureImage else { return }
        if let rotated = current.rotated(by: left ? -90 : 90) {
            currentSignatureImage = rotated
        }
    }
    
    func confirmPlacement() {
        guard imageSize != .zero, let signature = currentSignatureImage else { return }
        
        // Calculate normalized rect
        let baseWidth = imageSize.width * initialWidthRatio
        let signatureAspect = signature.size.height / signature.size.width
        let baseHeight = baseWidth * signatureAspect
        
        let finalWidth = baseWidth * scale
        let finalHeight = baseHeight * scale
        
        let originX = position.x - (finalWidth / 2)
        let originY = position.y - (finalHeight / 2)
        
        let normX = originX / imageSize.width
        let normY = originY / imageSize.height
        let normW = finalWidth / imageSize.width
        let normH = finalHeight / imageSize.height
        
        let normalizedRect = CGRect(x: normX, y: normY, width: normW, height: normH)
        
        onConfirm(normalizedRect, signature)
    }
}

// Helper extension
extension UIImage {
    func rotated(by degrees: CGFloat) -> UIImage? {
        let radians = degrees * .pi / 180
        var newSize = CGRect(origin: .zero, size: self.size)
            .applying(CGAffineTransform(rotationAngle: radians)).size
        // Trim off the extremely small float value to prevent core graphics from rounding it up
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        let context = UIGraphicsGetCurrentContext()!

        // Move origin to middle
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        // Rotate around middle
        context.rotate(by: radians)
        // Draw the image at its center
        self.draw(in: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }
}
