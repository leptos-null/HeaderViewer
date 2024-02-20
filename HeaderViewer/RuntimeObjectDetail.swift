//
//  RuntimeObjectDetail.swift
//  HeaderViewer
//
//  Created by Leptos on 2/18/24.
//

import SwiftUI
import ClassDump

struct RuntimeObjectDetail: View {
    let type: RuntimeObjectType
    
    private var semanticString: CDSemanticString {
        switch type {
        case .class(let named):
            CDClassModel(with: NSClassFromString(named))
                .semanticLines(withComments: false, synthesizeStrip: true)
        case .protocol(let named):
            CDProtocolModel(with: NSProtocolFromString(named))
                .semanticLines(withComments: false, synthesizeStrip: true)
        }
    }
    
    var body: some View {
        SemanticStringView(semanticString)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(type.name)
    }
}
