import SwiftUI

struct SettingsView: View {
    @AppStorage(DefaultsKey.saveFolder) private var saveFolder = ""
    @AppStorage(DefaultsKey.jpegQuality) private var jpegQuality = 0.9
    @AppStorage(DefaultsKey.forceA6) private var forceA6 = true

    var body: some View {
        Form {
            LabeledContent("保存先") {
                HStack {
                    Text(Storage.folder.path(percentEncoded: false))
                        .lineLimit(1)
                        .truncationMode(.head)
                        .id(saveFolder)
                    Button("変更…") {
                        if let url = FolderPicker.choose() { saveFolder = url.path }
                    }
                }
            }
            LabeledContent("JPEG 品質") {
                HStack {
                    Slider(value: $jpegQuality, in: 0.5...1.0, step: 0.05)
                    Text("\(Int(jpegQuality * 100))")
                        .monospacedDigit()
                        .frame(width: 32, alignment: .trailing)
                }
            }
            Toggle("トリム後に A6 の縦横比 (105:148) に揃える", isOn: $forceA6)
            Text("ファイル名は「日付_連番.jpg」（例: 2026-10-22_001.jpg）")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 480)
    }
}
