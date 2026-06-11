//
//  TIP_CALCULATORApp.swift
//  TIP CALCULATOR
//
//  Created by Ethan S.K. Song on 6/7/26.
//

import SwiftUI

@main
struct TIP_CALCULATORApp: App {
    @State private var history = HistoryStore()
    @State private var storeManager = StoreManager()
    @State private var limitTracker = ScanLimitTracker()

    @State private var isShowingSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isShowingSplash {
                    SplashView()
                        .transition(.opacity)
                } else {
                    ContentView()
                        .environment(history)
                        .environment(storeManager)
                        .environment(limitTracker)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        isShowingSplash = false
                    }
                }
            }
        }
    }
}
