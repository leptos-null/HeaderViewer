//
//  ImageClassPicker.swift
//  HeaderViewer
//
//  Created by Leptos on 2/20/24.
//

import SwiftUI
import ClassDump

private enum ImageLoadState {
    case notLoaded
    case loading
    case loaded
    case loadError(Error)
}

private class ImageClassPickerModel: ObservableObject {
    let namedNode: NamedNode
    
    let imagePath: String
    let imageName: String
    
    let runtimeListings: RuntimeListings = .shared
    
    @Published var searchString: String
    
    @Published private(set) var classNames: [String] // not filtered
    @Published private(set) var runtimeObjects: [RuntimeObjectType] // filtered based on search
    @Published private(set) var loadState: ImageLoadState
    
    private static func runtimeObjectsFor(classNames: [String], searchString: String) -> [RuntimeObjectType] {
        let ret: [RuntimeObjectType] = classNames.map { .class(named: $0) }
        if searchString.isEmpty { return ret }
        return ret.filter { $0.name.localizedCaseInsensitiveContains(searchString) }
    }
    
    init(namedNode: NamedNode) {
        self.namedNode = namedNode
        
        let imagePath = namedNode.path
        self.imagePath = imagePath
        self.imageName = namedNode.name
        
        let classNames = CDUtilities.classNamesIn(image: imagePath)
        self.classNames = classNames
        
        let searchString = ""
        self.searchString = searchString
        
        self.runtimeObjects = Self.runtimeObjectsFor(classNames: classNames, searchString: searchString)
        
        self.loadState = runtimeListings.isImageLoaded(path: imagePath) ? .loaded : .notLoaded
        
        runtimeListings.$classList
            .map { _ in
                CDUtilities.classNamesIn(image: imagePath)
            }
            .assign(to: &$classNames)
        
        let debouncedSearch = $searchString
            .debounce(for: 0.08, scheduler: RunLoop.main)
        
        $classNames.combineLatest(debouncedSearch) { classNames, searchString in
            Self.runtimeObjectsFor(classNames: classNames, searchString: searchString)
        }
        .assign(to: &$runtimeObjects)
        
        runtimeListings.$imageList
            .map { imageList in
                imageList.contains(CDUtilities.patchImagePathForDyld(imagePath))
            }
            .filter { $0 } // only allow isLoaded to pass through; we don't want to erase an existing state
            .map { _ in
                ImageLoadState.loaded
            }
            .assign(to: &$loadState)
    }
    
    func tryLoadImage() {
        do {
            loadState = .loading
            try CDUtilities.loadImage(at: imagePath)
            // we could set .loaded here, but there are already pipelines that will update the state
        } catch {
            loadState = .loadError(error)
        }
    }
}

struct ImageClassPicker: View {
    @StateObject private var viewModel: ImageClassPickerModel
    @Binding private var selection: RuntimeObjectType?
    
    init(namedNode: NamedNode, selection: Binding<RuntimeObjectType?>) {
        _viewModel = StateObject(wrappedValue: ImageClassPickerModel(namedNode: namedNode))
        _selection = selection
    }
    
    var body: some View {
        Group {
            switch viewModel.loadState {
            case .notLoaded:
                StatusView {
                    Text("\(viewModel.imageName) is not yet loaded")
                        .padding(.top)
                    Button {
                        viewModel.tryLoadImage()
                    } label: {
                        Text("Load now")
                    }
                    .buttonStyle(.bordered)
                }
            case .loading:
                ProgressView()
                    .scenePadding()
            case .loaded:
                if viewModel.classNames.isEmpty {
                    StatusView {
                        Text("\(viewModel.imageName) is loaded however does not appear to contain any classes")
                            .padding(.top)
                    }
                } else {
                    let runtimeObjects = viewModel.runtimeObjects
                    ListView(runtimeObjects, selection: $selection) { runtimeObject in
                        RuntimeObjectRow(type: runtimeObject)
                    }
                    .id(runtimeObjects) // don't try to diff the List
                    .searchable(text: $viewModel.searchString)
                }
            case .loadError(let error):
                StatusView {
                    if let dlOpenError = error as? DlOpenError,
                       let errorMessage = dlOpenError.message {
                        Text(errorMessage)
                            .font(.callout.monospaced())
                            .padding(.top)
                    } else {
                        Text("An unknown error occured trying to load '\(viewModel.imagePath)'")
                            .padding(.top)
                    }
                }
            }
        }
        .navigationTitle(viewModel.imageName)
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
