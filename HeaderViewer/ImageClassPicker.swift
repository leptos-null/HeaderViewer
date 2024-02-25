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
    @State private var loadError: Error?
    
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
            if let loadError {
                if let dlOpenError = loadError as? DlOpenError,
                   let errorMessage = dlOpenError.message {
                    StatusView {
                        Text(errorMessage)
                            .font(.callout.monospaced())
                            .padding(.top)
                    }
                } else {
                    StatusView {
                        Text("An unknown error occured trying to load '\(namedNode.path)'")
                            .padding(.top)
                    }
                }
            } else if listings.isImageLoaded(path: namedNode.path) {
                let runtimeObjects = self.runtimeObjects
                if runtimeObjects.isEmpty {
                    StatusView {
                        Text("\(namedNode.name) is loaded however does not appear to contain any classes")
                            .padding(.top)
                    }
                } else {
                    ListView(runtimeObjects, selection: $selection) { runtimeObject in
                        RuntimeObjectRow(type: runtimeObject)
                    }
                    .id(runtimeObjects) // don't try to diff the List
                    .searchable(text: $searchString)
                }
            } else {
                StatusView {
                    Text("\(namedNode.name) is not yet loaded")
                        .padding(.top)
                    Button {
                        do {
                            try CDUtilities.loadImage(at: namedNode.path)
                        } catch {
                            loadError = error
                        }
                    } label: {
                        Text("Load now")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .navigationTitle(namedNode.name)
    }
}

private struct StatusView<T: View>: View {
    let contents: () -> T
    
    init(@ViewBuilder contents: @escaping () -> T) {
        self.contents = contents
    }
    
    var body: some View {
        ScrollView(.vertical) {
            VStack {
                contents()
                Spacer()
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .scenePadding()
    }
}
