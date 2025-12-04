import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        // Feedback View or action
                        ContentUnavailableView("Coming Soon", systemImage: "envelope")
                    } label: {
                        Label("Give Feedback", systemImage: "bubble.left.and.bubble.right")
                    }
                } header: {
                    Text("Support")
                }
                
                Section {
                    NavigationLink {
                        // Privacy Policy View
                        ScrollView {
                            Text("Privacy Policy Placeholder")
                                .padding()
                        }
                        .navigationTitle("Privacy Policy")
                    } label: {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    
                    NavigationLink {
                        // Terms of Use View
                        ScrollView {
                            Text("Terms of Use Placeholder")
                                .padding()
                        }
                        .navigationTitle("Terms of Use")
                    } label: {
                        Label("Terms of Use", systemImage: "doc.text")
                    }
                } header: {
                    Text("About")
                }
                
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Mine")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    SettingsView()
}
