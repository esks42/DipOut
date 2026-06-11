# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

"DipOut" — an iOS (SwiftUI) app that scans a restaurant receipt, detects whether a printed tip suggestion was computed on the **post-tax** total (i.e. you'd be tipping on the tax), recalculates a fair tip on the pre-tax subtotal, and splits the bill evenly. Targets iOS, uses Vision (OCR) and VisionKit (document camera). No third-party dependencies.

## Layout

The Xcode project is nested one level down: repo root holds `RECEIPTS SAMPLE/` (test images) and the `TIP CALCULATOR/` workspace folder, which contains `TIP CALCULATOR.xcodeproj` and the source target. Run all `xcodebuild` commands from `TIP CALCULATOR/`.

## Build / test commands

Run from `/Users/sk/CLAUDE/ESKS/TIP CALCULATOR/TIP CALCULATOR`. The scheme name and target name both contain a space, so quote them.

```bash
# Build
xcodebuild -scheme "TIP CALCULATOR" -destination 'platform=iOS Simulator,name=iPhone 17' build

# Run all unit tests
xcodebuild -scheme "TIP CALCULATOR" -destination 'platform=iOS Simulator,name=iPhone 17' test

# Run a single test class or method (swift-testing, via xctest naming)
xcodebuild -scheme "TIP CALCULATOR" -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:"TIP CALCULATORTests/ReceiptParserTests"
```

Tests use the **swift-testing** framework (`import Testing`, `@Test`, `#expect`), not XCTest.

## Architecture

The app is a three-screen flow coordinated by a single observable session, sitting on top of a pure, framework-free engine. The split between "pure logic" and "Apple frameworks" is deliberate and load-bearing for testability — keep it.

**Flow:** [ContentView.swift](TIP%20CALCULATOR/TIP%20CALCULATOR/ContentView.swift) drives a `NavigationStack`: `ScanView` → `ReviewView` → `ResultsView`. A single `ReceiptSession` instance is passed down and shared across all three screens.

**State:** [ReceiptSession.swift](TIP%20CALCULATOR/TIP%20CALCULATOR/ReceiptSession.swift) is the `@Observable` source of truth. It holds the parsed `ReceiptData` plus user inputs (`people`, `targetPercent`, `rounding`) and exposes derived values (`verdict`, `recalculatedTip`, `newTotal`, `split`) as computed properties that call straight into `TipCalculator`. `load(image:)` runs OCR → parse → seeds `targetPercent` from the detected suggestion.

**Pipeline (image → numbers → verdict):**
1. [OCR/OCRService.swift](TIP%20CALCULATOR/TIP%20CALCULATOR/OCR/OCRService.swift) — Vision text recognition, off the main thread, returns newline-joined text in reading order.
2. [Engine/ReceiptParser.swift](TIP%20CALCULATOR/TIP%20CALCULATOR/Engine/ReceiptParser.swift) — pure string→`ReceiptData`. Handles two Vision layouts: same-line `"SUBTOTAL 45.00"` and **two-column** (a block of labels then a block of values), the latter recovered via the arithmetic constraint `subtotal + tax = total`. Tip suggestions are scraped by regex (`18% ($5.13)` etc.).
3. [Engine/TipCalculator.swift](TIP%20CALCULATOR/TIP%20CALCULATOR/Engine/TipCalculator.swift) — the core logic. `detectBasis` compares a printed tip against `subtotal×p%` vs `(subtotal+tax)×p%` to classify it `preTax`/`postTax`/`unknown`; when no percent is printed it infers the rate against `commonRates` within tolerance. `overallBasis` picks the worst post-tax suggestion as the headline verdict. Recalculation **always** uses the pre-tax subtotal. `split` does integer-cent reconciliation so per-person shares sum exactly to the total.
4. [Engine/ReceiptModels.swift](TIP%20CALCULATOR/TIP%20CALCULATOR/Engine/ReceiptModels.swift) — pure data types (`ReceiptData`, `SuggestedTip`, `TipBasis`).

The `Engine/` and `OCR/` separation means the entire numeric pipeline (parser + calculator) has **no UIKit/Vision dependency** and is fully unit-tested in [TIP CALCULATORTests](TIP%20CALCULATOR/TIP%20CALCULATORTests/TIP_CALCULATORTests.swift). When changing parsing or tip-detection logic, add/adjust a `#expect` case there rather than testing through the UI.

**Capture & UI:** [Capture/DocumentScannerView.swift](TIP%20CALCULATOR/TIP%20CALCULATOR/Capture/DocumentScannerView.swift) is a `UIViewControllerRepresentable` over VisionKit's `VNDocumentCameraViewController`. Views live in `Views/`; [Views/Theme.swift](TIP%20CALCULATOR/TIP%20CALCULATOR/Views/Theme.swift) is the design system (warm-greige background, yellow accent, bold black numerals) and reusable components (`StatCard`, `CardButton`, `ScreenTitle`, `SectionHeader`).

## Conventions

- Tolerances live as named constants on `TipCalculator` (`amountTolerance`, `percentTolerance`, `commonRates`) — tune detection there, don't scatter magic numbers.
- Money is formatted via the free `money(_:)` helper in `ReceiptSession.swift`.
- Keep new numeric/parsing logic out of the SwiftUI layer so it stays testable; SwiftUI views should only read computed properties off `ReceiptSession`.
