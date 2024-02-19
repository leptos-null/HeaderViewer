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

enum RuntimeObjectType: Hashable, Identifiable {
    case `class`(named: String)
    case `protocol`(named: String)
    
    var id: Self { self }
}

struct RuntimeObjectRow: View {
    let type: RuntimeObjectType
    
    private var systemImageName: String {
        switch type {
        case .class: return "c.square.fill"
        case .protocol: return "p.square.fill"
        }
    }
    
    private var iconColor: Color {
        switch type {
        case .class: return .green
        case .protocol: return .pink
        }
    }
    
    private var rowTitle: String {
        switch type {
        case .class(let named):
            return named
        case .protocol(let named):
            return named
        }
    }
    
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: systemImageName)
                .foregroundColor(iconColor)
            Text(rowTitle)
            Spacer()
        }
    }
}

struct RuntimeObjectDetail: View {
    let type: RuntimeObjectType
    
    private var title: String {
        switch type {
        case .class(let named):
            return named
        case .protocol(let named):
            return named
        }
    }
    
    private var semanticString: CDSemanticString {
        switch type {
        case .class(let named):
            CDClassModel(with: NSClassFromString(named))
                .semanticLines(withComments: false, synthesizeStrip: true)
        case .protocol(let named):
            CDProtocolModel(with: NSProtocolFromString(named))
                .semanticLines(withComments: false, synthesizeStrip: true)
        }
    }
    
    var body: some View {
        GeometryReader { geomProxy in
            ScrollView([.horizontal, .vertical]) {
                semanticString
                    .swiftText()
                    .textSelection(.enabled)
                    .multilineTextAlignment(.leading)
                    .scenePadding()
                    .frame(
                        minWidth: geomProxy.size.width, maxWidth: .infinity,
                        minHeight: geomProxy.size.height, maxHeight: .infinity,
                        alignment: .topLeading
                    )
            }
            .animation(.snappy, value: geomProxy.size)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(title)
        
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

struct ContentView: View {
    @StateObject private var objc: ObjcRuntime = .shared
    @State private var selectedObject: RuntimeObjectType?
    
    private var runtimeObjects: [RuntimeObjectType] {
        var ret: [RuntimeObjectType] = []
        ret += objc.classList.map { .class(named: $0) }
        ret += objc.protocolList.map { .protocol(named: $0) }
        return ret
    }
    
    var body: some View {
        NavigationSplitView {
            List(runtimeObjects, selection: $selectedObject) { runtimeObject in
                RuntimeObjectRow(type: runtimeObject)
            }
            .id(objc.classList) // don't try to diff the List
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

extension CDSemanticString {
    func swiftText() -> Text {
        var ret = Text(verbatim: "")
        enumerateTypes { str, type in
            switch type {
            case .standard:
                ret = ret + Text(verbatim: str)
            case .comment:
                ret = ret + Text(verbatim: str)
                    .foregroundColor(.gray)
            case .keyword:
                ret = ret + Text(verbatim: str)
                    .foregroundColor(.pink)
            case .variable:
                ret = ret + Text(verbatim: str)
            case .recordName:
                ret = ret + Text(verbatim: str)
                    .foregroundColor(.cyan)
            case .class:
                ret = ret + Text(verbatim: str)
                    .foregroundColor(.orange)
            case .protocol:
                ret = ret + Text(verbatim: str)
                    .foregroundColor(.teal)
            case .numeric:
                ret = ret + Text(verbatim: str)
                    .foregroundColor(.purple)
            default:
                ret = ret + Text(verbatim: str)
            }
        }
        return ret
            .font(.body.monospaced())
    }
}
