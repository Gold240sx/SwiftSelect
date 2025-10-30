//
//  MultiSelect.swift
//  MultiSelect
//
//  Created by Michael Martell on 10/23/25.
//

import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
import AVFoundation // 👇 for sound playback (optional)
#endif

// Developer NOTES:
// This is disconnected from the Application. This serves as a copy and paste code implementation... if desired to use this File instead of Swift Select Package import... The use of MultiSelectDropdown and SwiftSelect are the exact same


// MARK: - Public Configuration & Models

public enum MIconType {
    case image(Image)
    case emoji(String)
}

public struct MListOptions {
    public enum Style {
        case connected
        case detached
    }

    public enum Background {
        case system
        case light
        case dark
        case glass
    }

    public var maxHeight: CGFloat
    public var style: Style
    public var background: Background
    
    public init(
        maxHeight: CGFloat = 250,
        style: Style = .connected,
        background: Background = .system
    ) {
        self.maxHeight = maxHeight
        self.style = style
        self.background = background
    }
}

public struct MSelectOption: Identifiable, Hashable {
    public let id: UUID
    public let title: String
    public let value: String
    public let icon: MIconType?
    public let description: String?
    public let isDisabled: Bool
    public let group: String?
    
    public init(
        id: UUID = UUID(),
        _ title: String,
        value: String,
        icon: Image? = nil,
        description: String? = nil,
        group: String? = nil,
        isDisabled: Bool = false
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.icon = icon.map { .image($0) }
        self.description = description
        self.group = group
        self.isDisabled = isDisabled
    }
    
    public init(
        id: UUID = UUID(),
        _ title: String,
        value: String,
        emoji: String,
        description: String? = nil,
        group: String? = nil,
        isDisabled: Bool = false
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.icon = .emoji(emoji)
        self.description = description
        self.group = group
        self.isDisabled = isDisabled
    }
    
    public func hash(into hasher: inout Hasher) { hasher.combine(title) }
    public static func == (lhs: MSelectOption, rhs: MSelectOption) -> Bool { lhs.id == rhs.id }
}

public enum MDropDownPosition { case top, bottom }

// MARK: - Internal Overlay System (for isAbsolute)
struct DropdownMetadata {
    let id: UUID
    let options: [MSelectOption]
    let selection: Binding<Set<String>>
    let isMultiSelect: Bool
    let anchor: CGRect
    let listOptions: MListOptions
    let enableHaptics: Bool
    let enableSound: Bool
    let enableSearch: Bool
    let close: () -> Void
    let onPositionUpdate: (MDropDownPosition) -> Void
    let isAbsolute: Bool
    let onHeightChange: (CGFloat) -> Void
}

class DropdownManager: ObservableObject {
    @Published var current: DropdownMetadata?
}

struct DropdownEnvironmentKey: EnvironmentKey {
    static var defaultValue: DropdownManager = DropdownManager()
}

extension EnvironmentValues {
    var dropdownManager: DropdownManager {
        get { self[DropdownEnvironmentKey.self] }
        set { self[DropdownEnvironmentKey.self] = newValue }
    }
}

public struct MDropdownOverlay: ViewModifier {
    @StateObject private var manager = DropdownManager()

    public func body(content: Content) -> some View {
        content
            .environment(\.dropdownManager, manager)
            .overlay(alignment: .topLeading) {
                if let metadata = manager.current {
                    GeometryReader { proxy in
                        DropdownContainerView(metadata: metadata, rootViewProxy: proxy)
                    }
                }
            }
    }
}

// MARK: - View Helpers & Extensions (Moved to top)

extension View {
    public func mDropdownOverlay() -> some View {
        self.modifier(MDropdownOverlay())
    }
}

struct CustomOutlineModifier<S: ShapeStyle, V: Shape>: ViewModifier {
    let shapeStyle: S
    let shape: V
    let lineWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(
                shape.stroke(shapeStyle, lineWidth: lineWidth)
            )
    }
}

extension View {
    func customOutline<S: ShapeStyle, V: Shape>(
        _ shapeStyle: S,
        shape: V,
        lineWidth: CGFloat = 1
    ) -> some View {
        self.modifier(
            CustomOutlineModifier(
                shapeStyle: shapeStyle,
                shape: shape,
                lineWidth: lineWidth
            )
        )
    }
    
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Keyboard Handling (Cross-Platform)

struct KeyPress {
    enum Key {
        case upArrow
        case downArrow
        case `return`
        case escape
        case space
        case tab
    }
    enum Result { case handled, ignored }
    let key: Key
}

private struct KeyPressCaptureView: View {
    let handler: (KeyPress) -> KeyPress.Result
    var body: some View {
        #if os(macOS)
        MacKeyCapture(handler: handler)
            .frame(width: 0, height: 0)
        #else
        IOSKeyCapture(handler: handler)
            .frame(width: 0, height: 0)
        #endif
    }
}

#if os(iOS)
private struct IOSKeyCapture: UIViewRepresentable {
    let handler: (KeyPress) -> KeyPress.Result
    func makeUIView(context: Context) -> KeyCaptureView { KeyCaptureView(handler: handler) }
    func updateUIView(_ uiView: KeyCaptureView, context: Context) {}

