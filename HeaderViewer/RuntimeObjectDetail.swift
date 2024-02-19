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
                let lines = semanticString.splitLines()
                // this is inefficient:
                // having to recalculate length on each call
                let longestLine = lines.max { lhs, rhs in
                    lhs.length < rhs.length
                }
                ZStack(alignment: .leading) {
                    // use the longest line to expand the view as much as needed
                    // without having to render all the lines
                    if let longestLine {
                        SemanticLineView(line: longestLine)
                            .opacity(0)
                    }
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(lines) { line in
                            SemanticLineView(line: line)
                        }
                    }
                }
                .font(.body.monospaced())
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

struct SemanticLine: Identifiable {
    let number: Int
    let content: [SemanticRun]
    
    var id: Int { number }
}

struct SemanticRun: Identifiable {
    // it is the caller's responsibility to set a unique id relative to the container
    let id: Int
    let string: String
    let type: CDSemanticType
}

extension SemanticLine { // TODO: remove - this is inefficient
    var length: Int {
        content.reduce(into: .zero) { partialResult, run in
            partialResult += run.string.count
        }
    }
}

struct SemanticLineView: View {
    let line: SemanticLine
    
    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            ForEach(line.content) { run in
                SemanticRunView(run)
            }
        }
        .padding(.vertical, 1) // effectively line spacing
    }
}

struct SemanticRunView: View {
    let run: SemanticRun
    
    init(_ run: SemanticRun) {
        self.run = run
    }
    
    var body: some View {
        Group {
            switch run.type {
            case .standard:
                Text(run.string)
            case .comment:
                Text(run.string)
                    .foregroundColor(.gray)
            case .keyword:
                Text(run.string)
                    .foregroundColor(.pink)
            case .variable:
                Text(run.string)
            case .recordName:
                Text(run.string)
                    .foregroundColor(.cyan)
            case .class:
                Button {
                    print("Clicked class:", run.string)
                } label: {
                    Text(run.string)
                        .foregroundColor(.mint)
                }
                .buttonStyle(.plain)
            case .protocol:
                Button {
                    print("Clicked protocol:", run.string)
                } label: {
                    Text(run.string)
                        .foregroundColor(.teal)
                }
                .buttonStyle(.plain)
            case .numeric:
                Text(run.string)
                    .foregroundColor(.purple)
            default:
                Text(run.string)
            }
        }
        .lineLimit(1, reservesSpace: true)
    }
}

extension CDSemanticString {
    func splitLines() -> [SemanticLine] {
        var lines: [SemanticLine] = []
        
        var current: [SemanticRun] = []
        enumerateTypes { str, type in
            var movingSubstring: String = str
            while let lineBreakIndex = movingSubstring.firstIndex(of: "\n") {
                current.append(SemanticRun(id: current.count, string: String(movingSubstring[..<lineBreakIndex]), type: type))
                
                lines.append(SemanticLine(number: lines.count, content: current))
                current = []
                
                movingSubstring = String(movingSubstring[movingSubstring.index(after: lineBreakIndex)...])
            }
            current.append(SemanticRun(id: current.count, string: movingSubstring, type: type))
        }
        if !current.isEmpty {
            lines.append(SemanticLine(number: lines.count, content: current))
        }
        return lines
    }
}
