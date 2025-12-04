import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var store: FoxDocumentStore
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            FilesView()
                .tabItem {
                    Label("My Files", systemImage: "folder.fill")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Label("Mine", systemImage: "person.fill")
                }
                .tag(2)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(FoxDocumentStore())
}
