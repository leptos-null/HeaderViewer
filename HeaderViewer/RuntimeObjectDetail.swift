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
    
    @State private var stripProtocolConformance: Bool = false
    @State private var stripOverrides: Bool = false
    @State private var stripDuplicates: Bool = true
    @State private var stripSynthesized: Bool = true
    @State private var addSymbolImageComments: Bool = false
    
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
                    SemanticStringView(semanticString)
                } else {
                    Text("No class named \(Text(name).font(.callout.monospaced())) found")
                        .scenePadding()
                }
            case .protocol(let name):
                if let prtcl = NSProtocolFromString(name) {
                    let semanticString: CDSemanticString = CDProtocolModel(with: prtcl)
                        .semanticLines(with: generationOptions)
                    SemanticStringView(semanticString)
                } else {
                    Text("No protocol named \(Text(name).font(.callout.monospaced())) found")
                        .scenePadding()
                }
            }
        }
        .navigationTitle(type.name)
        .toolbar {
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
