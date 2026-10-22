import AppKit
import AVFoundation
import SwiftUI

/// カメラのフレームをそのまま表示する（ミラーリングしないので保存画像と同じ向きになる）
struct CameraPreview: NSViewRepresentable {
    let camera: CameraController

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        camera.setFrameSink { [weak view] buffer in view?.display(buffer) }
        return view
    }

    func updateNSView(_ nsView: PreviewView, context: Context) {}
}

final class PreviewView: NSView {
    private let contentLayer = CALayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layer = CALayer()
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        contentLayer.contentsGravity = .resizeAspect
        layer?.addSublayer(contentLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        contentLayer.frame = bounds
        CATransaction.commit()
    }

    func display(_ buffer: CVPixelBuffer) {
        guard let surface = CVPixelBufferGetIOSurface(buffer)?.takeUnretainedValue() else { return }
        DispatchQueue.main.async {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.contentLayer.contents = surface
            CATransaction.commit()
        }
    }
}

/// 検出枠・手動枠の表示と、手動枠のドラッグ編集
struct QuadOverlay: View {
    @ObservedObject var camera: CameraController

    var body: some View {
        GeometryReader { geo in
            let rect = AVMakeRect(aspectRatio: camera.videoSize, insideRect: CGRect(origin: .zero, size: geo.size))
            ZStack {
                if let quad = camera.displayQuad {
                    let points = quad.points.map { toView($0, in: rect) }
                    Path { path in
                        path.addLines(points)
                        path.closeSubpath()
                    }
                    .fill(Color.accentColor.opacity(0.15))
                    Path { path in
                        path.addLines(points)
                        path.closeSubpath()
                    }
                    .stroke(Color.accentColor, lineWidth: 2)
                }
                if camera.trimMode == .manual {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(Color.white)
                            .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
                            .frame(width: 16, height: 16)
                            .position(toView(camera.manualQuad[index], in: rect))
                            .gesture(
                                DragGesture(coordinateSpace: .named("overlay"))
                                    .onChanged { value in
                                        camera.manualQuad[index] = toNormalized(value.location, in: rect)
                                    }
                            )
                    }
                }
            }
            .coordinateSpace(name: "overlay")
        }
    }

    private func toView(_ p: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + p.x * rect.width, y: rect.minY + (1 - p.y) * rect.height)
    }

    private func toNormalized(_ p: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max((p.x - rect.minX) / rect.width, 0), 1),
            y: min(max(1 - (p.y - rect.minY) / rect.height, 0), 1)
        )
    }
}
