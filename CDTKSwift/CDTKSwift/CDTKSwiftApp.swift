import SwiftUI

@main
struct CDTKSwiftApp: App {
    @StateObject private var controller = DeviceController()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(controller)
                .preferredColorScheme(nil)
        }
    }
}