    final class KeyCaptureView: UIView {
        let handler: (KeyPress) -> KeyPress.Result
        init(handler: @escaping (KeyPress) -> KeyPress.Result) {
            self.handler = handler
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override var canBecomeFirstResponder: Bool { true }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            _ = becomeFirstResponder()
        }
        override var keyCommands: [UIKeyCommand]? {
            [
                UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(kUp)),
                UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(kDown)),
                UIKeyCommand(input: "\r", modifierFlags: [], action: #selector(kReturn)),
                UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(kEsc)),
                UIKeyCommand(input: " ", modifierFlags: [], action: #selector(kSpace)),
                UIKeyCommand(input: "\t", modifierFlags: [], action: #selector(kTab))
            ]
        }
        @objc private func kUp() { _ = handler(KeyPress(key: .upArrow)) }
        @objc private func kDown() { _ = handler(KeyPress(key: .downArrow)) }
        @objc private func kReturn() { _ = handler(KeyPress(key: .return)) }
        @objc private func kEsc() { _ = handler(KeyPress(key: .escape)) }
        @objc private func kSpace() { _ = handler(KeyPress(key: .space)) }
        @objc private func kTab() { _ = handler(KeyPress(key: .tab)) }
    }
}
#else
private struct MacKeyCapture: NSViewRepresentable {
    let handler: (KeyPress) -> KeyPress.Result
    func makeNSView(context: Context) -> KeyCaptureNSView { KeyCaptureNSView(handler: handler) }
    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {}

    final class KeyCaptureNSView: NSView {
        let handler: (KeyPress) -> KeyPress.Result
        init(handler: @escaping (KeyPress) -> KeyPress.Result) {
            self.handler = handler
            super.init(frame: .zero)
            autoresizingMask = []
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override var acceptsFirstResponder: Bool { true }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.makeFirstResponder(self)
        }
        override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 126: _ = handler(KeyPress(key: .upArrow))
            case 125: _ = handler(KeyPress(key: .downArrow))
            case 36: _ = handler(KeyPress(key: .return))
            case 53: _ = handler(KeyPress(key: .escape))
            case 49: _ = handler(KeyPress(key: .space))
            case 48: _ = handler(KeyPress(key: .tab))
            default: super.keyDown(with: event)
            }
        }
    }
}
#endif

extension View {
    func onKeyPress(_ handler: @escaping (KeyPress) -> KeyPress.Result) -> some View {
        self.background(KeyPressCaptureView(handler: handler))
    }
}


// MARK: - Custom Rounded Corner Shape (Cross-Platform)

/// A custom `OptionSet` to define corners in a platform-agnostic way.
struct RectCorner: OptionSet {
    let rawValue: Int

    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomLeft = RectCorner(rawValue: 1 << 2)
    static let bottomRight = RectCorner(rawValue: 1 << 3)
    
    static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

/// A `Shape` that rounds specific corners of a rectangle, compatible with both iOS and macOS.
struct RoundedCornerShape: Shape {
    var radius: CGFloat = .infinity
    var corners: RectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        #if os(macOS)
        let path = NSBezierPath()
        let cornerRadius = min(radius, rect.width / 2, rect.height / 2)
        
        // Points
        let topLeft = rect.origin
        let topRight = CGPoint(x: rect.maxX, y: rect.minY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)

        // Start
        path.move(to: CGPoint(x: topLeft.x + cornerRadius, y: topLeft.y))

        // Top edge and top-right corner
        path.line(to: CGPoint(x: topRight.x - cornerRadius, y: topRight.y))
        if corners.contains(.topRight) {
            path.appendArc(withCenter: CGPoint(x: topRight.x - cornerRadius, y: topRight.y + cornerRadius), radius: cornerRadius, startAngle: 270, endAngle: 360)
        } else {
            path.line(to: topRight)
        }

        // Right edge and bottom-right corner
        path.line(to: CGPoint(x: bottomRight.x, y: bottomRight.y - cornerRadius))
        if corners.contains(.bottomRight) {
            path.appendArc(withCenter: CGPoint(x: bottomRight.x - cornerRadius, y: bottomRight.y - cornerRadius), radius: cornerRadius, startAngle: 0, endAngle: 90)
        } else {
            path.line(to: bottomRight)
        }

        // Bottom edge and bottom-left corner
        path.line(to: CGPoint(x: bottomLeft.x + cornerRadius, y: bottomLeft.y))
        if corners.contains(.bottomLeft) {
            path.appendArc(withCenter: CGPoint(x: bottomLeft.x + cornerRadius, y: bottomLeft.y - cornerRadius), radius: cornerRadius, startAngle: 90, endAngle: 180)
        } else {
            path.line(to: bottomLeft)
        }

        // Left edge and top-left corner
        path.line(to: CGPoint(x: topLeft.x, y: topLeft.y + cornerRadius))
        if corners.contains(.topLeft) {
            path.appendArc(withCenter: CGPoint(x: topLeft.x + cornerRadius, y: topLeft.y + cornerRadius), radius: cornerRadius, startAngle: 180, endAngle: 270)
        } else {
            path.line(to: topLeft)
        }

        path.close()
        return Path(path.cgPath)

        #else
        var uiKitCorners: UIRectCorner = []
        if corners.contains(.topLeft) { uiKitCorners.insert(.topLeft) }
        if corners.contains(.topRight) { uiKitCorners.insert(.topRight) }
        if corners.contains(.bottomLeft) { uiKitCorners.insert(.bottomLeft) }
        if corners.contains(.bottomRight) { uiKitCorners.insert(.bottomRight) }
        
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: uiKitCorners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
        #endif
    }
}


