import SwiftUI
import MessageUI

struct FeedbackView: View {
    @Environment(\.dismiss) var dismiss
    @State private var feedbackText = ""
    @State private var email = ""
    @State private var isSending = false
    @State private var showMailView = false
    @State private var mailResult: Result<MFMailComposeResult, Error>? = nil
    @State private var showNoMailAlert = false
    
    private let developerEmail = "developer@moonspace.work"
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("We'd love to hear from you! Please let us know how we can improve the app.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .padding(.bottom, 8)
                    
                    TextField("Your Email (Optional)", text: $email)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    ZStack(alignment: .topLeading) {
                        if feedbackText.isEmpty {
                            Text("Type your feedback here...")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $feedbackText)
                            .frame(minHeight: 150)
                    }
                } header: {
                    Text("Feedback")
                }
                
                Section {
                    Button {
                        submitFeedback()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Send Feedback")
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                    .foregroundStyle(.white)
                    .listRowBackground(
                        feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
                        ? Color.gray 
                        : Color.blue
                    )
                    .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Give Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showMailView) {
                MailView(result: $mailResult,
                         recipients: [developerEmail],
                         subject: "PDFScanner Feedback",
                         messageBody: constructEmailBody())
            }
            .alert("No Email Account", isPresented: $showNoMailAlert) {
                Button("Copy Email Address") {
                    UIPasteboard.general.string = developerEmail
                }
                Button("OK", role: .cancel) { }
            } message: {
                Text("No email account is configured on this device. Please manually send your feedback to \(developerEmail).")
            }
        }
    }
    
    private func submitFeedback() {
        if MFMailComposeViewController.canSendMail() {
            showMailView = true
        } else {
            showNoMailAlert = true
        }
    }
    
    private func constructEmailBody() -> String {
        var body = feedbackText
        
        if !email.isEmpty {
            body += """


---
User Email: \(email)
"""
        }
        
        // Add device info for debugging
        let device = UIDevice.current
        body += """


---
Device: \(device.model)
System: \(device.systemName) \(device.systemVersion)
"""
        
        return body
    }
}

#Preview {
    FeedbackView()
}
