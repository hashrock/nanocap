// アプリアイコンを描画して Resources/AppIcon.icns を作る
// 使い方: swift scripts/make_icon.swift
import AppKit

let canvas: CGFloat = 1024

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func drawIcon(_ ctx: CGContext) {
    // macOS のアイコングリッドに合わせ、824pt の角丸四角を中央に置く
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: color(0x000000, 0.35))
    ctx.addPath(bodyPath)
    ctx.setFillColor(color(0x1E2A44))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [color(0x3A5A8C), color(0x1B2540)] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    // 斜めから撮ったノート（台形）
    let tl = CGPoint(x: 352, y: 742), tr = CGPoint(x: 672, y: 742)
    let br = CGPoint(x: 720, y: 282), bl = CGPoint(x: 304, y: 282)
    let note = CGMutablePath()
    note.addLines(between: [tl, tr, br, bl])
    note.closeSubpath()

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: color(0x000000, 0.4))
    ctx.addPath(note)
    ctx.setFillColor(color(0xFAF7F0))
    ctx.fillPath()
    ctx.restoreGState()

    // 罫線
    ctx.saveGState()
    ctx.addPath(note)
    ctx.clip()
    ctx.setStrokeColor(color(0x9DB4D6))
    ctx.setLineWidth(7)
    ctx.setLineCap(.round)
    func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }
    for i in 1...6 {
        let t = CGFloat(i) / 7
        let left = lerp(tl, bl, t), right = lerp(tr, br, t)
        ctx.move(to: lerp(left, right, 0.12))
        ctx.addLine(to: lerp(left, right, 0.88))
    }
    ctx.strokePath()
    ctx.restoreGState()

    // 取り込み枠（補正後の長方形を示すコーナーマーク）
    let frame = CGRect(x: 262, y: 222, width: 500, height: 580)
    let arm: CGFloat = 110
    ctx.setStrokeColor(color(0xFFB627))
    ctx.setLineWidth(34)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    let corners: [(CGPoint, CGFloat, CGFloat)] = [
        (CGPoint(x: frame.minX, y: frame.maxY), 1, -1),
        (CGPoint(x: frame.maxX, y: frame.maxY), -1, -1),
        (CGPoint(x: frame.maxX, y: frame.minY), -1, 1),
        (CGPoint(x: frame.minX, y: frame.minY), 1, 1),
    ]
    for (p, dx, dy) in corners {
        ctx.move(to: CGPoint(x: p.x + dx * arm, y: p.y))
        ctx.addLine(to: p)
        ctx.addLine(to: CGPoint(x: p.x, y: p.y + dy * arm))
    }
    ctx.strokePath()
    ctx.restoreGState()
}

func png(size: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    ctx.scaleBy(x: CGFloat(size) / canvas, y: CGFloat(size) / canvas)
    drawIcon(ctx)
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appending(path: "AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try png(size: base).write(to: iconset.appending(path: "icon_\(base)x\(base).png"))
    try png(size: base * 2).write(to: iconset.appending(path: "icon_\(base)x\(base)@2x.png"))
}

let resources = root.appending(path: "Resources")
try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
try png(size: 1024).write(to: resources.appending(path: "AppIcon.png"))
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", resources.appending(path: "AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
print("Wrote Resources/AppIcon.icns")