// MARK: - MultiSelectDropdown
public struct MultiSelectDropdown: View {
    // Public Properties
    public var placeholder: String
    public var isMultiSelect: Bool
    public var isAbsolute: Bool
    public var listOptions: MListOptions
    public var enableHaptics: Bool
    public var enableSound: Bool
    public var enableSearch: Bool
    public var accessibilityLabelText: String?
    @Binding public var selectedValues: Set<String>
    
    // Internal State & Data Source
    @State private var internalOptions: [MSelectOption]
    @State private var isLoading: Bool
    private let optionsLoader: (() async -> [MSelectOption])?
    
    @State private var isExpanded = false
    @State private var buttonFrame: CGRect = .zero
    @State private var dropdownPosition: MDropDownPosition = .bottom
    @Environment(\.dropdownManager) private var dropdownManager
    private let componentId = UUID()
    @State private var inlineGapHeight: CGFloat = 0
    
    // Static Initializer
    public init(
        options: [MSelectOption],
        placeholder: String = "Select...",
        isMultiSelect: Bool = true,
        isAbsolute: Bool = false,
        listOptions: MListOptions = .init(),
        selectedValues: Binding<Set<String>>,
        enableHaptics: Bool = true,
        enableSound: Bool = true,
        enableSearch: Bool = false,
        accessibilityLabelText: String? = nil
    ) {
        self._internalOptions = State(initialValue: options)
        self.placeholder = placeholder
        self.isMultiSelect = isMultiSelect
        self.isAbsolute = isAbsolute
        self.listOptions = listOptions
        self._selectedValues = selectedValues
        self.enableHaptics = enableHaptics
        self.enableSound = enableSound
        self.enableSearch = enableSearch
        self.accessibilityLabelText = accessibilityLabelText
        self.optionsLoader = nil
        self._isLoading = State(initialValue: false)
    }
    
    // Async Initializer
    public init(
        placeholder: String = "Select...",
        optionsLoader: @escaping () async -> [MSelectOption],
        isMultiSelect: Bool = true,
        isAbsolute: Bool = false,
        listOptions: MListOptions = .init(),
        selectedValues: Binding<Set<String>>,
        enableHaptics: Bool = true,
        enableSound: Bool = true,
        enableSearch: Bool = false,
        accessibilityLabelText: String? = nil
    ) {
        self._internalOptions = State(initialValue: [])
        self.placeholder = placeholder
        self.optionsLoader = optionsLoader
        self.isMultiSelect = isMultiSelect
        self.isAbsolute = isAbsolute
        self.listOptions = listOptions
        self._selectedValues = selectedValues
        self.enableHaptics = enableHaptics
        self.enableSound = enableSound
        self.enableSearch = enableSearch
        self.accessibilityLabelText = accessibilityLabelText
        self._isLoading = State(initialValue: true)
    }
    
