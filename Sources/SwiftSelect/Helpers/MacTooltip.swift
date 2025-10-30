#if os(macOS)
import SwiftUI
import AppKit

public extension View {
    func macOSTooltip(_ tip: String?) -> some View {
        background(GeometryReader { childGeometry in
            MacTooltipView(tip, geometry: childGeometry) {
                self
            }
        })
    }
}

private struct MacTooltipView<Content>: View where Content: View {
    let content: () -> Content
    let tip: String?
    let geometry: GeometryProxy

    init(_ tip: String?, geometry: GeometryProxy, @ViewBuilder content: @escaping () -> Content) {
        self.content = content
        self.tip = tip
        self.geometry = geometry
    }

    var body: some View {
        MacTooltipRepresentable(tip, content: content)
            .frame(width: geometry.size.width, height: geometry.size.height)
    }
}

private struct MacTooltipRepresentable<Content: View>: NSViewRepresentable {
    typealias NSViewType = NSHostingView<Content>

    init(_ text: String?, @ViewBuilder content: () -> Content) {
        self.text = text
        self.content = content()
    }

    let text: String?
    let content: Content

    func makeNSView(context _: Context) -> NSHostingView<Content> {
        NSViewType(rootView: content)
    }

    func updateNSView(_ nsView: NSHostingView<Content>, context _: Context) {
        nsView.rootView = content
        nsView.toolTip = text
    }
}
#endif


