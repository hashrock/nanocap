import AVFoundation
import SwiftUI

struct ContentView: View {
    @ObservedObject var camera: CameraController
    @AppStorage(DefaultsKey.rotation) private var rotation = 0
    @AppStorage(DefaultsKey.saveFolder) private var saveFolder = ""

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if camera.authorization == .authorized {
                    CameraPreview(camera: camera)
                    QuadOverlay(camera: camera)
                } else {
                    permissionView
                }
                Color.white.opacity(camera.isFlashing ? 0.6 : 0)
                    .animation(.easeOut(duration: 0.3), value: camera.isFlashing)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)

            Divider()
            controls
                .padding(10)
        }
        .onAppear { camera.start() }
    }

    private var permissionView: some View {
        VStack(spacing: 12) {
            Text("カメラへのアクセスが許可されていません")
                .foregroundStyle(.white)
            Button("システム設定を開く") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    Picker("カメラ", selection: Binding(
                        get: { camera.currentDeviceID ?? "" },
                        set: { camera.selectDevice($0) }
                    )) {
                        ForEach(camera.devices, id: \.uniqueID) { device in
                            Text(device.localizedName).tag(device.uniqueID)
                        }
                    }
                    .frame(maxWidth: 260)

                    Picker("トリム", selection: $camera.trimMode) {
                        ForEach(TrimMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 260)

                    if camera.trimMode == .manual {
                        Button("枠をリセット") { camera.manualQuad = .defaultManual }
                    }

                    Picker("回転", selection: $rotation) {
                        ForEach([0, 90, 180, 270], id: \.self) { Text("\($0)°").tag($0) }
                    }
                    .frame(width: 110)
                }
                HStack(spacing: 8) {
                    Button {
                        chooseFolder()
                    } label: {
                        Label(Storage.folder.path(percentEncoded: false), systemImage: "folder")
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                    .buttonStyle(.link)
                    .id(saveFolder)
                    Text(camera.statusMessage)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .font(.callout)
            }

            Spacer()

            if let thumbnail = camera.lastThumbnail {
                Button {
                    if let url = camera.lastSavedURL {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                } label: {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .help("Finder で表示")
            }

            Button {
                camera.capture()
            } label: {
                Label("撮影", systemImage: "camera.fill")
                    .frame(minWidth: 80)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.space, modifiers: [])
            .help("スペースキーで撮影")
        }
    }

    private func chooseFolder() {
        if let url = FolderPicker.choose() {
            saveFolder = url.path
        }
    }
}

enum FolderPicker {
    static func choose() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = Storage.folder
        panel.prompt = "選択"
        return panel.runModal() == .OK ? panel.url : nil
    }
}