    public var body: some View {
        ZStack(alignment: .topLeading) {
            if isExpanded && !isAbsolute {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation { isExpanded = false } }
                    .zIndex(1)
            }
            
            VStack(spacing: 0) {
                buttonView
                if !isAbsolute {
                    InlineDropdownContainerView(
                        options: internalOptions,
                        selection: $selectedValues,
                        isMultiSelect: isMultiSelect,
                        listOptions: listOptions,
                        enableHaptics: enableHaptics,
                        enableSound: enableSound,
                        enableSearch: enableSearch,
                        isVisible: isExpanded,
                        onClose: {
                            withAnimation { isExpanded = false }
                        }
                    )
                    .padding(.top, listOptions.style == .detached ? 10 : 0)
                    .zIndex(1)
                }
            }
            .zIndex(2)
        }
            .background(GeometryReader { geo in
                let newFrame = geo.frame(in: .global)
                Color.clear.onAppear {
                    self.buttonFrame = newFrame
                }
                .onChange(of: newFrame) { _, frame in
                    self.buttonFrame = frame
                    // If the overlay is currently showing for this component, update its anchor frame
                    if isExpanded && dropdownManager.current?.id == componentId {
                        updateOverlayMetadata(with: frame)
                    }
                }
            })
            .task {
                if let loader = optionsLoader {
                    if isLoading { // Only load if we started in a loading state
                        self.internalOptions = await loader()
                        self.isLoading = false
                    }
                }
            }
    }
    
    // MARK: - Subviews
    
    private var textColor: Color {
        switch listOptions.background {
        case .light:
            return .black
        case .dark:
            return .white
        default:
            return .primary
        }
    }
    
    private var secondaryTextColor: Color {
        switch listOptions.background {
        case .light:
            return .black.opacity(0.6)
        case .dark:
            return .white.opacity(0.6)
        default:
            return .secondary
        }
    }
    
    private var buttonView: some View {
        let shape = RoundedCornerShape(radius: 10, corners: buttonCorners)
        let backgroundColor: Color = {
            switch listOptions.background {
            case .system:
                #if os(iOS)
                return Color(UIColor.secondarySystemBackground)
                #else
                return Color(NSColor.windowBackgroundColor)
                #endif
            case .light: return .white
            case .dark: return .black
            case .glass: return .clear // Material is applied below
            }
        }()
        
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded.toggle()
                
                if isAbsolute {
                    if isExpanded {
                        updateOverlayMetadata(with: buttonFrame)
                    } else {
                        dropdownManager.current = nil
                    }
                }
            }
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .frame(width: 18, height: 18)
                    Text("Loading...")
                        .foregroundColor(.secondary)
                } else {
                    if let iconType = selectedDisplayInfo.icon {
                        switch iconType {
                        case .image(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .cornerRadius(4)
                                .foregroundColor(textColor)
                        case .emoji(let string):
                            Text(string)
                                .font(.title3)
                        }
                    }
                    Text(selectedDisplayInfo.title)
                        .fontWeight(selectedValues.isEmpty ? .regular : .bold)
                        .lineLimit(1)
                        .allowsTightening(true)
                        .foregroundColor(selectedValues.isEmpty ? textColor.opacity(0.75) : textColor)
                }
                
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundColor(textColor)
                    .rotationEffect(.degrees(isExpanded ? -180 : 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
            }
            .padding(10)
            .frame(minHeight: 36)
            .background(
                shape
                    .fill(backgroundColor)
                    .if(listOptions.background == .glass) { view in
                        view.background(.ultraThinMaterial, in: shape)
                    }
                    .shadow(color: .black.opacity(isExpanded ? 0.15 : 0.08),
                            radius: isExpanded ? 10 : 5, y: isExpanded ? 5 : 2)
            )
            .clipShape(shape)
            .customOutline(
                Color.accentColor.opacity(isExpanded ? 0.3 : 0),
                shape: shape,
                lineWidth: 3
            )
        }
        .buttonStyle(.plain)
        .focusable(true)
        .focusEffectDisabled()
        .disabled(isLoading)
        .accessibilityElement()
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text("\(accessibilityLabelText ?? placeholder) dropdown"))
        .accessibilityValue(Text(selectedDisplayInfo.title))
        .accessibilityHint(Text(isExpanded ? "Double-tap to close" : "Double-tap to open"))
        .zIndex(2)
    }
    
    private var buttonCorners: RectCorner {
        if isExpanded && listOptions.style == .connected {
            if dropdownPosition == .bottom {
                // When the dropdown is open below and connected, un-round the bottom corners of the button.
                return [.topLeft, .topRight]
            } else {
                // When the dropdown is open above and connected, un-round the top corners of the button.
                return [.bottomLeft, .bottomRight]
            }
        }
        return .allCorners
    }

    private func updateOverlayMetadata(with frame: CGRect) {
        dropdownManager.current = .init(
            id: componentId,
            options: internalOptions,
            selection: $selectedValues,
            isMultiSelect: isMultiSelect,
            anchor: frame,
            listOptions: listOptions,
            enableHaptics: enableHaptics,
            enableSound: enableSound,
            enableSearch: enableSearch,
            close: {
                isExpanded = false
                dropdownManager.current = nil
                if !isAbsolute { inlineGapHeight = 0 }
            },
            onPositionUpdate: { newPosition in
                self.dropdownPosition = newPosition
            },
            isAbsolute: self.isAbsolute,
            onHeightChange: { height in
                if !isAbsolute {
                    inlineGapHeight = height
                }
            }
        )
    }

    private var selectedDisplayInfo: (title: String, icon: MIconType?) {
        if selectedValues.isEmpty {
            return (placeholder, nil)
        }

        if isMultiSelect {
            let list = internalOptions.filter { selectedValues.contains($0.value) }.map { $0.title }
            return (list.joined(separator: ", "), nil)
        }

        if !isMultiSelect || selectedValues.count == 1 {
            if let value = selectedValues.first,
               let match = internalOptions.first(where: { $0.value == value }) {
                return (match.title, match.icon)
            }
        }

        let list = internalOptions.filter { selectedValues.contains($0.value) }.map { $0.title }
        return (list.joined(separator: ", "), nil)
    }
}


// MARK: - Dropdown List View (for re-use in overlay)
private struct DropdownContainerView: View {
    let metadata: DropdownMetadata
    var rootViewProxy: GeometryProxy?
    @Binding private var selection: Set<String>
    @FocusState private var isSearchFieldFocused: Bool
    @FocusState private var isListFocused: Bool
    
    // State for positioning and animation
    @State private var position: MDropDownPosition = .bottom
    @State private var isVisible = false
    @State private var dynamicMaxHeight: CGFloat = 250
    @State private var focusedOptionID: UUID? = nil
    @State private var searchText: String = ""
    @State private var contentHeight: CGFloat = 0
    
    init(metadata: DropdownMetadata, rootViewProxy: GeometryProxy? = nil) {
        self.metadata = metadata
        self.rootViewProxy = rootViewProxy
        self._selection = metadata.selection
    }

    private var dropdownCorners: RectCorner {
        if metadata.listOptions.style == .connected {
            if position == .bottom {
                // For a connected style below, only round the bottom corners.
                return [.bottomLeft, .bottomRight]
            } else {
                // For a connected style above, only round the top corners.
                return [.topLeft, .topRight]
            }
        }
        
        // For detached styles, round all corners.
        return .allCorners
    }
    
    private var filteredOptions: [MSelectOption] {
        if searchText.isEmpty {
            return metadata.options
        }
        return metadata.options.filter {
            $0.title.lowercased().contains(searchText.lowercased()) ||
            ($0.group?.lowercased().contains(searchText.lowercased()) ?? false)
        }
    }
    
