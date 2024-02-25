//
//  ImageClassPicker.swift
//  HeaderViewer
//
//  Created by Leptos on 2/20/24.
//

import SwiftUI
import ClassDump

struct ImageClassPicker: View {
    let namedNode: NamedNode
    @Binding private var selection: RuntimeObjectType?
    @State private var searchString: String = ""
    
    @EnvironmentObject private var listings: RuntimeListings
    
    private var classNames: [String] {
        CDUtilities.classNamesIn(image: namedNode.path)
    }
    
    init(namedNode: NamedNode, selection: Binding<RuntimeObjectType?>) {
        self.namedNode = namedNode
        _selection = selection
    }
    
    private var runtimeObjects: [RuntimeObjectType] {
        let ret: [RuntimeObjectType] = classNames.map { .class(named: $0) }
        if searchString.isEmpty { return ret }
        return ret.filter { $0.name.localizedCaseInsensitiveContains(searchString) }
    }
    
    var body: some View {
        Group {
            if listings.isImageLoaded(path: namedNode.path) {
                let runtimeObjects = self.runtimeObjects
                if runtimeObjects.isEmpty {
                    VStack {
                        Text("\(namedNode.name) is loaded however does not appear to contain any classes")
                            .padding(.top)
                        Spacer()
                    }
                    .scenePadding()
                } else {
                    ListView(runtimeObjects, selection: $selection) { runtimeObject in
                        RuntimeObjectRow(type: runtimeObject)
                    }
                    .id(runtimeObjects) // don't try to diff the List
                    .searchable(text: $searchString)
                }
            } else {
                VStack {
                    Text("\(namedNode.name) is not yet loaded")
                        .padding(.top)
                    Button {
                        CDUtilities.loadImage(at: namedNode.path)
                    } label: {
                        Text("Load now")
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
                .scenePadding()
            }
        }
        .navigationTitle(namedNode.name)
    }
}
