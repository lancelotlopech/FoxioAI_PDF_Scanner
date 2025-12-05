import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var store: FoxDocumentStore
    @State private var selectedTab = 0
    
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.5)
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
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
