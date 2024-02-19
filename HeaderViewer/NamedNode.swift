//
//  NamedNode.swift
//  HeaderViewer
//
//  Created by Leptos on 2/18/24.
//

import Foundation

final class NamedNode {
    let name: String
    weak var parent: NamedNode?
    
    private(set) var children: [NamedNode] = []
    
    init(_ name: String, parent: NamedNode? = nil) {
        self.parent = parent
        self.name = name
    }
    
    var path: String {
        guard let parent else { return name }
        let directory = parent.path
        return directory + "/" + name
    }
    
    var isLeaf: Bool { children.isEmpty }
    
    func child(named name: String) -> NamedNode {
        if let existing = children.first(where: { $0.name == name }) {
            return existing
        }
        let child = NamedNode(name, parent: self)
        children.append(child)
        return child
    }
}

extension NamedNode: Hashable {
    static func == (lhs: NamedNode, rhs: NamedNode) -> Bool {
        lhs.name == rhs.name && lhs.parent === rhs.parent
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(parent)
    }
}
