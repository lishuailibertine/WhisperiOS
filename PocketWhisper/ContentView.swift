//
//  ContentView.swift
//  PocketWhisper
//
//  Created by li shuai on 2025/12/17.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            ExtractionView()
                .tabItem {
                    Label("Extraction", systemImage: "waveform")
                }
            
            ModelsView()
                .tabItem {
                    Label("Models", systemImage: "arrow.down.circle")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView()
}
