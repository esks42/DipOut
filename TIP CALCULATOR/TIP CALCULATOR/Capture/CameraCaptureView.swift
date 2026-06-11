//
//  CameraCaptureView.swift
//  TIP CALCULATOR
//
//  Single-shot receipt camera + a branded "use it or retake" review. Captures one photo, flattens
//  it (perspective-correct + crop) like a document scanner, lets the user keep or retake, and can
//  save a copy to Photos. Replaces VisionKit's multi-page "Ready for next scan" flow.
//

import SwiftUI
import AVFoundation
import Photos
import Vision

// MARK: - Flow

/// Camera → captured-photo review. Calls `onUse` with the chosen image or `onCancel` to back out.
struct ScannerFlowView: View {
    var onUse: (UIImage) -> Void
    var onCancel: () -> Void

    @State private var camera = CameraModel()
    @State private var captured: UIImage?
    @State private var processing = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = captured {
                CapturedReviewView(image: image,
                                   onUse: { onUse(image) },
                                   onRetake: { captured = nil; camera.resumeDetection() })
            } else {
                cameraLayer
            }

            if processing {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    ProgressView().controlSize(.large).tint(.white)
                }
            }
        }
        .onAppear {
            camera.onCapture = { raw in
                processing = true
                // VNDetectDocumentSegmentationRequest is prone to cutting off the bottom of long receipts
                // (mistaking separator dashed lines for document boundaries). We use the raw photo to
                // guarantee no text is lost.
                Task.detached(priority: .userInitiated) {
                    let image = raw
                    await MainActor.run { captured = image; processing = false }
                }
            }
            camera.start()
        }
        .onDisappear { camera.stop() }
    }

    private var cameraLayer: some View {
        ZStack {
            CameraPreview(session: camera.session).ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.35), in: Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer()

                Text(camera.holdSteady ? "Hold steady…" : "Fit the whole receipt in the frame")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(.black.opacity(0.35), in: Capsule())
                    .padding(.bottom, 24)
                    .animation(.easeInOut(duration: 0.2), value: camera.holdSteady)

                ShutterButton(locking: camera.holdSteady) { camera.capture() }
                    .padding(.bottom, 36)
            }

            if camera.permissionDenied { permissionDeniedView }
        }
    }

    private var permissionDeniedView: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "camera.fill").font(.system(size: 44)).foregroundStyle(Theme.inkSecondary)
                Text("Camera unavailable")
                    .font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.ink)
                Text("Turn on camera access in Settings, or pick a receipt from your photos instead.")
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 40)
                CardButton(title: "Close", systemImage: "xmark", background: Theme.surface,
                           foreground: Theme.ink, action: onCancel)
                    .padding(.horizontal, 40).padding(.top, 8)
            }
        }
    }
}

/// Classic shutter: white ring with an on-brand yellow core. The ring turns green and pulses while
/// a steady receipt is locked for auto-capture.
private struct ShutterButton: View {
    var locking: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().strokeBorder(locking ? Theme.positive : .white, lineWidth: 5)
                    .frame(width: 78, height: 78)
                    .scaleEffect(locking ? 1.12 : 1)
                Circle().fill(Theme.yellow).frame(width: 62, height: 62)
            }
            .animation(.easeInOut(duration: 0.25), value: locking)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Take photo")
    }
}

// MARK: - Review

/// Shows the captured receipt with themed keep/retake actions and an optional Photos save.
struct CapturedReviewView: View {
    let image: UIImage
    var onUse: () -> Void
    var onRetake: () -> Void

    @AppStorage("saveScansToPhotos") private var saveToPhotos = true

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Use this scan?")
                    .font(.system(size: 24, weight: .black)).foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(uiImage: image)
                    .resizable().scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                        .strokeBorder(Theme.ink.opacity(0.08), lineWidth: 1))

                Spacer(minLength: 0)

                Toggle(isOn: $saveToPhotos) {
                    Label("Save a copy to Photos", systemImage: "square.and.arrow.down")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
                .tint(Theme.yellow)
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(Theme.surface.opacity(0.55), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                HStack(spacing: 12) {
                    pill("Retake", "arrow.counterclockwise", bg: Theme.surface, fg: Theme.ink, action: onRetake)
                    pill("Use Photo", "checkmark", bg: Theme.yellow, fg: .black) {
                        if saveToPhotos { PhotoSaver.save(image) }
                        onUse()
                    }
                }
            }
            .padding(20)
        }
    }

    private func pill(_ title: String, _ icon: String, bg: Color, fg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                Text(title).font(.system(size: 18, weight: .semibold))
            }
            .foregroundStyle(fg)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(bg, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Adds a scanned receipt to the user's photo library (add-only permission).
enum PhotoSaver {
    static func save(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
        }
    }
}

// MARK: - Camera

