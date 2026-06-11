//
//  SplashView.swift
//  TIP CALCULATOR
//
//  Premium animated splash screen for DipOut.
//

import SwiftUI

struct SplashView: View {
    @State private var billHeight: CGFloat = 0
    @State private var coinScale: CGFloat = 0.001 // Use 0.001 to avoid rendering glitches
    @State private var coinOffset: CGFloat = -50
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 20
    
    var body: some View {
        ZStack {
            // Background
            Theme.bg.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 40) {
                // Animated Logo
                ZStack {
                    // The Bill (Black vertical rectangle)
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.ink)
                        .frame(width: 70, height: billHeight)
                        .offset(x: -20, y: (100 - billHeight) / 2) // Keep it anchored to the bottom as it grows
                    
                    // The Tip/Coin (Yellow circle)
                    Circle()
                        .fill(Theme.yellow)
                        .frame(width: 56, height: 56)
                        .scaleEffect(coinScale)
                        .offset(x: 25, y: coinOffset)
                        .shadow(color: Theme.yellow.opacity(0.4), radius: 15, x: 0, y: 8)
                }
                .frame(height: 100)
                
                // Typography
                VStack(spacing: 8) {
                    Text("DipOut")
                        .font(.system(size: 46, weight: .black, design: .rounded))
                        .foregroundColor(Theme.ink)
                        .tracking(-1) // Tighter tracking for a premium feel
                    
                    Text("Tip the service, not the tax.")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.inkSecondary)
                }
                .opacity(textOpacity)
                .offset(y: textOffset)
            }
        }
        .onAppear {
            // 1. Bill slides up smoothly
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0).delay(0.1)) {
                billHeight = 100
            }
            
            // 2. Coin drops down and bounces into place
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5, blendDuration: 0).delay(0.4)) {
                coinScale = 1.0
                coinOffset = 10 // Settles slightly offset from the center
            }
            
            // 3. Text smoothly fades and slides up
            withAnimation(.easeOut(duration: 0.7).delay(0.7)) {
                textOpacity = 1.0
                textOffset = 0
            }
        }
    }
}

#Preview {
    SplashView()
}
