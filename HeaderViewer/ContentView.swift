//
//  ContentView.swift
//  HeaderViewer
//
//  Created by Leptos on 2/17/24.
//

import SwiftUI
import ClassDump

private enum RuntimeTypeSearchScope: Hashable {
    case all
    case classes
    case protocols
}

struct ContentView: View {
    @StateObject private var listings: RuntimeListings = .shared

    @State private var selectedObject: RuntimeObjectType?
    @State private var searchString: String = ""
    @State private var searchScope: RuntimeTypeSearchScope = .all
    
    private var runtimeObjects: [RuntimeObjectType] {
        var ret: [RuntimeObjectType] = []
        if searchScope != .protocols {
            ret += listings.classList.map { .class(named: $0) }
        }
        if searchScope != .classes {
            ret += listings.protocolList.map { .protocol(named: $0) }
        }
        if searchString.isEmpty { return ret }
        return ret.filter { $0.name.localizedCaseInsensitiveContains(searchString) }
    }
    
    
    var body: some View {
        NavigationSplitView {
            NavigationStack {
                List(runtimeObjects, selection: $selectedObject) { runtimeObject in
                    RuntimeObjectRow(type: runtimeObject)
                }
                .id(runtimeObjects) // don't try to diff the List
                .searchable(text: $searchString)
                .searchScopes($searchScope) {
                    Text("All")
                        .tag(RuntimeTypeSearchScope.all)
                    Text("Classes")
                        .tag(RuntimeTypeSearchScope.classes)
                    Text("Protocols")
                        .tag(RuntimeTypeSearchScope.protocols)
                }
                .navigationTitle("Header Viewer")
                .toolbar {
                    ToolbarItem {
                        NavigationLink(value: CDUtilities.dyldSharedCacheImageRootNode) {
                            Label("Browse", systemImage: "folder")
                        }
                    }
                }
                .navigationDestination(for: NamedNode.self) { namedNode in
                    if namedNode.isLeaf {
                        ImageClassPicker(namedNode: namedNode, selection: $selectedObject)
                            .environmentObject(listings)
                    } else {
                        NamedNodeView(node: namedNode)
                            .environmentObject(listings)
                    }
                }
            }
        } detail: {
            NavigationStack {
                if let selectedObject {
                    RuntimeObjectDetail(type: selectedObject)
                        .navigationDestination(for: RuntimeObjectType.self) { object in
                            RuntimeObjectDetail(type: object)
                        }
                } else {
                    Text("Select a class or protocol")
                        .scenePadding()
                }
            }
        }
    }
}
