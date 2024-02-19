//
//  RuntimeObjectType.swift
//  HeaderViewer
//
//  Created by Leptos on 2/18/24.
//

import Foundation

enum RuntimeObjectType: Hashable, Identifiable {
    case `class`(named: String)
    case `protocol`(named: String)
    
    var id: Self { self }
}

extension RuntimeObjectType {
    var name: String {
        switch self {
        case .class(let name):
            return name
        case .protocol(let name):
            return name
        }
    }
}
