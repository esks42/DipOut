//
//  ScanningOverlayView.swift
//  TIP CALCULATOR
//
//  Premium animated loading overlay shown while processing a receipt.
//

import SwiftUI

struct ScanningOverlayView: View {
    @State private var scannerOffset: CGFloat = -25
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            // Full screen solid background exactly like SplashView
            Theme.bg.ignoresSafeArea()
            
            VStack(spacing: 40) {
                // The Animated Logo
                ZStack {
                    // The Bill (Black vertical rectangle)
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.ink)
                        .frame(width: 70, height: 100)
                        .offset(x: -20, y: 0)
                    
                    // The Coin acting as a scanner
                    Circle()
                        .fill(Theme.yellow)
                        .frame(width: 56, height: 56)
                        .offset(x: 25, y: scannerOffset)
                        .shadow(color: Theme.yellow.opacity(0.4), radius: 15, x: 0, y: 8)
                }
                .frame(height: 100)
                
                // Typography
                Text("Crunching the numbers...")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.ink)
                    .opacity(isPulsing ? 0.3 : 1.0)
            }
        }
        .onAppear {
            // Coin slides up and down smoothly along the bill
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                scannerOffset = 25
            }
            
            // Text pulses softly
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

#Preview {
    ScanningOverlayView()
}
