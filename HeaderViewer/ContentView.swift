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

private enum RuntimeTypeSearchScope: Hashable {
    case all
    case classes
    case protocols
}

private extension RuntimeTypeSearchScope {
    var includesClasses: Bool {
        switch self {
        case .all: true
        case .classes: true
        case .protocols: false
        }
    }
    var includesProtocols: Bool {
        switch self {
        case .all: true
        case .classes: false
        case .protocols: true
        }
    }
}

private class ContentRootViewModel: ObservableObject {
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

struct ContentRootView: View {
    @StateObject private var viewModel: ContentRootViewModel
    @Binding var selectedObject: RuntimeObjectType?
    
    init(selectedObject: Binding<RuntimeObjectType?>) {
        _viewModel = StateObject(wrappedValue: ContentRootViewModel())
        _selectedObject = selectedObject
    }
    
    var body: some View {
        NavigationStack {
            let runtimeObjects = viewModel.runtimeObjects
            ListView(runtimeObjects, selection: $selectedObject) { runtimeObject in
                RuntimeObjectRow(type: runtimeObject)
            }
            .id(runtimeObjects) // don't try to diff the List
            .searchable(text: $viewModel.searchString)
            .searchScopes($viewModel.searchScope) {
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
                        Label("System Images", systemImage: "folder")
                    }
                }
            }
            .navigationDestination(for: NamedNode.self) { namedNode in
                if namedNode.isLeaf {
                    ImageClassPicker(namedNode: namedNode, selection: $selectedObject)
                } else {
                    NamedNodeView(node: namedNode)
                        .environmentObject(RuntimeListings.shared)
                }
            }
        }
    }
}