    private var verticalOffset: CGFloat {
        let spacing: CGFloat = (metadata.listOptions.style == .connected) ? 0 : (metadata.isAbsolute ? 10 : 4)
        
        if position == .bottom {
            return metadata.anchor.maxY + spacing
        } else {
            return metadata.anchor.minY - spacing - dynamicMaxHeight
        }
    }
    
    private var dropdownBackgroundColor: AnyView {
        let shape = RoundedCornerShape(radius: 10, corners: dropdownCorners)
        switch metadata.listOptions.background {
        case .system:
            #if os(iOS)
            return AnyView(shape.fill(Color(UIColor.systemBackground)))
            #else
            return AnyView(shape.fill(Color(NSColor.windowBackgroundColor)))
            #endif
        case .light: return AnyView(shape.fill(Color.white))
        case .dark: return AnyView(shape.fill(Color.black))
        case .glass: return AnyView(shape.fill(.clear).background(.ultraThinMaterial, in: shape))
        }
    }
    
    private var selectedLabelsSummary: String {
        let titles = metadata.options.filter { selection.contains($0.value) }.map { $0.title }
        return titles.joined(separator: ", ")
    }

    private var listSecondaryTextColor: Color {
        if metadata.listOptions.background == .light { return .black.opacity(0.6) }
        return .secondary
    }
    
    var body: some View {
        let dropdownList = VStack(spacing: 0) {
            if metadata.enableSearch {
                searchBar
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
            }
            ScrollView {
                let groupedOptions = Dictionary(grouping: filteredOptions, by: { $0.group })
                let sortedGroupKeys = groupedOptions.keys.sorted {
                    switch ($0, $1) {
                    case (nil, nil): return false
                    case (nil, _): return true
                    case (_, nil): return false
                    case let (a?, b?): return a < b
                    }
                }
                
                VStack(spacing: 5) {
                    var animationStep = 0
                    ForEach(sortedGroupKeys, id: \.self) { groupKey in
                        if let group = groupKey {
                            groupHeaderRow(
                                title: group,
                                isVisible: isVisible,
                                animationDelay: Double(animationStep) * 0.05
                            )
                            let _ = { animationStep += 1 }()
                        }
                        
                        if let options = groupedOptions[groupKey] {
                            ForEach(options) { option in
                                optionRow(
                                    option,
                                    isVisible: isVisible,
                                    animationDelay: Double(animationStep) * 0.05
                                )
                                let _ = { animationStep += 1 }()
                            }
                        }
                    }
                }
                .padding(8)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { contentHeight = geo.size.height }
                            .onChange(of: geo.size.height) { _, newValue in
                                contentHeight = newValue
                            }
                    }
                )
                
                if filteredOptions.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        Text("No items found")
                            .font(.footnote)
                            .foregroundColor(listSecondaryTextColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(12)
                }
            }
            .frame(maxHeight: min(dynamicMaxHeight, max(contentHeight, 44)))
            
            if metadata.isMultiSelect && !selection.isEmpty {
                Divider().padding(.horizontal, 8)
                Text("(\(selection.count)) items selected... \(selectedLabelsSummary)")
                    .font(.caption)
                    .foregroundColor(listSecondaryTextColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(
            dropdownBackgroundColor
                .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
        )
        .contentShape(Rectangle())
        .transition(.opacity.combined(with: .move(edge: position == .top ? .bottom : .top)))
        .focusable()
        .focused($isListFocused)
        .onKeyPress(handleKeyPress)
        .focusEffectDisabled()
        .onChange(of: searchText) { _ in
            let options = filteredOptions
            if options.count == 1 {
                focusedOptionID = options.first?.id
            }
        }
        
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    metadata.close()
                }
            
            if let proxy = rootViewProxy {
            dropdownList
                    .frame(width: metadata.anchor.width)
                    .position(
                        x: metadata.anchor.midX,
                        y: {
                            let spacing: CGFloat = (metadata.listOptions.style == .connected) ? 0 : (metadata.isAbsolute ? 10 : 4)
                            let effectiveHeight = min(dynamicMaxHeight, max(contentHeight, 44))
                            // For connected + absolute + multi-select, always anchor below the picker.
                            if metadata.listOptions.style == .connected && metadata.isAbsolute && metadata.isMultiSelect {
                                return metadata.anchor.maxY + spacing + (effectiveHeight / 2)
                            }
                            if position == .bottom {
                                return metadata.anchor.maxY + spacing + (effectiveHeight / 2)
                            } else {
                                return metadata.anchor.minY - spacing - (effectiveHeight / 2)
                            }
                        }()
                    )
                    .background(GeometryReader { geo in
                        Color.clear.onChange(of: geo.size.height) { _, newHeight in
                            metadata.onHeightChange(newHeight)
                        }
                    })
                    .onAppear {
                        determineDropdownPosition(in: proxy)
                        withAnimation { isVisible = true }
                        // Default keyboard focus to the list so arrows work immediately
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.isListFocused = true
                        }
                    }
                    .onChange(of: selection) { _ in
                        // In connected + absolute + multi-select mode, never flip above
                        if metadata.listOptions.style == .connected && metadata.isAbsolute && metadata.isMultiSelect {
                            self.position = .bottom
                        }
                    }
            }
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            let iconColor: Color = (metadata.listOptions.background == .light) ? .blue : .secondary
            Image(systemName: "magnifyingglass")
                .foregroundColor(iconColor)
            
