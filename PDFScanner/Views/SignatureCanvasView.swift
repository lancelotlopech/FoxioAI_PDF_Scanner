import SwiftUI
import PencilKit

struct SignatureCanvasView: View {
    @Environment(\.dismiss) var dismiss
    @State private var canvasView = PKCanvasView()
    var onSave: (UIImage) -> Void
    
    // Drawing State
    @State private var selectedColor: Color = .black
    @State private var strokeWidth: CGFloat = 3.0
    
    let colors: [Color] = [.black, .blue, .red]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ZStack {
                    Color.gray.opacity(0.1)
                        .ignoresSafeArea()
                    
                    CanvasViewRepresentable(
                        canvasView: $canvasView,
                        color: $selectedColor,
                        width: $strokeWidth
                    )
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 5)
                    .padding()
                }
                
                // Controls
                VStack(spacing: 20) {
                    // Color Picker
                    HStack(spacing: 20) {
                        ForEach(colors, id: \.self) { color in
                            Button {
                                selectedColor = color
                            } label: {
                                Circle()
                                    .fill(color)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.white)
                                            .opacity(selectedColor == color ? 1 : 0)
                                    )
                                    .shadow(radius: 2)
                            }
                        }
                    }
                    
                    // Thickness Slider
                    HStack {
                        Image(systemName: "scribble")
                            .font(.system(size: 12))
                        
                        Slider(value: $strokeWidth, in: 1...10)
                            .tint(selectedColor)
                        
                        Image(systemName: "scribble")
                            .font(.system(size: 24))
                    }
                    .padding(.horizontal, 32)
                }
                .padding(.bottom)
                
                Text("Sign above")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom)
            }
            .navigationTitle("Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveSignature()
                    }
                }
                
                ToolbarItem(placement: .bottomBar) {
                    Button("Clear") {
                        canvasView.drawing = PKDrawing()
                    }
                }
            }
        }
    }
    
    func saveSignature() {
        let drawing = canvasView.drawing
        let bounds = drawing.bounds
        
        if bounds.width > 0 && bounds.height > 0 {
            // Add some padding to the image
            let image = drawing.image(from: bounds, scale: UIScreen.main.scale)
            onSave(image)
            dismiss()
        } else {
            // Empty drawing
            dismiss()
        }
    }
}

struct CanvasViewRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var color: Color
    @Binding var width: CGFloat
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        updateTool(for: canvasView)
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        updateTool(for: uiView)
    }
    
    private func updateTool(for canvasView: PKCanvasView) {
        canvasView.tool = PKInkingTool(.pen, color: UIColor(color), width: width)
    }
}
