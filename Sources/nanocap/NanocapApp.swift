import SwiftUI

@main
struct NanocapApp: App {
    @StateObject private var camera: CameraController

    init() {
        DefaultsKey.register()
        _camera = StateObject(wrappedValue: CameraController())
    }

    var body: some Scene {
        Window("nanocap", id: "main") {
            ContentView(camera: camera)
                .frame(minWidth: 720, minHeight: 520)
        }
        .defaultSize(width: 1000, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("撮影") { camera.capture() }
                    .keyboardShortcut(.return, modifiers: .command)
                Button("保存フォルダを開く") {
                    NSWorkspace.shared.open(Storage.folder)
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
        }
    }
}
