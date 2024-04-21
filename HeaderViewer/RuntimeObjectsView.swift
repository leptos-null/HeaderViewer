//
//  RuntimeObjectsView.swift
//  HeaderViewer
//
//  Created by Leptos on 4/21/24.
//

import SwiftUI

enum RuntimeTypeSearchScope: Hashable {
    case all
    case classes
    case protocols
}

extension RuntimeTypeSearchScope {
    var includesClasses: Bool {
        switch self {
        case .all: true
        case .classes: true
        case .protocols: false
        }
    }
    var includesProtocols: Bool {
        switch self {
        case .all: true
        case .classes: false
        case .protocols: true
        }
    }
}

struct RuntimeObjectsList: View {
    let runtimeObjects: [RuntimeObjectType] // caller's responsibility to filter this
    
    @Binding var selectedObject: RuntimeObjectType?
    @Binding var searchString: String
    @Binding var searchScope: RuntimeTypeSearchScope
    
    var body: some View {
        ListView(runtimeObjects, selection: $selectedObject) { runtimeObject in
            RuntimeObjectRow(type: runtimeObject)
        }
        .id(runtimeObjects) // don't try to diff the List
        .searchable(text: $searchString)
        .autocorrectionDisabled() // turn of auto-correct for the search field
        .searchScopes($searchScope) {
            Text("All")
                .tag(RuntimeTypeSearchScope.all)
            Text("Classes")
                .tag(RuntimeTypeSearchScope.classes)
            Text("Protocols")
                .tag(RuntimeTypeSearchScope.protocols)
        }
    }
}
