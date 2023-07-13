//
//  TypingPallApp.swift
//  TypingPall
//
//  Created by Mieraidihaimu Mieraisan on 12/07/2023.
//

import SwiftUI

@main
struct TypingPallApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
                TypingScreenView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
