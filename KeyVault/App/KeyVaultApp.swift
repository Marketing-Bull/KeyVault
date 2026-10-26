import SwiftUI
import SwiftData

@main
struct KeyVaultApp: App {
    @StateObject private var appState = AppState()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Entry.self,
            VaultSecureField.self,
            Agent.self,
            AgentGrant.self
        ])
        let store = VaultStore.prepare()
        do {
            return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: store.url)])
        } catch where store.copiedLegacyStore {
            // The copied legacy file wasn't a KeyVault store after all; drop the copy and start fresh.
            VaultStore.removeStore(at: store.url)
            do {
                return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: store.url)])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Entry") {
                    NotificationCenter.default.post(name: .newEntry, object: nil)
                }
                .keyboardShortcut("n")
            }
            CommandGroup(after: .appSettings) {
                Button("Lock Vault") {
                    appState.lock()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }
    }
}

/// Root view that switches between setup, unlock, and main content.
struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.isFirstLaunch {
                SetupView()
            } else if !appState.isUnlocked {
                UnlockView()
            } else {
                MainView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.isUnlocked)
        .animation(.easeInOut(duration: 0.3), value: appState.isFirstLaunch)
        .onReceive(appState.autoLock.$isLocked) { isLocked in
            if isLocked {
                appState.lock()
            }
        }
    }
}

extension Notification.Name {
    static let newEntry = Notification.Name("newEntry")
}
