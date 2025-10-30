
//
//  ContentView.swift
//  SwiftSelect
//
//  Created by Michael Martell on 10/23/25.
//

import SwiftUI

// MARK: - Internal Overlay System
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

struct DropdownMetadata {
    let id: UUID
    let options: [SelectOption]
    let selection: Binding<Set<String>>
    let isMultiSelect: Bool
    let anchor: CGRect
    let listOptions: ListOptions
    let enableHaptics: Bool
    let enableSound: Bool
    let enableSearch: Bool
    let close: () -> Void
    let onPositionUpdate: (DropDownPosition) -> Void
    let isAbsolute: Bool
    let onHeightChange: (CGFloat) -> Void
}

public struct DropdownOverlay: ViewModifier {
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

public extension View {
    func dropdownOverlay() -> some View { self.modifier(DropdownOverlay()) }
}

// MARK: - SwiftSelect Public View
public struct SwiftSelect: View {
    public var placeholder: String // ✅
    public var isMultiSelect: Bool // ✅
    public var isAbsolute: Bool // ✅
    public var listOptions: ListOptions // ✅
    public var enableHaptics: Bool // ✅
    public var enableSound: Bool // ✅
    public var enableSearch: Bool // ✅
    public var accessibilityLabelText: String? // 🎾
    @Binding public var selectedValues: Set<String> // ✅

    @State private var internalOptions: [SelectOption]
    @State private var isLoading: Bool
    private let optionsLoader: (() async -> [SelectOption])?

    @State private var isExpanded = false
    @State private var buttonFrame: CGRect = .zero
    @State private var dropdownPosition: DropDownPosition = .bottom
    @Environment(\.dropdownManager) private var dropdownManager
    @Environment(\.dropdownSettings) private var globalSettings
    private let componentId = UUID()
    @State private var inlineGapHeight: CGFloat = 0

    public init(
        options: [SelectOption],
        placeholder: String = "Select...",
        isMultiSelect: Bool = true,
        isAbsolute: Bool = false,
        listOptions: ListOptions = .init(),
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

    public init(
        placeholder: String = "Select...",
        optionsLoader: @escaping () async -> [SelectOption],
        isMultiSelect: Bool = true,
        isAbsolute: Bool = false,
        listOptions: ListOptions = .init(),
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
        VStack(spacing: 0) {
            buttonView
            if isExpanded && !isAbsolute {
                Color.clear.frame(height: inlineGapHeight + (listOptions.style == .connected ? 0 : 4))
            }
        }
        .background(GeometryReader { geo in
            let newFrame = geo.frame(in: .global)
            Color.clear.onAppear { self.buttonFrame = newFrame }
                .onChange(of: newFrame) { _, frame in
                    self.buttonFrame = frame
                    if isExpanded && dropdownManager.current?.id == componentId { updateOverlayMetadata(with: frame) }
                }
        })
        .task {
            if let loader = optionsLoader, isLoading {
                self.internalOptions = await loader()
                self.isLoading = false
            }
        }
    }

    private var textColor: Color {
        switch listOptions.background {
        case .light: return .black
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
            case .glass: return .clear
            }
        }()

        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded.toggle()
                if isExpanded { updateOverlayMetadata(with: buttonFrame) }
                else { dropdownManager.current = nil }
            }
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().frame(width: 18, height: 18)
                    Text("Loading...").foregroundColor(.secondary)
                } else {
                    if let iconType = selectedDisplayInfo.icon {
                        switch iconType {
                        case .image(let image):
                            image.resizable().scaledToFit().frame(width: 18, height: 18).cornerRadius(4).foregroundColor(textColor)
                        case .emoji(let string):
                            Text(string).font(.title3)
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
                    .if(listOptions.background == .glass) { view in view.background(.ultraThinMaterial, in: shape) }
                    .shadow(color: .black.opacity(isExpanded ? 0.15 : 0.08), radius: isExpanded ? 10 : 5, y: isExpanded ? 5 : 2)
            )
            .clipShape(shape)
            .customOutline(Color.accentColor.opacity(isExpanded ? 0.3 : 0), shape: shape, lineWidth: 3)
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
    }

    private var buttonCorners: RectCorner {
        if isExpanded && listOptions.style == .connected {
            return dropdownPosition == .bottom ? [.topLeft, .topRight] : [.bottomLeft, .bottomRight]
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
            onPositionUpdate: { newPosition in self.dropdownPosition = newPosition },
            isAbsolute: self.isAbsolute,
            onHeightChange: { height in if !isAbsolute { inlineGapHeight = height } }
        )
    }

    private var selectedDisplayInfo: (title: String, icon: MIconType?) {
        if selectedValues.isEmpty { return (placeholder, nil) }
        if isMultiSelect {
            let list = internalOptions.filter { selectedValues.contains($0.value) }.map { $0.title }
            return (list.joined(separator: ", "), nil)
        }
        if !isMultiSelect || selectedValues.count == 1 {
            if let value = selectedValues.first, let match = internalOptions.first(where: { $0.value == value }) {
                return (match.title, match.icon)
            }
        }
        let list = internalOptions.filter { selectedValues.contains($0.value) }.map { $0.title }
        return (list.joined(separator: ", "), nil)
    }
}

// Backwards-compatible aliases
public typealias SwiftSelectDropdown = SwiftSelect
public typealias MultiSelectDropdown = SwiftSelect
