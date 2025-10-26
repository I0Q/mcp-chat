//
//  ContentView.swift
//  HelloWorld
//
//  Created by Acacio Santana on 10/26/25.
//

import SwiftUI

struct ContentView: View {
var body: some View {
     
        TabView {
            NavigationStack {
                ChatView()
            }
            .tabItem {
                Label("Chat", systemImage: "message.fill")
            }
            
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
    }

}
    
#Preview {
    ContentView()
}
