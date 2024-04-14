//
//  RuntimeObjectDetail.swift
//  HeaderViewer
//
//  Created by Leptos on 2/18/24.
//

import SwiftUI
import ClassDump

struct RuntimeObjectDetail: View {
    // influenced by
    // https://developer.apple.com/design/human-interface-guidelines/typography
    private static var defaultFontSize: Int {
#if os(iOS) || os(visionOS)
        16
#elseif os(macOS)
        13
#else
#warning("Unknown platform")
        12
#endif
    }
    
    let type: RuntimeObjectType
    
    @State private var stripProtocolConformance: Bool = false
    @State private var stripOverrides: Bool = false
    @State private var stripDuplicates: Bool = true
    @State private var stripSynthesized: Bool = true
    @State private var addSymbolImageComments: Bool = false
    
    @AppStorage("code_font_size") private var fontSize: Int = Self.defaultFontSize
    
    private var generationOptions: CDGenerationOptions {
        let options: CDGenerationOptions = .init()
        options.stripProtocolConformance = stripProtocolConformance
        options.stripOverrides = stripOverrides
        options.stripDuplicates = stripDuplicates
        options.stripSynthesized = stripSynthesized
        options.stripCtorMethod = true
        options.stripDtorMethod = true
        options.addSymbolImageComments = addSymbolImageComments
        return options
    }
    
    var body: some View {
        Group {
            switch type {
            case .class(let name):
                if let cls = NSClassFromString(name) {
                    let semanticString: CDSemanticString = CDClassModel(with: cls)
                        .semanticLines(with: generationOptions)
                    SemanticStringView(semanticString, fontSize: CGFloat(fontSize))
                } else {
                    Text("No class named \(Text(name).font(.callout.monospaced())) found")
                        .scenePadding()
                }
            case .protocol(let name):
                if let prtcl = NSProtocolFromString(name) {
                    let semanticString: CDSemanticString = CDProtocolModel(with: prtcl)
                        .semanticLines(with: generationOptions)
                    SemanticStringView(semanticString, fontSize: CGFloat(fontSize))
                } else {
                    Text("No protocol named \(Text(name).font(.callout.monospaced())) found")
                        .scenePadding()
                }
            }
        }
        .navigationTitle(type.name)
        .toolbar {
            FontToolbarItem(fontSize: $fontSize)
            
            ToolbarItem {
                Menu {
                    Toggle("Strip protocol conformance", isOn: $stripProtocolConformance)
                    Toggle("Strip overrides", isOn: $stripOverrides)
                    Toggle("Strip duplicates", isOn: $stripDuplicates)
                    Toggle("Strip synthesized", isOn: $stripSynthesized)
                    Toggle("Add symbol comments", isOn: $addSymbolImageComments)
                } label: {
                    Label("Generation options", systemImage: "ellipsis.curlybraces")
                }
            }
        }
#if os(iOS) || os(watchOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
#if os(visionOS)
        .background(.ultraThickMaterial)
#endif
    }
}

private struct FontToolbarItem: ToolbarContent {
    @Binding var fontSize: Int
    
    private var sizeDescription: String {
        fontSize.formatted(.number)
    }
    
    private var smallerButton: some View {
        Button("Smaller", systemImage: "textformat.size.smaller") {
            guard fontSize > 4 else { return }
            fontSize -= 1
        }
    }
    
    private var largerButton: some View {
        Button("Larger", systemImage: "textformat.size.larger") {
            guard fontSize < 28 else { return }
            fontSize += 1
        }
    }
    
    private func sizeControlGroup(withDescription: Bool) -> some View {
        ControlGroup("Font Size", systemImage: "textformat.size") {
            smallerButton
            if withDescription {
                Text(sizeDescription)
            }
            largerButton
        }
    }
    
    var body: some ToolbarContent {
        ToolbarItem {
#if os(iOS) || os(visionOS)
            if #available(iOS 16.4, *) {
                Menu {
                    sizeControlGroup(withDescription: true)
                        .controlGroupStyle(.compactMenu)
                } label: {
                    Label("Font", systemImage: "textformat.size")
                }
                .menuActionDismissBehavior(.disabled)
            } else {
                Menu {
                    sizeControlGroup(withDescription: true)
                } label: {
                    Label("Font", systemImage: "textformat.size")
                }
            }
#else
            sizeControlGroup(withDescription: false)
                .controlGroupStyle(.navigation)
#endif
        }
    }
}
