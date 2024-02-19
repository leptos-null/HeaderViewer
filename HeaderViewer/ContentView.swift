//
//  ContentView.swift
//  HeaderViewer
//
//  Created by Leptos on 2/17/24.
//

import SwiftUI
import MachO.dyld
import ObjectiveC.runtime
import ClassDump
import Combine

extension CDUtilities {
    class func imageNames() -> [String] {
        var imageCount: UInt32 = 0
        let imageNames = objc_copyImageNames(&imageCount)
        
        let names = sequence(first: imageNames) { $0.successor() }
            .prefix(Int(imageCount))
            .map { String(cString: $0.pointee) }
        
        imageNames.deallocate()
        
        return names
    }
    
    class func protocolNames() -> [String] {
        var protocolCount: UInt32 = 0
        guard let protocolList = objc_copyProtocolList(&protocolCount) else { return [] }
        
        let names = sequence(first: protocolList) { $0.successor() }
            .prefix(Int(protocolCount))
            .map { NSStringFromProtocol($0.pointee) }
        
        return names
    }
    
    class func classNamesIn(image: String) -> [String] {
        patchImagePathForDYLD(image).withCString(encodedAs: Unicode.UTF8.self) { cString in
            var classCount: UInt32 = 0
            guard let classNames = objc_copyClassNamesForImage(cString, &classCount) else { return [] }
            
            let names = sequence(first: classNames) { $0.successor() }
                .prefix(Int(classCount))
                .map { String(cString: $0.pointee) }
            
            classNames.deallocate()
            
            return names
        }
    }
    
    class func patchImagePathForDYLD(_ imagePath: String) -> String {
        let rootPath = ProcessInfo.processInfo.environment["DYLD_ROOT_PATH"]
        guard let rootPath else { return imagePath }
        return rootPath.appending(imagePath)
    }
}

final class ObjcRuntime: ObservableObject {
    static let shared = ObjcRuntime()
    private static var sharedIfExists: ObjcRuntime?
    
    @Published private(set) var classList: [String]
    @Published private(set) var protocolList: [String]
    @Published private(set) var imageList: [String]
    
    private let shouldReloadClassList = PassthroughSubject<Void, Never>()
    
    private var subscriptions: Set<AnyCancellable> = []
    
    private init() {
        self.classList = CDUtilities.safeClassNames()
        self.protocolList = CDUtilities.protocolNames()
        self.imageList = CDUtilities.imageNames()
        
        ObjcRuntime.sharedIfExists = self
        
        shouldReloadClassList
            .debounce(for: .milliseconds(15), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                self.classList = CDUtilities.safeClassNames()
                self.protocolList = CDUtilities.protocolNames()
                self.imageList = CDUtilities.imageNames()
            }
            .store(in: &subscriptions)
        
        _dyld_register_func_for_add_image { _, _ in
            ObjcRuntime.sharedIfExists?.shouldReloadClassList.send()
        }
        
        _dyld_register_func_for_remove_image { _, _ in
            ObjcRuntime.sharedIfExists?.shouldReloadClassList.send()
        }
    }
}

private enum RuntimeTypeSearchScope: Hashable {
    case all
    case classes
    case protocols
}

struct ContentView: View {
    @StateObject private var objc: ObjcRuntime = .shared
    @State private var selectedObject: RuntimeObjectType?
    @State private var searchString: String = ""
    @State private var searchScope: RuntimeTypeSearchScope = .all
    
    private var runtimeObjects: [RuntimeObjectType] {
        var ret: [RuntimeObjectType] = []
        if searchScope != .protocols {
            ret += objc.classList.map { .class(named: $0) }
        }
        if searchScope != .classes {
            ret += objc.protocolList.map { .protocol(named: $0) }
        }
        if searchString.isEmpty { return ret }
        return ret.filter { $0.name.localizedCaseInsensitiveContains(searchString) }
    }
    
    private var dyldSharedCacheImageRootNode: NamedNode {
        let root = NamedNode("")
        for path in CDUtilities.dyldSharedCacheImagePaths() {
            var current = root
            for pathComponent in path.split(separator: "/") {
                switch pathComponent {
                case ".":
                    break // current
                case "..":
                    if let parent = current.parent {
                        current = parent
                    }
                default:
                    current = current.child(named: String(pathComponent))
                }
            }
        }
        return root
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
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(value: dyldSharedCacheImageRootNode) {
                            Label("Browse", systemImage: "folder")
                        }
                    }
                }
                .navigationDestination(for: NamedNode.self) { namedNode in
                    if namedNode.isLeaf {
                        ImageClassPicker(namedNode: namedNode, selection: $selectedObject)
                            .environmentObject(objc)
                    } else {
                        NamedNodeView(node: namedNode)
                            .environmentObject(objc)
                    }
                }
            }
        } detail: {
            if let selectedObject {
                RuntimeObjectDetail(type: selectedObject)
            } else {
                Text("Select a class or protocol")
                    .scenePadding()
            }
        }
    }
}

struct ImageClassPicker: View {
    let namedNode: NamedNode
    @Binding private var selection: RuntimeObjectType?
    @State private var searchString: String = ""
    
    // we don't read this directly, but when the loaded images change, we would like to know
    @EnvironmentObject private var objc: ObjcRuntime
    
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
        List(runtimeObjects, selection: $selection) { runtimeObject in
            RuntimeObjectRow(type: runtimeObject)
        }
        .id(runtimeObjects) // don't try to diff the List
        .searchable(text: $searchString)
        .navigationTitle(namedNode.name)
    }
}
