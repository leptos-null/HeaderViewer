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
                ListView(runtimeObjects, selection: $selectedObject) { runtimeObject in
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
                            Label("System Images", systemImage: "folder")
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

private struct ListView<DataSource: RandomAccessCollection, SelectionValue: Hashable, RowContent: View>: View
where DataSource.Element: Identifiable, SelectionValue == DataSource.Element.ID /* List does not have this last constraint */ {
    @Binding private var selection: SelectionValue?
    private let dataSource: DataSource
    private let rowBuilder: (DataSource.Element) -> RowContent
    
    init(_ dataSource: DataSource, selection: Binding<SelectionValue?>, @ViewBuilder rowBuilder: @escaping (DataSource.Element) -> RowContent) {
        _selection = selection
        self.dataSource = dataSource
        self.rowBuilder = rowBuilder
    }
    
    var body: some View {
#if os(macOS)
        // `List` is not lazy on macOS
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(dataSource) { dataItem in
                    Row(isSelected: .init(get: {
                        dataItem.id == selection
                    }, set: { isSelected in
                        selection = dataItem.id
                    })) {
                        rowBuilder(dataItem)
                    }
                }
            }
            .padding(.horizontal, 10)
        }
#else
        List(dataSource, selection: $selection, rowContent: rowBuilder)
#endif
    }
}

#if os(macOS)
private extension ListView {
    struct Row<Content: View>: View {
        @Binding var isSelected: Bool
        let content: () -> Content
        
        init(isSelected: Binding<Bool>, @ViewBuilder content: @escaping  () -> Content) {
            _isSelected = isSelected
            self.content = content
        }
        
        var body: some View {
            content()
                .padding(6)
                .contentShape(.interaction, Rectangle())
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.tint)
                    }
                }
                .onTapGesture {
                    isSelected = true
                }
        }
    }
}
#endif
