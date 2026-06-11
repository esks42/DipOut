//
//  ContentView.swift
//  TIP CALCULATOR
//
//  Root coordinator: owns the shared session + scan flow so a new scan can be started
//  from any tab (Calculate or Saved), then routes results into the Calculate stack.
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    @Environment(StoreManager.self) private var store
    @Environment(ScanLimitTracker.self) private var scanLimit

    @State private var session = ReceiptSession()
    @State private var selection = 0
    @State private var path: [Stage] = []
    @State private var showScanner = false
    @State private var showPaywall = false

    enum Stage: Hashable { case review, results }

    var body: some View {
        TabView(selection: $selection) {
            CalculatorFlow(session: session, path: $path,
                           onNewScan: startScan, onImage: handle, onPaywall: { showPaywall = true })
                .tabItem { Label("Calculate", systemImage: "doc.text.viewfinder") }
                .tag(0)

            HistoryView(onNewScan: startScan)
                .tabItem { Label("Saved", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(1)
        }
        .tint(Theme.ink)
        .fullScreenCover(isPresented: $showScanner) {
            // Backgrounds/preview fill the screen; controls stay in the safe area (clear of the island).
            ScannerFlowView(onUse: { image in showScanner = false; handle(image) },
                            onCancel: { showScanner = false })
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .overlay {
            if session.isProcessing {
                ScanningOverlayView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: session.isProcessing)
    }

    private var canScan: Bool { store.isPremium || scanLimit.hasFreeScans }

    /// Open the camera if a scan is available, otherwise present the paywall.
    private func startScan() {
        if canScan { showScanner = true } else { showPaywall = true }
    }

    /// Process a captured/picked receipt and route into the Calculate stack at Review.
    private func handle(_ image: UIImage) {
        Task {
            if !store.isPremium { scanLimit.recordScan() }
            await session.load(image: image)
            selection = 0
            path = [.review]
        }
    }
}

struct CalculatorFlow: View {
    let session: ReceiptSession
    @Binding var path: [ContentView.Stage]
    var onNewScan: () -> Void
    var onImage: (UIImage) -> Void
    var onPaywall: () -> Void

    var body: some View {
        NavigationStack(path: $path) {
            ScanView(session: session, onNewScan: onNewScan, onImage: onImage, onPaywall: onPaywall)
                .navigationDestination(for: ContentView.Stage.self) { stage in
                    switch stage {
                    case .review:  ReviewView(session: session) { path.append(.results) }
                    case .results: ResultsView(session: session) { path.removeAll() }
                    }
                }
        }
    }
}

struct ScanView: View {
    let session: ReceiptSession
    @Environment(StoreManager.self) private var store
    @Environment(ScanLimitTracker.self) private var scanLimit

    var onNewScan: () -> Void
    var onImage: (UIImage) -> Void
    var onPaywall: () -> Void

    @State private var photoItem: PhotosPickerItem?

    private var canScan: Bool { store.isPremium || scanLimit.hasFreeScans }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        ScreenTitle("DipOut")
                        NewScanButton(action: onNewScan)
                    }
                    .padding(.bottom, 4)

                    Button { onNewScan() } label: {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.viewfinder")
                                .font(.system(size: 66, weight: .regular))
                            Text("Scan a receipt")
                                .font(.system(size: 23, weight: .bold))
                            Text("Find out if the tip is charged on tax.")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.black.opacity(0.55))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 360)
                        .background(Theme.yellow, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    PhotosPicker(selection: $photoItem, matching: .images) {
                        HStack(spacing: 10) {
                            Image(systemName: "photo").font(.system(size: 20, weight: .semibold))
                            Text("Choose from Photos").font(.system(size: 19, weight: .semibold))
                        }
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                    }

                    if !store.isPremium {
                        Button { onPaywall() } label: {
                            Text(scanLimit.hasFreeScans
                                 ? "\(scanLimit.remainingFreeScans) free \(scanLimit.remainingFreeScans == 1 ? "scan" : "scans") left"
                                 : "Free scans used — unlock Pro")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.inkSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            guard canScan else { photoItem = nil; onPaywall(); return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    onImage(image)
                }
                photoItem = nil
            }
        }
    }
}

/// Top-right "take another shot" action; opens the camera directly.
struct NewScanButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "camera.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 48, height: 48)
                .background(Theme.yellow, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New scan")
    }
}

#Preview {
    ContentView()
        .environment(HistoryStore())
        .environment(StoreManager())
        .environment(ScanLimitTracker())
}
