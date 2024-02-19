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
    
    var body: some View {
        NavigationSplitView {
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
                    Button {
                        // TODO
                    } label: {
                        Label("Browse", systemImage: "folder")
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
