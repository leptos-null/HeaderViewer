//
//  SemanticStringView.swift
//  HeaderViewer
//
//  Created by Leptos on 2/19/24.
//

import SwiftUI
import ClassDump

struct SemanticStringView: View {
    let semanticString: CDSemanticString
    
    init(_ semanticString: CDSemanticString) {
        self.semanticString = semanticString
    }
    
    var body: some View {
        GeometryReader { geomProxy in
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .leading) {
                    // use the longest line to expand the view as much as needed
                    // without having to render all the lines
                    let (lines, longestLineIndex) = semanticString.semanticLines()
                    if let longestLineIndex {
                        SemanticLineView(line: lines[longestLineIndex])
                            .padding(.horizontal, 4) // add some extra space, just in case
                            .opacity(0)
                    }
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(lines) { line in
                            SemanticLineView(line: line)
                        }
                    }
                    .accessibilityTextContentType(.sourceCode)
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
    }
}

private struct SemanticLine: Identifiable {
    let number: Int
    let content: [SemanticRun]
    
    var id: Int { number }
}

private struct SemanticRun: Identifiable {
    // it is the caller's responsibility to set a unique id relative to the container
    let id: Int
    let string: String
    let type: CDSemanticType
}

private struct SemanticOptimizedRun: Identifiable {
    let id: Int
    let type: SemanticOptimizedType
}

private enum SemanticOptimizedType {
    case text(Text)
    case navigation(RuntimeObjectType, Text)
}

private extension SemanticOptimizedRun {
    static func optimize(lineContent: [SemanticRun]) -> [Self] {
        var ret: [Self] = []
        
        var currentText: Text?
        var currentLength: Int = 0
        
        func pushRun() {
            if let prefix = currentText {
                ret.append(.init(id: ret.count, type: .text(prefix)))
                currentText = nil
                currentLength = 0
            }
        }
        
        for run in lineContent {
            func pushText(_ provider: (Text) -> Text) {
                let str = run.string
                let text = provider(Text(str))
                if let prefix = currentText {
                    currentText = prefix + text
                } else {
                    currentText = text
                }
                currentLength += str.count
                // optimization tuning parameter:
                // too low -> laying out each line may take a long time
                // too high -> Text may fail to layout
                if currentLength > 512 {
                    pushRun()
                }
            }
            
            func pushNavigation(_ objectType: RuntimeObjectType, _ provider: (Text) -> Text) {
                pushRun()
                let text = provider(Text(run.string))
                ret.append(.init(id: ret.count, type: .navigation(objectType, text)))
            }
            
            switch run.type {
            case .standard:
                pushText {
                    $0
                }
            case .comment:
                pushText {
                    $0
                        .foregroundColor(.gray)
                }
            case .keyword:
                pushText {
                    $0
                        .foregroundColor(.pink)
                }
            case .variable:
                pushText {
                    $0
                }
            case .recordName:
                pushText {
                    $0
                        .foregroundColor(.cyan)
                }
            case .class:
                pushNavigation(.class(named: run.string)) {
                    $0
                        .foregroundColor(.mint)
                }
            case .protocol:
                pushNavigation(.protocol(named: run.string)) {
                    $0
                        .foregroundColor(.teal)
                }
            case .numeric:
                pushText {
                    $0
                }
            default:
                pushText {
                    $0
                }
            }
        }
        pushRun()
        
        return ret
    }
}

private struct SemanticLineView: View {
    let line: SemanticLine
    
    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            ForEach(SemanticOptimizedRun.optimize(lineContent: line.content)) { run in
                switch run.type {
                case .text(let text):
                    text
                case .navigation(let runtimeObjectType, let text):
                    NavigationLink(value: runtimeObjectType) {
                        text
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .lineLimit(1, reservesSpace: true)
        .padding(.vertical, 1) // effectively line spacing
    }
}

private extension CDSemanticString {
    func semanticLines() -> (lines: [SemanticLine], longestLineIndex: Int?) {
        var lines: [SemanticLine] = []
        var longestLineIndex: Int?
        var longestLineLength: Int = 0
        
        var current: [SemanticRun] = []
        var currentLineLength = 0
        
        func pushLine() {
            let upcomingIndex = lines.count
            lines.append(SemanticLine(number: upcomingIndex, content: current))
            if currentLineLength > longestLineLength {
                longestLineLength = currentLineLength
                longestLineIndex = upcomingIndex
            }
            current = []
            currentLineLength = 0
        }
        
        enumerateTypes { str, type in
            func pushRun(string: String) {
                current.append(SemanticRun(id: current.count, string: string, type: type))
                currentLineLength += string.count
            }
            
            var movingSubstring: String = str
            while let lineBreakIndex = movingSubstring.firstIndex(of: "\n") {
                pushRun(string: String(movingSubstring[..<lineBreakIndex]))
                pushLine()
                // index after because we don't want to include '\n' in the output
                movingSubstring = String(movingSubstring[movingSubstring.index(after: lineBreakIndex)...])
            }
            pushRun(string: movingSubstring)
        }
        if !current.isEmpty {
            pushLine()
        }
        return (lines, longestLineIndex)
    }
}
