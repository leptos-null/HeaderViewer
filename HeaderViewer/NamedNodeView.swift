//
//  NamedNodeView.swift
//  HeaderViewer
//
//  Created by Leptos on 2/19/24.
//

import SwiftUI
import ClassDump

struct NamedNodeView: View {
    let node: NamedNode
    
    @State private var searchText: String = ""
    
    @EnvironmentObject private var listings: RuntimeListings
    
    private var children: [NamedNode] {
        if searchText.isEmpty { return node.children }
        return node.children.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        List(children, id: \.name) { child in
            NavigationLink(value: child) {
                HStack {
                    Image(systemName: child.isLeaf ? "doc" : "folder")
                        .foregroundColor(couldLoad(node: child) ? .orange : .blue)
                    Text(child.name)
                    Spacer()
                }
                .accessibilityLabel(child.name)
                .contextMenu {
                    if couldLoad(node: child) {
                        Button {
                            try? CDUtilities.loadImage(at: child.path)
                        } label: {
                            Label("Load", systemImage: "ellipsis")
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText)
        .autocorrectionDisabled() // turn of auto-correct for the search field
        .navigationTitle((node.name.isEmpty && node.parent == nil) ? "/" : node.name)
    }
    
    private func couldLoad(node: NamedNode) -> Bool {
        node.isLeaf && !listings.isImageLoaded(path: node.path)
    }
}
