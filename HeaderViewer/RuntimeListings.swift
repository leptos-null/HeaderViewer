//
//  RuntimeListings.swift
//  HeaderViewer
//
//  Created by Leptos on 2/20/24.
//

import Foundation
import Combine
import ClassDump
import MachO.dyld

final class RuntimeListings: ObservableObject {
    static let shared = RuntimeListings()
    private static var sharedIfExists: RuntimeListings?
    
    @Published private(set) var classList: [String]
    @Published private(set) var protocolList: [String]
    @Published private(set) var imageList: [String]
    
    private let shouldReload = PassthroughSubject<Void, Never>()
    
    private var subscriptions: Set<AnyCancellable> = []
    
    private init() {
        self.classList = CDUtilities.classNames()
        self.protocolList = CDUtilities.protocolNames()
        self.imageList = CDUtilities.imageNames()
        
        RuntimeListings.sharedIfExists = self
        
        shouldReload
            .debounce(for: .milliseconds(15), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                self.classList = CDUtilities.classNames()
                self.protocolList = CDUtilities.protocolNames()
                self.imageList = CDUtilities.imageNames()
            }
            .store(in: &subscriptions)
        
        _dyld_register_func_for_add_image { _, _ in
            RuntimeListings.sharedIfExists?.shouldReload.send()
        }
        
        _dyld_register_func_for_remove_image { _, _ in
            RuntimeListings.sharedIfExists?.shouldReload.send()
        }
    }
    
    func isImageLoaded(path: String) -> Bool {
        imageList.contains(CDUtilities.patchImagePathForDyld(path))
    }
}

extension CDUtilities {
    class func imageNames() -> [String] {
        (0...)
            .lazy
            .map(_dyld_get_image_name)
            .prefix { $0 != nil }
            .compactMap { $0 }
            .map { String(cString: $0) }
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
        patchImagePathForDyld(image).withCString { cString in
            var classCount: UInt32 = 0
            guard let classNames = objc_copyClassNamesForImage(cString, &classCount) else { return [] }
            
            let names = sequence(first: classNames) { $0.successor() }
                .prefix(Int(classCount))
                .map { String(cString: $0.pointee) }
            
            classNames.deallocate()
            
            return names
        }
    }
}

extension CDUtilities {
    class func patchImagePathForDyld(_ imagePath: String) -> String {
        guard imagePath.starts(with: "/") else { return imagePath }
        let rootPath = ProcessInfo.processInfo.environment["DYLD_ROOT_PATH"]
        guard let rootPath else { return imagePath }
        return rootPath.appending(imagePath)
    }
    
    @discardableResult
    class func loadImage(at path: String) -> Bool {
        path.withCString { cString in
            dlopen(cString, RTLD_LAZY) != nil
        }
    }
}

extension CDUtilities {
    class var dyldSharedCacheImageRootNode: NamedNode {
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
}
