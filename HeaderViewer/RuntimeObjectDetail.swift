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
        GeometryReader { geomProxy in
            ScrollView([.horizontal, .vertical]) {
                SemanticStringView(semanticString: semanticString)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.leading)
                    .scenePadding()
                    .frame(
                        minWidth: geomProxy.size.width, maxWidth: .infinity,
                        minHeight: geomProxy.size.height, maxHeight: .infinity,
                        alignment: .topLeading
                    )
            }
            .animation(.snappy, value: geomProxy.size)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(type.name)
        
    }
}

private struct SemanticStringView: View {
    let semanticString: CDSemanticString
    
    var body: Text {
        var ret = Text(verbatim: "")
        semanticString.enumerateTypes { str, type in
            switch type {
            case .standard:
                ret = ret + Text(verbatim: str)
            case .comment:
                ret = ret + Text(verbatim: str)
                    .foregroundColor(.gray)
            case .keyword:
                ret = ret + Text(verbatim: str)
                    .foregroundColor(.pink)
            case .variable:
                ret = ret + Text(verbatim: str)
            case .recordName:
                ret = ret + Text(verbatim: str)
                    .foregroundColor(.cyan)
            case .class:
                ret = ret + Text(verbatim: str)
                    .foregroundColor(.orange)
            case .protocol:
                ret = ret + Text(verbatim: str)
                    .foregroundColor(.teal)
            case .numeric:
                ret = ret + Text(verbatim: str)
                    .foregroundColor(.purple)
            default:
                ret = ret + Text(verbatim: str)
            }
        }
        return ret
            .font(.body.monospaced())
    }
}
