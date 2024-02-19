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
    
    @EnvironmentObject private var objc: ObjcRuntime
    
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
                .contextMenu {
                    if couldLoad(node: child) {
                        Button {
                            loadImage(at: child.path)
                        } label: {
                            Label("Load", systemImage: "ellipsis")
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText)
        .navigationTitle((node.name.isEmpty && node.parent == nil) ? "/" : node.name)
    }
    
    private func couldLoad(node: NamedNode) -> Bool {
        node.isLeaf && !isImageLoaded(node.path)
    }
    
    private func isImageLoaded(_ imagePath: String) -> Bool {
        objc.imageList.contains(CDUtilities.patchImagePathForDYLD(imagePath))
    }
    
    private func loadImage(at path: String) {
        let dlStatus: (success: Bool, errorString: String?) = path.withCString { cString in
            let handle = dlopen(cString, RTLD_LAZY)
            let errStr = dlerror()
            if handle != nil { return (true, nil) }
            guard let errStr else { return (false, nil) }
            return (false, String(cString: errStr))
        }
        guard dlStatus.success else {
            print("dlopen(\"\(path)\", RTLD_LAZY)", "->", dlStatus.errorString ?? "???")
            return
        }
    }
}