// Thread-safety is hand-managed: AV work runs on `queue`, UI state (`permissionDenied`, `onCapture`)
// is only touched on the main queue — so the @Sendable session/delegate closures are safe.
@Observable
nonisolated final class CameraModel: NSObject, AVCapturePhotoCaptureDelegate,
                                     AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    var permissionDenied = false
    /// A steady receipt is detected and we're about to auto-snap — surfaced as a "hold steady" cue.
    var holdSteady = false
    @ObservationIgnored var onCapture: ((UIImage) -> Void)?

    @ObservationIgnored private let output = AVCapturePhotoOutput()
    @ObservationIgnored private let videoOutput = AVCaptureVideoDataOutput()
    @ObservationIgnored private let queue = DispatchQueue(label: "camera.session")
    @ObservationIgnored private let videoQueue = DispatchQueue(label: "camera.video")
    @ObservationIgnored private var device: AVCaptureDevice?

    // Auto-capture state — only touched on `videoQueue`.
    @ObservationIgnored private var analysisPaused = false
    @ObservationIgnored private var lastAnalysis = Date.distantPast
    @ObservationIgnored private var lastRect: CGRect?
    @ObservationIgnored private var steadyCount = 0

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted { self.configure() }
                else { DispatchQueue.main.async { self.permissionDenied = true } }
            }
        default: permissionDenied = true
        }
    }

    func stop() { queue.async { if self.session.isRunning { self.session.stopRunning() } } }

    /// Re-arm auto-capture after the user retakes.
    func resumeDetection() {
        videoQueue.async { self.analysisPaused = false; self.steadyCount = 0; self.lastRect = nil }
        DispatchQueue.main.async { self.holdSteady = false }
    }

    func capture() {
        videoQueue.async { self.analysisPaused = true }   // stop auto-detecting once we're shooting
        queue.async {
            guard let device = self.device else { return }
            if (try? device.lockForConfiguration()) != nil {
                let centre = CGPoint(x: 0.5, y: 0.5)
                if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = centre
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposurePointOfInterest = centre
                    device.exposureMode = .continuousAutoExposure
                }
                device.unlockForConfiguration()
            }
            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .quality
            settings.flashMode = .off                       // flash on paper causes glare
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }

    private func configure() {
        queue.async {
            if self.session.inputs.isEmpty {
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo

                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                      let input = try? AVCaptureDeviceInput(device: device),
                      self.session.canAddInput(input) else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async { self.permissionDenied = true }
                    return
                }
                self.session.addInput(input)
                self.device = device

                self.output.maxPhotoQualityPrioritization = .quality
                if self.session.canAddOutput(self.output) { self.session.addOutput(self.output) }

                // Live frames for auto-capture (detect a steady receipt rectangle).
                self.videoOutput.alwaysDiscardsLateVideoFrames = true
                self.videoOutput.setSampleBufferDelegate(self, queue: self.videoQueue)
                if self.session.canAddOutput(self.videoOutput) { self.session.addOutput(self.videoOutput) }

                self.session.commitConfiguration()
                self.prepareDevice(device)
            }
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    private func prepareDevice(_ device: AVCaptureDevice) {
        guard (try? device.lockForConfiguration()) != nil else { return }
        if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
        if device.isSmoothAutoFocusSupported { device.isSmoothAutoFocusEnabled = true }
        if device.isAutoFocusRangeRestrictionSupported { device.autoFocusRangeRestriction = .near }
        if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
        device.unlockForConfiguration()
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        let upright = image.normalizedUp()
        DispatchQueue.main.async { self.onCapture?(upright) }
    }

    // MARK: Auto-capture (live rectangle detection)

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        autoreleasepool {
            guard !analysisPaused else { return }
            let now = Date()
            guard now.timeIntervalSince(lastAnalysis) > 0.2 else { return }   // ~5 checks/sec
            lastAnalysis = now
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            let request = VNDetectRectanglesRequest()
            request.minimumSize = 0.25            // receipt must occupy a reasonable portion of the frame
            request.minimumAspectRatio = 0.1      // tall/narrow receipts
            request.maximumAspectRatio = 1.0
            request.minimumConfidence = 0.6
            request.quadratureTolerance = 25      // tolerate some angle
            request.maximumObservations = 1
            try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([request])

            guard let rect = request.results?.first, rect.confidence >= 0.6 else {
                steadyCount = 0; lastRect = nil
                setHoldSteady(false)
                return
            }

            if let last = lastRect, Self.isClose(last, rect.boundingBox) { steadyCount += 1 }
            else { steadyCount = 0 }
            lastRect = rect.boundingBox
            setHoldSteady(steadyCount >= 1)

            if steadyCount >= 4 {                 // steady for ~0.8s → snap
                analysisPaused = true
                setHoldSteady(false)
                capture()
            }
        }
    }

    /// Two normalized rects represent the "same" receipt held roughly still.
    private static func isClose(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.midX - b.midX) < 0.06 && abs(a.midY - b.midY) < 0.06
            && abs(a.width - b.width) < 0.08 && abs(a.height - b.height) < 0.08
    }

    private func setHoldSteady(_ value: Bool) {
        DispatchQueue.main.async { if self.holdSteady != value { self.holdSteady = value } }
    }
}

/// Live camera preview backed by an AVCaptureVideoPreviewLayer.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

private extension UIImage {
    /// Redraws into an upright (.up orientation) image so downstream pixel work isn't sideways.
    nonisolated func normalizedUp() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = self.scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
