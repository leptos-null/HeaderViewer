//
//  ContentView.swift
//  HeaderViewer
//
//  Created by Leptos on 2/17/24.
//

import SwiftUI
import ClassDump

struct ContentView: View {
    @State private var selectedObject: RuntimeObjectType?
    
    var body: some View {
        NavigationSplitView {
            ContentRootView(selectedObject: $selectedObject)
        } detail: {
            if let selectedObject {
                NavigationStack {
                    RuntimeObjectDetail(type: selectedObject)
                        .navigationDestination(for: RuntimeObjectType.self) { object in
                            RuntimeObjectDetail(type: object)
                        }
                }
            } else {
                Text("Select a class or protocol")
                    .scenePadding()
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

struct ContentRootView: View {
    private static let dscRootNode = CDUtilities.dyldSharedCacheImageRootNode
    
    @Binding var selectedObject: RuntimeObjectType?
    
    var body: some View {
        NavigationStack {
            AllRuntimeObjectsView(selectedObject: $selectedObject)
                .navigationTitle("Header Viewer")
                .toolbar {
                    ToolbarItem {
                        NavigationLink(value: Self.dscRootNode) {
                            Label("System Images", systemImage: "folder")
                        }
                    }
                }
                .navigationDestination(for: NamedNode.self) { namedNode in
                    if namedNode.isLeaf {
                        ImageRuntimeObjectsView(namedNode: namedNode, selection: $selectedObject)
                    } else {
                        NamedNodeView(node: namedNode)
                            .environmentObject(RuntimeListings.shared)
                    }
                }
        }
    }
}

private class AllRuntimeObjectsViewModel: ObservableObject {
    let runtimeListings: RuntimeListings = .shared
    
    @Published var searchString: String
    @Published var searchScope: RuntimeTypeSearchScope
    
    @Published private(set) var runtimeObjects: [RuntimeObjectType] // filtered based on search
    
    private static func runtimeObjectsFor(classNames: [String], protocolNames: [String], searchString: String, searchScope: RuntimeTypeSearchScope) -> [RuntimeObjectType] {
        var ret: [RuntimeObjectType] = []
        if searchScope.includesClasses {
            ret += classNames.map { .class(named: $0) }
        }
        if searchScope.includesProtocols {
            ret += protocolNames.map { .protocol(named: $0) }
        }
        if searchString.isEmpty { return ret }
        return ret.filter { $0.name.localizedCaseInsensitiveContains(searchString) }
    }
    
    init() {
        let searchString = ""
        let searchScope: RuntimeTypeSearchScope = .all
        
        self.searchString = searchString
        self.searchScope = searchScope
        self.runtimeObjects = Self.runtimeObjectsFor(
            classNames: runtimeListings.classList, protocolNames: runtimeListings.protocolList,
            searchString: searchString, searchScope: searchScope
        )
        
        let debouncedSearch = $searchString
            .debounce(for: 0.08, scheduler: RunLoop.main)
        
        $searchScope
            .combineLatest(debouncedSearch, runtimeListings.$classList, runtimeListings.$protocolList) {
                Self.runtimeObjectsFor(
                    classNames: $2, protocolNames: $3,
                    searchString: $1, searchScope: $0
                )
            }
            .assign(to: &$runtimeObjects)
    }
}

private struct AllRuntimeObjectsView: View {
    @StateObject private var viewModel: AllRuntimeObjectsViewModel
    @Binding var selectedObject: RuntimeObjectType?
    
    init(selectedObject: Binding<RuntimeObjectType?>) {
        _viewModel = StateObject(wrappedValue: AllRuntimeObjectsViewModel())
        _selectedObject = selectedObject
    }
    
    var body: some View {
        RuntimeObjectsList(
            runtimeObjects: viewModel.runtimeObjects, selectedObject: $selectedObject,
            searchString: $viewModel.searchString, searchScope: $viewModel.searchScope
        )
    }
}
