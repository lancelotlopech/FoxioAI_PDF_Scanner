from reportlab.lib.pagesizes import LETTER
from reportlab.pdfgen import canvas
from reportlab.lib.units import inch
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.enums import TA_LEFT

def create_privacy_policy():
    doc = SimpleDocTemplate("PrivacyPolicy.pdf", pagesize=LETTER,
                            rightMargin=72, leftMargin=72,
                            topMargin=72, bottomMargin=18)
    Story = []
    styles = getSampleStyleSheet()
    
    # Custom Styles
    title_style = styles["Heading1"]
    title_style.alignment = TA_LEFT
    
    heading_style = styles["Heading2"]
    heading_style.spaceBefore = 12
    heading_style.spaceAfter = 6
    
    normal_style = styles["Normal"]
    normal_style.spaceBefore = 6
    normal_style.spaceAfter = 6
    
    # Content
    content = [
        ("FoxioAI PDF – Privacy Policy", title_style),
        ("Last Updated: December 12, 2025", normal_style),
        ("Developer: Xuanzhong Chen (developer@moonspace.work)", normal_style),
        
        ("1. Introduction", heading_style),
        ("""This Privacy Policy explains how FoxioAI PDF (the "App") collects, uses, and protects your information. The App is designed to minimize data usage, and all PDF processing is currently done locally on your device. Any future server-side processing or advertising services will be disclosed in this policy and require your consent when applicable.""", normal_style),
        
        ("2. Information We Collect", heading_style),
        ("The App does not actively collect personally identifiable information. We only collect the necessary data in the following cases:", normal_style),
        ("2.1 Error Logs (Non-Personal Information)", styles["Heading3"]),
        ("""In the event of errors or crashes, the App may collect anonymous log data:<br/>
- Device model<br/>
- OS version<br/>
- App version<br/>
- Usage time and error information<br/>
No personally identifiable data is collected. This data is used to improve stability and resolve issues.""", normal_style),
        
        ("3. Permission Usage (Corresponding to Info.plist)", heading_style),
        ("3.1 Camera Permission", styles["Heading3"]),
        ("""Purpose: To take photos for scanning documents, images, or text to generate PDFs.<br/>
Explanation: All image processing is done locally on your device. We do not upload, store, or share your image content. Camera access is granted only with your permission.""", normal_style),
        
        ("3.2 Photo Library Permission (Read and Write)", styles["Heading3"]),
        ("""Purpose: To import files or images from the photo library for PDF generation. To save the generated PDF or images to the photo library.<br/>
Explanation: We do not scan, upload, or analyze any other images in your photo library. We only access the files or content you explicitly select to import or save. All processing is done locally and will not be sent to our servers.""", normal_style),
        
        ("3.3 Advertising and Tracking Permission (App Tracking Transparency / IDFA)", styles["Heading3"]),
        ("We use the App Tracking Transparency (ATT) framework to request your permission to collect the Identifier for Advertisers (IDFA).", normal_style),
        ("Purpose:", styles["Heading4"]),
        ("""- Analytics & Attribution: We use identifiers to understand how users interact with our App and to measure the effectiveness of our marketing campaigns (e.g., via Facebook).<br/>
- Personalized Experience: To provide a more relevant user experience.""", normal_style),
        ("Your Choice:", styles["Heading4"]),
        ("""- You can choose to "Allow" or "Ask App Not to Track" in the system popup.<br/>
- You can change this setting at any time in your device Settings > Privacy > Tracking.<br/>
- If you decline, the App will still function normally, but we will not be able to use your IDFA for these purposes.""", normal_style),
        
        ("4. Third-Party Services", heading_style),
        ("We engage third-party service providers to help us operate and improve the App. These services may collect information sent by your device, such as your IP address, device model, and usage data.", normal_style),
        ("4.1 Firebase (Google)", styles["Heading3"]),
        ("""- Service: Firebase Analytics, Crashlytics.<br/>
- Purpose: To analyze app usage, detect crashes, and improve stability.<br/>
- Privacy Policy: https://policies.google.com/privacy""", normal_style),
        ("4.2 Facebook (Meta)", styles["Heading3"]),
        ("""- Service: Facebook SDK.<br/>
- Purpose: For marketing attribution (to know if you installed the App via a Facebook ad) and usage analytics.<br/>
- Privacy Policy: https://www.facebook.com/privacy/policy""", normal_style),
        
        ("5. Subscriptions and Purchases", heading_style),
        ("In-app subscriptions and purchases are processed via Apple’s In-App Purchase system. We do not handle your payment information. Payment processing is managed solely by Apple.", normal_style),
        
        ("6. User Data Control", heading_style),
        ("""You have the following rights:<br/>
- To delete all local data generated within the app.<br/>
- To withdraw permissions (Camera, Photo Library, Tracking).<br/>
If server-side processing is added in the future, you will be able to request access to, deletion of, or export of your data. We do not create user accounts and do not collect additional information without your consent.""", normal_style),
        
        ("7. Children’s Privacy", heading_style),
        ("The App is not intended for use by children under the age of 16. We do not knowingly collect personal information from children. If we become aware of such data collection, we will delete it immediately.", normal_style),
        
        ("8. Data Security", heading_style),
        ("""We use industry-standard measures to protect your data, such as:<br/>
- iOS sandboxing<br/>
- Local processing, minimizing network transmission risks<br/>
However, no system can guarantee 100% security.""", normal_style),
        
        ("9. Legal Compliance", heading_style),
        ("""We comply with the following regulations:<br/>
- GDPR (Europe)<br/>
- CCPA (California)<br/>
- COPPA (Children’s Privacy)<br/>
If we introduce server-side processing or advertising in the future, we will update this policy to ensure compliance with these regulations.""", normal_style),
        
        ("10. Changes to the Privacy Policy", heading_style),
        ("This policy may be updated periodically. If significant changes are made, we will notify you within the app. Continued use of the app constitutes acceptance of the updated terms.", normal_style),
        
        ("11. Contact Information", heading_style),
        ("""If you have any questions about this Privacy Policy, please contact us at:<br/>
developer@moonspace.work""", normal_style),
    ]
    
    for text, style in content:
        Story.append(Paragraph(text, style))
        Story.append(Spacer(1, 12))
        
    doc.build(Story)
    print("PrivacyPolicy.pdf generated successfully.")

if __name__ == "__main__":
    try:
        create_privacy_policy()
    except ImportError:
        print("Error: reportlab is not installed. Please install it using 'pip install reportlab'")
