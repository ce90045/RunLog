import SwiftUI

@main
struct RunLogApp: App {
    @StateObject private var workout = WorkoutManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workout)
        }
    }
}
