import PDFKit
import UIKit

/// 用于高亮显示可编辑文本块的注解（蓝色虚线框）
class BlockHighlightAnnotation: PDFAnnotation {
    
    override init(bounds: CGRect, forType type: PDFAnnotationSubtype, withProperties properties: [AnyHashable : Any]?) {
        super.init(bounds: bounds, forType: type, withProperties: properties)
        self.shouldPrint = false // 不需要打印出来
        self.shouldDisplay = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        guard let page = self.page else { return }
        
        UIGraphicsPushContext(context)
        context.saveGState()
        
        // 1. 坐标系转换：从 PDF 坐标系 (Bottom-Left) 翻转为 UIKit 绘制习惯 (Top-Left)
        context.translateBy(x: 0, y: bounds.origin.y + bounds.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        // 2. 绘制区域
        let drawingRect = CGRect(x: bounds.origin.x, y: 0, width: bounds.width, height: bounds.height)
        
        // 3. 绘制蓝色虚线框和半透明背景
        let path = UIBezierPath(rect: drawingRect)
        
        // 背景色
        UIColor.blue.withAlphaComponent(0.05).setFill()
        path.fill()
        
        // 边框
        UIColor.blue.withAlphaComponent(0.6).setStroke()
        path.lineWidth = 1.0
        let dashes: [CGFloat] = [4.0, 2.0]
        path.setLineDash(dashes, count: dashes.count, phase: 0.0)
        path.stroke()
        
        context.restoreGState()
        UIGraphicsPopContext()
    }
}

/// 用于“擦除”原始文本的注解（白色实心矩形）
class RedactionAnnotation: PDFAnnotation {
    
    override init(bounds: CGRect, forType type: PDFAnnotationSubtype, withProperties properties: [AnyHashable : Any]?) {
        super.init(bounds: bounds, forType: type, withProperties: properties)
        self.color = .white // 核心：白色背景覆盖
        self.shouldPrint = true
        self.shouldDisplay = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// 用于显示用户编辑后新文本的注解
class EditableTextAnnotation: PDFAnnotation {
    
    var text: String = ""
    var textFont: UIFont = UIFont.systemFont(ofSize: 12)
    var textColor: UIColor = .black
    
    init(bounds: CGRect, text: String, font: UIFont, textColor: UIColor) {
        super.init(bounds: bounds, forType: .widget, withProperties: nil)
        self.text = text
        self.textFont = font
        self.textColor = textColor
        self.shouldPrint = true
        self.shouldDisplay = true
        self.isReadOnly = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        guard let page = self.page else { return }
        
        UIGraphicsPushContext(context)
        context.saveGState()
        
        // 1. 坐标系转换
        context.translateBy(x: 0, y: bounds.origin.y + bounds.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        // 2. 绘制配置
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineBreakMode = .byWordWrapping
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: textFont,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
        
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        
        // 3. 绘制文本
        // 允许高度溢出，防止文字被截断
        let drawingRect = CGRect(x: bounds.origin.x, y: 0, width: bounds.width, height: 10000)
        attributedText.draw(in: drawingRect)
        
        context.restoreGState()
        UIGraphicsPopContext()
    }
}

/// 补丁属性模型，用于序列化存储
struct PatchAttributes: Codable {
    var text: String
    var fontSize: CGFloat
    var fontName: String
    var colorHex: String
    var lineSpacing: CGFloat
    var letterSpacing: CGFloat
    var isTransparent: Bool
}

/// 智能补丁注解：支持图片渲染和元数据存储
class PatchAnnotation: PDFAnnotation {
    
    var image: UIImage?
    var attributes: PatchAttributes?
    
    init(bounds: CGRect, image: UIImage, attributes: PatchAttributes) {
        self.image = image
        self.attributes = attributes
        super.init(bounds: bounds, forType: .stamp, withProperties: nil)
        
        // Store attributes in contents as JSON for persistence/restoration
        if let data = try? JSONEncoder().encode(attributes),
           let jsonString = String(data: data, encoding: .utf8) {
            self.contents = jsonString
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        guard let image = image, let cgImage = image.cgImage else { return }
        
        context.saveGState()
        
        // Draw the image (Patch)
        let rect = self.bounds
        let drawingBounds = CGRect(x: rect.origin.x, y: rect.origin.y, width: rect.width, height: rect.height)
        context.draw(cgImage, in: drawingBounds)
        
        // Draw selection border if selected (handled by PDFView usually, but we can enforce custom look)
        // Note: PDFView handles selection highlighting natively for annotations if we allow it.
        
        context.restoreGState()
    }
}
