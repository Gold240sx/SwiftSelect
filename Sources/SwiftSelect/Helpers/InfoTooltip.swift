import SwiftUI
#if os(macOS)
import AppKit
#endif

@available(iOS 13.0, macOS 12.0, tvOS 13.0, watchOS 6.0, *)
public struct InfoTooltipIcon: View {
    public let title: String?
    public let description: String?
    public let action: (() -> Void)?
    public let leadingIconName: String?

    @State private var isHovering: Bool = false

    public init(title: String? = nil, description: String?, action: (() -> Void)? = nil, leadingIconName: String? = nil) {
        self.title = title
        self.description = description
        self.action = action
        self.leadingIconName = leadingIconName
    }

    public var body: some View {
        Group {
            // Expand hover/tap target with padding 2 and rounded content shape
            let base = icon
                .padding(2)
                .contentShape(RoundedRectangle(cornerRadius: 4))

            #if os(macOS)
            let hoverArea = base
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) { isHovering = hovering }
                }
                .macOSHoverPopover(isEnabled: hasText, yOffset: 10) {
                TooltipContent(title: title, description: description, leadingIconName: leadingIconName)
            }
            if let action {
                Button(action: action) { hoverArea }.buttonStyle(.plain)
            } else {
                hoverArea
            }
            #else
            if let action {
                Button(action: action) { base }.buttonStyle(.plain)
            } else {
                base
            }
            #endif
        }
    }

    private var hasText: Bool { (description?.isEmpty == false) || (title?.isEmpty == false) }

    private var icon: some View {
        Group {
            #if os(macOS)
            if #available(macOS 11.0, *) {
                Image(systemName: "info.circle")
            } else {
                Text("i")
            }
            #else
            Image(systemName: "info.circle")
            #endif
        }
        .imageScale(.medium)
        .opacity(isHovering ? 1.0 : 0.5)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
    }
}

// MARK: - Hover helper
@available(iOS 13.0, macOS 11.0, tvOS 13.0, watchOS 6.0, *)
private extension View {
    @ViewBuilder
    func applyHover(showPopover: Binding<Bool>, hasText: Bool) -> some View {
        #if os(macOS)
        self.onHover { hovering in
            guard hasText else { return }
            showPopover.wrappedValue = hovering
        }
        #else
        self
        #endif
    }
    
    @ViewBuilder
    func tooltipPopover(isPresented: Binding<Bool>, title: String?, description: String?, leadingIconName: String?) -> some View {
        #if os(macOS)
        if #available(macOS 12.0, *) {
            self.popover(isPresented: isPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                TooltipContent(title: title, description: description, leadingIconName: leadingIconName)
            }
        } else {
            self.popover(isPresented: isPresented, arrowEdge: .top) {
                TooltipContent(title: title, description: description, leadingIconName: leadingIconName)
            }
        }
        #else
        self
        #endif
    }
}

@available(iOS 13.0, macOS 11.0, tvOS 13.0, watchOS 6.0, *)
private struct TooltipContent: View {
    let title: String?
    let description: String?
    let leadingIconName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title, !title.isEmpty { Text(title).font(.headline) }
            Group {
                if #available(macOS 13.0, iOS 16.0, *) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 8) { contentIconAndText }
                        VStack(alignment: .leading, spacing: 8) { contentIconAndText }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) { contentIconAndText }
                }
            }
        }
        .padding(10)
        .background(
            Group {
                #if os(macOS)
                if #available(macOS 12.0, *) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.windowBackgroundColor))
                }
                #else
                if #available(iOS 15.0, *) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(UIColor.secondarySystemBackground))
                }
                #endif
            }
        )
        .frame(maxWidth: 280, alignment: .leading)
    }

    @ViewBuilder
    private var contentIconAndText: some View {
        if let leadingIconName, !leadingIconName.isEmpty {
            Image(systemName: leadingIconName)
                .imageScale(.medium)
                .foregroundColor(.secondary)
        }
        if let description, !description.isEmpty {
            Text(description)
                .font(.footnote)
                .lineLimit(nil)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
