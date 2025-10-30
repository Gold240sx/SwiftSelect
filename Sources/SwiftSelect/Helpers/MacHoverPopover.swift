#if os(macOS)
import SwiftUI
import AppKit

public extension View {
    func macOSHoverPopover<Content: View>(isEnabled: Bool, yOffset: CGFloat = 10, @ViewBuilder content: @escaping () -> Content) -> some View {
        background(MacHoverPopoverRepresentable(isEnabled: isEnabled, yOffset: yOffset, content: content))
    }
}

private struct MacHoverPopoverRepresentable<Content: View>: NSViewRepresentable {
    final class HoverView: NSView {
        var isEnabled: Bool = false
        var yOffset: CGFloat = 10
        var content: (() -> Content)?

        private var tracking: NSTrackingArea?
        private var popover: NSPopover?
        private var openWork: DispatchWorkItem?
        private var closeWork: DispatchWorkItem?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let tracking { removeTrackingArea(tracking) }
            let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
            let area = NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil)
            addTrackingArea(area)
            tracking = area
        }

        override func mouseEntered(with event: NSEvent) {
            guard isEnabled else { return }
            closeWork?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.show() }
            openWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
        }

        override func mouseExited(with event: NSEvent) {
            openWork?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.hide() }
            closeWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
        }

        private func show() {
            guard let content else { return }
            if popover == nil {
                let p = NSPopover()
                p.behavior = .semitransient
                p.animates = true
                let host = NSHostingController(rootView: AnyView(content()))
                p.contentViewController = host
                popover = p
            } else {
                (popover?.contentViewController as? NSHostingController<AnyView>)?.rootView = AnyView(content())
            }
            if let host = popover?.contentViewController as? NSHostingController<AnyView> {
                host.view.layoutSubtreeIfNeeded()
                // With fixed SwiftUI width (280), rely on intrinsic fitted height
                let fit = host.view.fittingSize
                // Compute available width within window so popover does not overflow horizontally
                var allowedWidth: CGFloat = 280
                if let window = self.window {
                    let rectInWindow = self.convert(self.bounds, to: nil)
                    let rectOnScreen = window.convertToScreen(rectInWindow)
                    let winFrame = window.frame
                    let anchorX = rectOnScreen.midX
                    let margin: CGFloat = 8
                    let leftSpace = max(anchorX - winFrame.minX - margin, 60)
                    let rightSpace = max(winFrame.maxX - anchorX - margin, 60)
                    allowedWidth = min(280, 2 * min(leftSpace, rightSpace))
                }
                let minWidth: CGFloat = 120
                let width = min(max(fit.width, minWidth), max(allowedWidth, minWidth))
                let height = max(fit.height, 20)
                popover?.contentSize = NSSize(width: width, height: height)
            }
            let rect = bounds.offsetBy(dx: 0, dy: yOffset)
            popover?.show(relativeTo: rect, of: self, preferredEdge: .minY)
        }

        private func hide() { popover?.close() }
    }

    let isEnabled: Bool
    let yOffset: CGFloat
    let content: () -> Content

    func makeNSView(context: Context) -> HoverView {
        let view = HoverView(frame: .zero)
        view.isEnabled = isEnabled
        view.yOffset = yOffset
        view.content = content
        return view
    }

    func updateNSView(_ nsView: HoverView, context: Context) {
        nsView.isEnabled = isEnabled
        nsView.yOffset = yOffset
        nsView.content = content
    }
}
#endif


