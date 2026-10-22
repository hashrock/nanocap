import Foundation

/// 保存先フォルダに「日付_連番.jpg」で書き出す
enum Storage {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static var folder: URL {
        let path = UserDefaults.standard.string(forKey: DefaultsKey.saveFolder) ?? ""
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
    }

    static func save(_ data: Data, date: Date = Date()) throws -> URL {
        let folder = folder
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let prefix = dateFormatter.string(from: date) + "_"
        let existing = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        let maxSeq = existing
            .filter { $0.hasPrefix(prefix) && $0.lowercased().hasSuffix(".jpg") }
            .compactMap { Int($0.dropFirst(prefix.count).dropLast(4)) }
            .max() ?? 0
        let url = folder.appending(path: prefix + String(format: "%03d", maxSeq + 1) + ".jpg")
        try data.write(to: url, options: .withoutOverwriting)
        return url
    }
}
