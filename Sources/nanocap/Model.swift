import Foundation
import Vision

/// ノートの4隅。正規化座標 (0...1、原点は左下。Vision / Core Image と同じ向き)
struct Quad: Equatable {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint

    static let defaultManual = Quad(
        topLeft: CGPoint(x: 0.3, y: 0.9),
        topRight: CGPoint(x: 0.7, y: 0.9),
        bottomRight: CGPoint(x: 0.7, y: 0.1),
        bottomLeft: CGPoint(x: 0.3, y: 0.1)
    )

    init(topLeft: CGPoint, topRight: CGPoint, bottomRight: CGPoint, bottomLeft: CGPoint) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomRight = bottomRight
        self.bottomLeft = bottomLeft
    }

    init(_ observation: VNRectangleObservation) {
        self.init(
            topLeft: observation.topLeft,
            topRight: observation.topRight,
            bottomRight: observation.bottomRight,
            bottomLeft: observation.bottomLeft
        )
    }

    var points: [CGPoint] { [topLeft, topRight, bottomRight, bottomLeft] }

    subscript(index: Int) -> CGPoint {
        get { points[index] }
        set {
            switch index {
            case 0: topLeft = newValue
            case 1: topRight = newValue
            case 2: bottomRight = newValue
            default: bottomLeft = newValue
            }
        }
    }

    // UserDefaults 保存用 "x,y;x,y;x,y;x,y"
    var encoded: String {
        points.map { "\($0.x),\($0.y)" }.joined(separator: ";")
    }

    init?(encoded: String) {
        let pts = encoded.split(separator: ";").compactMap { pair -> CGPoint? in
            let v = pair.split(separator: ",").compactMap { Double($0) }
            return v.count == 2 ? CGPoint(x: v[0], y: v[1]) : nil
        }
        guard pts.count == 4 else { return nil }
        self.init(topLeft: pts[0], topRight: pts[1], bottomRight: pts[2], bottomLeft: pts[3])
    }
}

enum TrimMode: String, CaseIterable, Identifiable {
    case auto, manual, none

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: "自動検出"
        case .manual: "手動枠"
        case .none: "補正なし"
        }
    }
}

enum DefaultsKey {
    static let saveFolder = "saveFolder"
    static let jpegQuality = "jpegQuality"
    static let forceA6 = "forceA6"
    static let rotation = "rotation"
    static let trimMode = "trimMode"
    static let manualQuad = "manualQuad"
    static let cameraID = "cameraID"

    static func register() {
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
        UserDefaults.standard.register(defaults: [
            saveFolder: pictures.appending(path: "nanocap").path,
            jpegQuality: 0.9,
            forceA6: true,
            rotation: 0,
            trimMode: TrimMode.auto.rawValue,
        ])
    }
}
