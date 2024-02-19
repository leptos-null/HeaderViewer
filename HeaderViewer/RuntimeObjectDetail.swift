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
        SemanticStringView(semanticString: semanticString)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(type.name)
    }
}

private struct SemanticStringView {
    let semanticString: CDSemanticString
}

#if false
#elseif canImport(UIKit)
extension SemanticStringView: UIViewRepresentable {
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.linkTextAttributes = [
            .foregroundColor: UIColor.systemTeal
        ] // TODO: text view inside of scroll view
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        let preferredFont = UIFont.preferredFont(forTextStyle: .body, compatibleWith: textView.traitCollection)
        
        var baseAttributes = AttributeContainer()
        baseAttributes.foregroundColor = UIColor.label
        baseAttributes.font = UIFont.monospacedSystemFont(ofSize: preferredFont.pointSize, weight: .regular)
        textView.attributedText = NSAttributedString(semanticString.attributedString(baseAttributes: baseAttributes))
    }
}

private extension CDSemanticString { // UIKit attributes
    func attributedString(baseAttributes: AttributeContainer) -> AttributedString {
        var ret = AttributedString()
        enumerateTypes { str, type in
            // struct, so this is copied each time
            var attributeContainer = baseAttributes
            switch type {
            case .standard:
                break
            case .comment:
                attributeContainer.foregroundColor = UIColor.systemGray
            case .keyword:
                attributeContainer.foregroundColor = UIColor.systemPink
            case .variable:
                break
            case .recordName:
                attributeContainer.foregroundColor = UIColor.systemCyan
            case .class:
                attributeContainer.foregroundColor = UIColor.systemTeal
                // TODO: link handling
            case .protocol:
                attributeContainer.foregroundColor = UIColor.systemTeal
                // TODO: link handling
            case .numeric:
                attributeContainer.foregroundColor = UIColor.systemPurple
            default:
                break
            }
            ret.append(AttributedString(str, attributes: attributeContainer))
        }
        return ret
    }
}

//#elseif canImport(AppKit)
#else

extension SemanticStringView: View {
    private var textView: Text {
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
    
    var body: some View {
        GeometryReader { geomProxy in
            ScrollView([.horizontal, .vertical]) {
                textView
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
    }
}

#endif