            TextField("Search...", text: $searchText)
                .textFieldStyle(.plain)
                .focused($isSearchFieldFocused)
                .foregroundColor(metadata.listOptions.background == .light ? .black : .primary)
                .tint(metadata.listOptions.background == .light ? .blue : .accentColor)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(iconColor)
                }
                .buttonStyle(.plain)
            }
            
            #if os(iOS)
            if !isSearchFieldFocused {
                Button(action: { isSearchFieldFocused = true }) {
                    Image(systemName: "keyboard")
                        .foregroundColor(iconColor)
                }
                .buttonStyle(.plain)
            }
            #endif
            
            if metadata.isMultiSelect && !selection.isEmpty {
                Button(action: {
                    withAnimation { selection.removeAll() }
                }) {
                    Text("Clear Selection")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    (metadata.listOptions.background == .light || metadata.listOptions.background == .system)
                    ? Color.gray.opacity(0.20) : Color.primary.opacity(0.08)
                )
                // .fill(.black)
        )
        .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
    }
    
    private func groupHeaderRow(title: String, isVisible: Bool, animationDelay: Double) -> some View {
        Text(title)
            .font(.caption)
            .foregroundColor(metadata.listOptions.background == .light ? .black.opacity(0.6) : .secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.top, 6)
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : -15)
            .animation(.spring(response: 0.2, dampingFraction: 0.6).delay(animationDelay), value: isVisible)
    }
    
    private func optionRow(_ option: MSelectOption, isVisible: Bool, animationDelay: Double) -> some View {
        let isSelected = selection.contains(option.value)
        let isFocused = focusedOptionID == option.id
        
        let textColor: Color = {
            if metadata.listOptions.background == .light { return .black }
            return .primary
        }()
        
        let secondaryTextColor: Color = {
            if metadata.listOptions.background == .light { return .black.opacity(0.6) }
            return .secondary
        }()
        
        return Button(action: {
            #if !os(macOS)
            if metadata.enableHaptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
            if metadata.enableSound { AudioServicesPlaySystemSound(1104) }
            #endif
            
            withAnimation(.easeInOut(duration: 0.15)) {
                if metadata.isMultiSelect {
                    if isSelected { selection.remove(option.value) }
                    else { selection.insert(option.value) }
                } else {
                    selection = [option.value]
                    metadata.close()
                }
            }
        }) {
            HStack(spacing: 8) {
                if let iconType = option.icon {
                    switch iconType {
                    case .image(let image):
                        image
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .cornerRadius(4)
                            .foregroundColor(option.isDisabled ? .secondary : .accentColor)
                    case .emoji(let string):
                        Text(string).font(.title3)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(isSelected ? .headline : .body)
                        .foregroundColor(option.isDisabled ? .secondary : textColor)
                    
                    if let description = option.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(secondaryTextColor)
                    }
                }
                
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.accentColor)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(rowBackgroundColor(for: option, isFocused: isFocused))
                    .scaleEffect(isFocused ? 1.03 : 1.0)
                    .shadow(color: isFocused ? .accentColor.opacity(0.25) : .clear, radius: isFocused ? 8 : 0)
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(option.isDisabled)
        .accessibilityElement()
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text(option.title))
        .accessibilityValue(Text(isSelected ? "Selected" : "Not selected"))
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : -15)
        .animation(.spring(response: 0.2, dampingFraction: 0.6).delay(animationDelay), value: isVisible)
        .onHover { hovering in
            #if os(macOS)
            withAnimation(.easeInOut(duration: 0.2)) {
                if hovering {
                    focusedOptionID = option.id
                }
            }
            #endif
        }
    }
    
    private func rowBackgroundColor(for option: MSelectOption, isFocused: Bool) -> Color {
        if option.isDisabled { return .gray.opacity(0.05) }
        if selection.contains(option.value) { return .accentColor.opacity(0.12) }
        #if os(macOS)
        if isFocused { return .gray.opacity(0.10) }
        #endif
        return .clear
    }
    
    private func determineDropdownPosition(in proxy: GeometryProxy) {
        let safeArea = proxy.safeAreaInsets
        let rootViewFrame = proxy.frame(in: .global)
        
        let spaceBelow = (rootViewFrame.height + rootViewFrame.origin.y - safeArea.bottom) - metadata.anchor.maxY
        let spaceAbove = metadata.anchor.minY - (rootViewFrame.origin.y + safeArea.top)

        let requiredHeight = metadata.listOptions.maxHeight
        // Prefer staying below the control for connected + absolute + multi-select,
        // even if there isn't room for the full maxHeight. Only flip to top if there
        // truly isn't enough space to show a minimal list.
        let minimalVisibleHeight: CGFloat = 44
        var newPosition: MDropDownPosition
        if metadata.listOptions.style == .connected && metadata.isAbsolute && metadata.isMultiSelect {
            // Always keep the list below the picker in this mode.
            newPosition = .bottom
            self.dynamicMaxHeight = min(requiredHeight, max(spaceBelow, minimalVisibleHeight))
        } else {
            if spaceBelow < requiredHeight && spaceAbove > requiredHeight {
                newPosition = .top
                self.dynamicMaxHeight = min(requiredHeight, spaceAbove)
            } else {
                newPosition = .bottom
                self.dynamicMaxHeight = min(requiredHeight, spaceBelow)
            }
        }
        
        self.position = newPosition
        // Use a slight delay to ensure the state change propagates after the initial view setup
        DispatchQueue.main.async {
            metadata.onPositionUpdate(newPosition)
        }
    }
    
    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .upArrow:
            moveFocus(direction: -1)
            return .handled
        case .downArrow:
            moveFocus(direction: 1)
            return .handled
        case .return:
            selectFocusedOption()
            return .handled
        case .space:
            selectFocusedOption()
            return .handled
        case .tab:
            // allow system focus traversal
            return .ignored
        case .escape:
            metadata.close()
            return .handled
        default:
            return .ignored
        }
    }

    private func moveFocus(direction: Int) {
        let options = filteredOptions
        guard !options.isEmpty else { return }
        
        let currentIndex = options.firstIndex(where: { $0.id == focusedOptionID })
        
        let newIndex: Int
        if let currentIndex {
            // Move from the current index, wrapping around
            newIndex = (currentIndex + direction + options.count) % options.count
        } else {
            // Nothing is focused, so focus the first or last item depending on direction
            newIndex = direction > 0 ? 0 : options.count - 1
        }
        
        focusedOptionID = options[newIndex].id
    }

    private func selectFocusedOption() {
        guard let focusedID = focusedOptionID,
              let option = metadata.options.first(where: { $0.id == focusedID }),
              !option.isDisabled else { return }

        // Use the same selection logic as the button action
        #if !os(macOS)
        if metadata.enableHaptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        if metadata.enableSound { AudioServicesPlaySystemSound(1104) }
        #endif
        
        withAnimation(.easeInOut(duration: 0.15)) {
            if metadata.isMultiSelect {
                if selection.contains(option.value) {
                    selection.remove(option.value)
                } else {
                    selection.insert(option.value)
                }
            } else {
                selection = [option.value]
                metadata.close()
            }
        }
    }
}


