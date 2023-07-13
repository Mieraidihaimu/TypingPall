//
//  InfoSectionView.swift
//  TypingPall
//
//  Created by Mieraidihaimu Mieraisan on 13/07/2023.
//

import SwiftUI

struct InfoSectionView: View {
    @Binding var isShowingPlaceholderText: Bool

    var body: some View {
        HStack {
            Text("Version 0.0.1")
        }
    }
}

struct InfoSectionView_Previews: PreviewProvider {
    static var previews: some View {
        InfoSectionView(isShowingPlaceholderText: .constant(false))
    }
}
