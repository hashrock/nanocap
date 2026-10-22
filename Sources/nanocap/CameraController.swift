import AppKit
import AVFoundation
import CoreImage

final class CameraController: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published private(set) var devices: [AVCaptureDevice] = []
    @Published private(set) var currentDeviceID: String?
    @Published private(set) var authorization = AVCaptureDevice.authorizationStatus(for: .video)
    @Published private(set) var videoSize = CGSize(width: 16, height: 9)
    @Published private(set) var detectedQuad: Quad?
    @Published private(set) var statusMessage = ""
    @Published private(set) var lastSavedURL: URL?
    @Published private(set) var lastThumbnail: NSImage?
    @Published private(set) var isFlashing = false

    @Published var trimMode: TrimMode {
        didSet {
            UserDefaults.standard.set(trimMode.rawValue, forKey: DefaultsKey.trimMode)
            lock.withLock { detectionEnabled = trimMode == .auto }
            if trimMode != .auto { detectedQuad = nil }
        }
    }

    @Published var manualQuad: Quad {
        didSet { UserDefaults.standard.set(manualQuad.encoded, forKey: DefaultsKey.manualQuad) }
    }

    /// プレビューに出す枠
    var displayQuad: Quad? {
        switch trimMode {
        case .auto: detectedQuad
        case .manual: manualQuad
        case .none: nil
        }
    }

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "nanocap.session")
    private let videoQueue = DispatchQueue(label: "nanocap.video")
    private let processingQueue = DispatchQueue(label: "nanocap.processing")

    // videoQueue と main から触るものは lock で守る
    private let lock = NSLock()
    private var latestBuffer: CVPixelBuffer?
    private var detectionEnabled = true
    private var frameSink: ((CVPixelBuffer) -> Void)?

    private var lastDetectionTime = Date.distantPast // videoQueue 専用
    private var lastSeenQuadTime = Date.distantPast // main 専用

    override init() {
        let defaults = UserDefaults.standard
        trimMode = TrimMode(rawValue: defaults.string(forKey: DefaultsKey.trimMode) ?? "") ?? .auto
        manualQuad = defaults.string(forKey: DefaultsKey.manualQuad).flatMap(Quad.init(encoded:)) ?? .defaultManual
        super.init()
        detectionEnabled = trimMode == .auto
    }

    func setFrameSink(_ sink: @escaping (CVPixelBuffer) -> Void) {
        lock.withLock { frameSink = sink }
    }

    // MARK: - セッション

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorization = .authorized
            refreshDevices()
            let saved = UserDefaults.standard.string(forKey: DefaultsKey.cameraID)
            let device = devices.first { $0.uniqueID == saved } ?? AVCaptureDevice.default(for: .video) ?? devices.first
            if let device { selectDevice(device.uniqueID) }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { _ in
                DispatchQueue.main.async { self.start() }
            }
        default:
            authorization = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }

    func refreshDevices() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera, .deskViewCamera],
            mediaType: .video,
            position: .unspecified
        )
        devices = discovery.devices
    }

    func selectDevice(_ id: String) {
        guard let device = devices.first(where: { $0.uniqueID == id }) else { return }
        currentDeviceID = id
        UserDefaults.standard.set(id, forKey: DefaultsKey.cameraID)
        detectedQuad = nil

        sessionQueue.async { [self] in
            session.beginConfiguration()
            session.inputs.forEach { session.removeInput($0) }
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) { session.addInput(input) }
            } catch {
                session.commitConfiguration()
                DispatchQueue.main.async { self.statusMessage = "カメラを開けません: \(error.localizedDescription)" }
                return
            }
            if session.outputs.isEmpty {
                output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                output.alwaysDiscardsLateVideoFrames = true
                output.setSampleBufferDelegate(self, queue: videoQueue)
                if session.canAddOutput(output) { session.addOutput(output) }
            }
            useHighestResolution(device)
            session.commitConfiguration()
            if !session.isRunning { session.startRunning() }
        }
    }

    /// ノートの文字を読めるよう、最大解像度のフォーマットを選ぶ
    private func useHighestResolution(_ device: AVCaptureDevice) {
        let candidates = device.formats.filter { format in
            format.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= 10 }
        }
        let best = candidates.max { a, b in
            let da = CMVideoFormatDescriptionGetDimensions(a.formatDescription)
            let db = CMVideoFormatDescriptionGetDimensions(b.formatDescription)
            return Int(da.width) * Int(da.height) < Int(db.width) * Int(db.height)
        }
        guard let best, (try? device.lockForConfiguration()) != nil else { return }
        device.activeFormat = best
        device.unlockForConfiguration()
    }

    // MARK: - フレーム

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let (sink, detect) = lock.withLock { () -> (((CVPixelBuffer) -> Void)?, Bool) in
            latestBuffer = pixelBuffer
            return (frameSink, detectionEnabled)
        }
        sink?(pixelBuffer)

        let size = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        if size != videoSize {
            DispatchQueue.main.async { self.videoSize = size }
        }

        // 検出は 10fps 程度に間引く
        let now = Date()
        guard detect, now.timeIntervalSince(lastDetectionTime) >= 0.1 else { return }
        lastDetectionTime = now
        let quad = DocumentDetector.detect(in: pixelBuffer)
        DispatchQueue.main.async { self.updateDetectedQuad(quad) }
    }

    private func updateDetectedQuad(_ quad: Quad?) {
        guard trimMode == .auto else { return }
        // 一瞬見失っただけで枠が消えてちらつかないようにする
        if let quad {
            detectedQuad = quad
            lastSeenQuadTime = Date()
        } else if Date().timeIntervalSince(lastSeenQuadTime) > 0.5 {
            detectedQuad = nil
        }
    }

    // MARK: - 撮影

    func capture() {
        guard let buffer = lock.withLock({ latestBuffer }) else {
            statusMessage = "カメラの映像がありません"
            return
        }
        let image = CIImage(cvPixelBuffer: buffer)
        let defaults = UserDefaults.standard
        let mode = trimMode
        let fallbackQuad = detectedQuad
        let manual = manualQuad
        let rotation = defaults.integer(forKey: DefaultsKey.rotation)
        let forceA6 = defaults.bool(forKey: DefaultsKey.forceA6)
        let quality = defaults.double(forKey: DefaultsKey.jpegQuality)
        isFlashing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { self.isFlashing = false }

        // 連番の採番が競合しないよう直列キューで処理する
        processingQueue.async { [self] in
            var note = ""
            let quad: Quad?
            switch mode {
            case .auto:
                // 撮影フレームで検出し直し、だめならプレビュー中の検出結果を使う
                quad = DocumentDetector.detect(in: image) ?? fallbackQuad
                if quad == nil { note = "（ノートを検出できなかったため全体を保存）" }
            case .manual:
                quad = manual
            case .none:
                quad = nil
            }
            let options = ProcessOptions(quad: quad, rotation: rotation, forceA6: forceA6, jpegQuality: quality)
            guard let data = ImageProcessor.jpeg(from: image, options: options) else {
                DispatchQueue.main.async { self.statusMessage = "画像の変換に失敗しました" }
                return
            }
            do {
                let url = try Storage.save(data)
                let thumbnail = NSImage(data: data)
                DispatchQueue.main.async {
                    self.lastSavedURL = url
                    self.lastThumbnail = thumbnail
                    self.statusMessage = "保存: \(url.lastPathComponent)\(note)"
                }
            } catch {
                DispatchQueue.main.async { self.statusMessage = "保存に失敗: \(error.localizedDescription)" }
            }
        }
    }
}