#if os(iOS)
import CoreMotion
#endif

// MARK: - Selectable 3D Glass Card
struct GlassCard: View {
    let id: Int
    let title: String
    @Binding var selectedIDs: Set<Int>
#if os(iOS)
    @ObservedObject private var motion = MotionManager()
#endif
    @State private var isHovered = false
    
    var isSelected: Bool { selectedIDs.contains(id) }
    
    var body: some View {
#if os(iOS)
        let tiltX = CGFloat(motion.roll) * 10
        let tiltY = CGFloat(motion.pitch) * 10
#else
        let tiltX: CGFloat = 0
        let tiltY: CGFloat = 0
#endif
        let shape = RoundedRectangle(cornerRadius: 25)
        
        ZStack {
            // Background "glass" layer
            (
                Group {
                    if #available(iOS 26.0, macOS 26.0, *) {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .background(.ultraThinMaterial)
                            .clipShape(shape)
                    } else {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .background(.ultraThinMaterial)
                            .clipShape(shape)
                    }
                }
            )
            .customOutline(
                LinearGradient(
                    colors: [.white.opacity(0.5), .white.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                shape: shape,
                lineWidth: isSelected || isHovered ? 2.5 : 1
            )
            .shadow(color: .black.opacity(isHovered || isSelected ? 0.25 : 0.1),
                    radius: isHovered || isSelected ? 20 : 5)
            
            // Title Text
            Text(title)
                .font(.headline)
                .foregroundStyle(isSelected ? Color.blue : .white)
                .padding()
        }
        .frame(width: 200, height: 120)
        .rotation3DEffect(
            .degrees(isHovered ? Double(tiltX) / 2 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.4
        )
        .rotation3DEffect(
            .degrees(isHovered ? Double(-tiltY) / 2 : 0),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.4
        )
        .scaleEffect(isHovered || isSelected ? 1.06 : 1.0)
        .animation(.easeInOut(duration: 0.25), value: isHovered)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        .onTapGesture {
            if selectedIDs.contains(id) {
                selectedIDs.remove(id)
            } else {
                selectedIDs.insert(id)
            }
#if os(iOS)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
#endif
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .focusable(true)
        .focusEffectDisabled()
#if os(visionOS)
        .onFocusChange { focused in
            isHovered = focused
        }
#endif
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(title) card")
    }
}

#if os(iOS)
final class MotionManager: ObservableObject {
    private let manager = CMMotionManager()
    @Published var roll: Double = 0
    @Published var pitch: Double = 0
    @Published var yaw: Double = 0

    init() {
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        if manager.isDeviceMotionAvailable {
            manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
                guard let s = self, let motion = motion else { return }
                s.roll = motion.attitude.roll
                s.pitch = motion.attitude.pitch
                s.yaw = motion.attitude.yaw
            }
        }
    }

    deinit {
        manager.stopDeviceMotionUpdates()
    }
}
#endif

private struct InlineDropdownContainerView: View {
    let options: [MSelectOption]
    @Binding var selection: Set<String>
    let isMultiSelect: Bool
    let listOptions: MListOptions
    let enableHaptics: Bool
    let enableSound: Bool
    let enableSearch: Bool
    let isVisible: Bool
    let onClose: () -> Void
    
    @State private var searchText: String = ""
    @State private var contentHeightInline: CGFloat = 0
    
    private var textColor: Color {
        switch listOptions.background {
        case .light: return Color.black.opacity(0.8)
        case .dark: return .white
        default: return .primary
        }
    }
    private var secondaryTextColor: Color {
        switch listOptions.background {
        case .light: return .black.opacity(0.6)
        case .dark: return .white.opacity(0.6)
        default: return .secondary
        }
    }
    private var inlineCorners: RectCorner {
        listOptions.style == .connected ? [.bottomLeft, .bottomRight] : .allCorners
    }
    private var inlineBackgroundView: AnyView {
        let shape = RoundedCornerShape(radius: 10, corners: inlineCorners)
        switch listOptions.background {
        case .system:
            #if os(iOS)
            return AnyView(shape.fill(Color(UIColor.secondarySystemBackground)).opacity(0.8))
            #else
            return AnyView(shape.fill(Color(NSColor.windowBackgroundColor)).opacity(0.8))
            #endif
        case .light:
            return AnyView(shape.fill(Color.white).opacity(0.8))
        case .dark:
            return AnyView(shape.fill(Color.black).opacity(0.8))
        case .glass:
            return AnyView(shape.fill(.clear).background(.ultraThinMaterial, in: shape).opacity(0.9))
        }
    }
    private var filteredOptions: [MSelectOption] {
        if searchText.isEmpty { return options }
        return options.filter {
            $0.title.lowercased().contains(searchText.lowercased()) ||
            ($0.group?.lowercased().contains(searchText.lowercased()) ?? false)
        }
    }
    private var grouped: [String?: [MSelectOption]] { Dictionary(grouping: filteredOptions, by: { $0.group }) }
    private var sortedKeys: [String?] { grouped.keys.sorted { (a, b) in
        switch (a, b) {
        case (nil, nil): return false
        case (nil, _): return true
        case (_, nil): return false
        case let (a?, b?): return a < b
        }
    } }
    private var selectedLabelsSummary: String {
        let titles = options.filter { selection.contains($0.value) }.map { $0.title }
        return titles.joined(separator: ", ")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if enableSearch {
                inlineSearchBar
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
            }
            ScrollView {
                VStack(spacing: 5) {
                    ForEach(sortedKeys, id: \.self) { key in
                        if let group = key {
                            Text(group)
                                .font(.caption)
                                .foregroundColor(secondaryTextColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 6)
                                .padding(.top, 6)
                                .opacity(isVisible ? 1 : 0)
                                .offset(y: isVisible ? 0 : -15)
                                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isVisible)
                        }
                        ForEach(grouped[key] ?? []) { option in
                            inlineOptionRow(option)
                                .opacity(isVisible ? 1 : 0)
                                .offset(y: isVisible ? 0 : -15)
                                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isVisible)
                        }
                    }
                }
                .padding(8)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { contentHeightInline = geo.size.height }
                            .onChange(of: geo.size.height) { _, newVal in contentHeightInline = newVal }
                    }
                )
                if filteredOptions.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.secondary)
                        Text("No matching results")
                            .font(.footnote)
                            .foregroundColor(secondaryTextColor)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 90)
                }
            }
            .frame(maxHeight: listOptions.maxHeight)
            
            if isMultiSelect && !selection.isEmpty {
                Divider().padding(.horizontal, 8)
                Text("(\(selection.count)) items selected... \(selectedLabelsSummary)")
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(inlineBackgroundView)
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
        .frame(
            height: {
                if !isVisible { return 0 }
                let emptyMin: CGFloat = 180
                let effectiveContent = contentHeightInline + (filteredOptions.isEmpty ? emptyMin : 0)
                return min(listOptions.maxHeight, max(effectiveContent, filteredOptions.isEmpty ? emptyMin : 0))
            }(),
            alignment: .top
        )
        .clipped()
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isVisible)
    }
    
    private var inlineSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(.blue)
            TextField("Search...", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundColor(listOptions.background == .light ? Color.black.opacity(0.8) : .primary)
                .tint(.blue)
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.blue)
                }.buttonStyle(.plain)
            }
            if isMultiSelect && !selection.isEmpty {
                Button(action: { withAnimation { selection.removeAll() } }) {
                    Text("Clear Selection").font(.caption).foregroundColor(.accentColor)
                }.buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    (listOptions.background == .light || listOptions.background == .system) ? Color.gray.opacity(0.08) : Color.primary.opacity(0.05)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
    }
    
    private func inlineOptionRow(_ option: MSelectOption) -> some View {
        let isSelected = selection.contains(option.value)
        return Button(action: {
            #if !os(macOS)
            if enableHaptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
            if enableSound { AudioServicesPlaySystemSound(1104) }
            #endif
            withAnimation(.easeInOut(duration: 0.15)) {
                if isMultiSelect {
                    if isSelected { selection.remove(option.value) } else { selection.insert(option.value) }
                } else {
                    selection = [option.value]
                    onClose()
                }
            }
        }) {
            HStack(spacing: 8) {
                if let iconType = option.icon {
                    switch iconType {
                    case .image(let image):
                        image.renderingMode(.template).resizable().scaledToFit().frame(width: 18, height: 18).cornerRadius(4).foregroundColor(isSelected ? .accentColor : textColor)
                    case .emoji(let string):
                        Text(string).font(.title3)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title).font(isSelected ? .headline : .body).foregroundColor(option.isDisabled ? .secondary : textColor)
                    if let description = option.description {
                        Text(description).font(.caption).foregroundColor(secondaryTextColor)
                    }
                }
                Spacer()
                if isSelected { Image(systemName: "checkmark.circle.fill").foregroundColor(.accentColor) }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10).fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(option.isDisabled)
        .focusEffectDisabled()
    }
}
