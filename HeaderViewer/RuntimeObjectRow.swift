//
//  RuntimeObjectRow.swift
//  HeaderViewer
//
//  Created by Leptos on 2/18/24.
//

import SwiftUI

struct RuntimeObjectRow: View {
    let type: RuntimeObjectType
    
    private var systemImageName: String {
        switch type {
        case .class: return "c.square.fill"
        case .protocol: return "p.square.fill"
        }
    }
    
    private var iconColor: Color {
        switch type {
        case .class: return .green
        case .protocol: return .pink
        }
    }
    
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: systemImageName)
                .foregroundColor(iconColor)
            Text(type.name)
            Spacer()
        }
        .accessibilityLabel(type.name)
    }
}
