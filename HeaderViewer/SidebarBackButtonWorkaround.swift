//
//  SidebarBackButtonWorkaround.swift
//  HeaderViewer
//
//  Created by Leptos on 10/13/26.
//

import SwiftUI

extension View {
    @ViewBuilder
    func sidebarBackButtonWorkaround(navigationTitle: String? = nil) -> some View {
#if os(macOS)
        if #available(macOS 26.0, *) {
            self
                .modifier(SidebarBackButtonWorkaround(navigationTitle: navigationTitle))
        } else {
            self
        }
#else
        self
#endif
    }
}

#if os(macOS)
// in my testing on macOS 26.6.2, without `navigationBarBackButtonHidden`, the contents of the sidebar
// is sized at a 0 height.
// potentially related, `navigationBarBackButtonHidden` also causes the navigation title to not appear,
// so we have to show the navigation title ourselves when applying this workaround.
@available(macOS 26.0, *)
private struct SidebarBackButtonWorkaround: ViewModifier {
    var navigationTitle: String?
    
    @Environment(\.dismiss) private var dismiss
    
    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden()
            .toolbar {
                if let navigationTitle {
                    ToolbarItem(placement: .principal) {
                        Text(navigationTitle)
                    }
                }
                /* description of my observation of each "placement", in this specific configuration on macOS 26.6.2
                 *
                 * `automatic`          - trailing within the sidebar, immediately before (i.e. on the leading side of) the sidebar collapse button
                 * `cancellationAction` - trailing within the sidebar, immediately before (i.e. on the leading side of) the sidebar collapse button
                 * `confirmationAction` - trailing within the sidebar, immediately before (i.e. on the leading side of) the sidebar collapse button
                 * `primaryAction`      - trailing within the sidebar, immediately before (i.e. on the leading side of) the sidebar collapse button
                 *
                 * `destructiveAction` - leading within the sidebar, immediately after (i.e. on the trailing side of) the "stop lights"
                 *
                 * `keyboard` - leading within the Touch Bar
                 *
                 * `navigation` - leading within the _detail_ panel, which is trailing relative to the sidebar collapse button
                 *
                 * `principal` - centered within the sidebar, immediately trailing the navigation title (custom `ToolbarItem` above)
                 * `status`    - centered within the sidebar, immediately trailing the navigation title (custom `ToolbarItem` above)
                 *
                 * `secondaryAction` - centered within the sidebar, immediately leading the navigation title (custom `ToolbarItem` above)
                 *
                 * `accessoryBar` - in a row beneath the navigation bar within the _detail_ panel
                 */
                ToolbarItem(placement: .destructiveAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Back", systemImage: "chevron.backward")
                    }
                }
            }
    }
}
#endif
