//
//  ListView.swift
//  HeaderViewer
//
//  Created by Leptos on 2/24/24.
//

import SwiftUI

struct ListView<DataSource: RandomAccessCollection, SelectionValue: Hashable, RowContent: View>: View
where DataSource.Element: Identifiable, SelectionValue == DataSource.Element.ID /* List does not have this last constraint */ {
    @Binding private var selection: SelectionValue?
    private let dataSource: DataSource
    private let rowBuilder: (DataSource.Element) -> RowContent
    
    init(_ dataSource: DataSource, selection: Binding<SelectionValue?>, @ViewBuilder rowBuilder: @escaping (DataSource.Element) -> RowContent) {
        _selection = selection
        self.dataSource = dataSource
        self.rowBuilder = rowBuilder
    }
    
    var body: some View {
#if os(macOS)
        // `List` is not lazy on macOS
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(dataSource) { dataItem in
                    Row(isSelected: .init(get: {
                        dataItem.id == selection
                    }, set: { isSelected in
                        selection = dataItem.id
                    })) {
                        rowBuilder(dataItem)
                    }
                }
            }
            .padding(.horizontal, 10)
        }
#else
        List(dataSource, selection: $selection, rowContent: rowBuilder)
#endif
    }
}

#if os(macOS)
private extension ListView {
    struct Row<Content: View>: View {
        @Binding var isSelected: Bool
        let content: () -> Content
        
        init(isSelected: Binding<Bool>, @ViewBuilder content: @escaping  () -> Content) {
            _isSelected = isSelected
            self.content = content
        }
        
        var body: some View {
            content()
                .padding(6)
                .contentShape(.interaction, Rectangle())
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.tint)
                    }
                }
                .onTapGesture {
                    isSelected = true
                }
        }
    }
}
#endif
