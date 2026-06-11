//
//  ScanLimitTracker.swift
//  TIP CALCULATOR
//
//  Lifetime free-scan trial. The first `freeScanAllowance` scans are free; after that the
//  paywall is shown. A lifetime counter (not a daily reset) is the conversion mechanism —
//  a once-a-month user still gets months of runway, while an engaged user hits the wall.
//

import Foundation

@Observable
final class ScanLimitTracker {
    /// Scans granted before the paywall. Tuned here, not scattered through the UI.
    let freeScanAllowance = 5

    private let defaults: UserDefaults
    private let key = "freeScansUsed"

    /// Stored (not computed) so `@Observable` tracks it and the count can drive the UI;
    /// `didSet` mirrors it to `UserDefaults` for persistence across launches.
    private(set) var scansUsed: Int {
        didSet { defaults.set(scansUsed, forKey: key) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.scansUsed = defaults.integer(forKey: key)
    }

    var remainingFreeScans: Int { max(0, freeScanAllowance - scansUsed) }

    var hasFreeScans: Bool { scansUsed < freeScanAllowance }

    func recordScan() { scansUsed += 1 }
}
