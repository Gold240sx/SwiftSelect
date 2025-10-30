//
//  SelectPicker.swift
//  SwiftSelect
//
//  Created by Michael Martell on 10/29/25.
//

import SwiftUI

#if os(macOS)
import AppKit
#endif

#if os(macOS)
import AppKit
#else
import UIKit
  import AVFoundation  // 👇 for sound playback (optional)
#endif


// swiftSelect-version: 0.1.0

@available(iOS 13.0, macOS 14.0, tvOS 13.0, watchOS 6.0, *)
public struct SwiftSelect: View {

  // MARK: - Label Configuration
    public struct LabelStyleConfig {
        public var font: Font
        public var fontWeight: Font.Weight
        public var color: Color
        public var sublabelFont: Font
        public var sublabelColor: Color
        public var asteriskColor: Color

        public init(
            font: Font = .title3,
            fontWeight: Font.Weight = .bold,
            color: Color = .primary,
            sublabelFont: Font = .footnote,
            sublabelColor: Color = Color.primary.opacity(0.7),
            asteriskColor: Color = .red
        ) {
            self.font = font
            self.fontWeight = fontWeight
            self.color = color
            self.sublabelFont = sublabelFont
            self.sublabelColor = sublabelColor
            self.asteriskColor = asteriskColor
        }
    }

    public struct LabelOptions {
        public struct InfoOptions {
            public var text: String
            public var icon: String?

            public init(text: String, icon: String? = nil) {
                self.text = text
                self.icon = icon
            }
        }
    public var label: String?
        public var sublabel: String?
        public var isRequired: Bool
        public var showsInfoIcon: Bool
        public var infoAction: (() -> Void)?
        public var tooltipTitle: String?
        public var tooltipDescription: String?
        public var infoOptions: InfoOptions?
        public var style: LabelStyleConfig

        public init(
      label: String? = nil,
            sublabel: String? = nil,
            isRequired: Bool = false,
            showsInfoIcon: Bool = false,
            infoAction: (() -> Void)? = nil,
            tooltipTitle: String? = nil,
            tooltipDescription: String? = nil,
            infoOptions: InfoOptions? = nil,
            style: LabelStyleConfig = LabelStyleConfig()
        ) {
      self.label = label
            self.sublabel = sublabel
            self.isRequired = isRequired
            self.showsInfoIcon = showsInfoIcon
            self.infoAction = infoAction
            self.tooltipTitle = tooltipTitle
            self.tooltipDescription = tooltipDescription
            self.infoOptions = infoOptions
            self.style = style
            #if DEBUG
            if showsInfoIcon && infoAction != nil {
          precondition(
            tooltipDescription != nil && !(tooltipDescription ?? "").isEmpty,
            "LabelOptions.tooltipDescription is required when infoAction is provided.")
            }
            #endif
        }
    }

  public var errorMessage: String?

  // Primary props

  public var labelOptions: LabelOptions
    
  // MARK: - Selector Configuration

  public struct SelectorOptions {
    public var placeholder: String
    public var enableHaptics: Bool
    public var enableSoundFeedback: Bool
    public var enableSearch: Bool
    public var isAbsolute: Bool
    public var isMultiSelect: Bool
    // Multi-select helper: Add an "All …" row at top
    public var checkAll: Bool
    public var checkAllTitleOverride: String?

    public init(
      placeholder: String = "Select…",
      enableHaptics: Bool = false,
      enableSoundFeedback: Bool = false,
      enableSearch: Bool = false,
      isAbsolute: Bool = false,
      isMultiSelect: Bool = false,
      checkAll: Bool = false,
      checkAllTitleOverride: String? = nil
    ) {
      self.placeholder = placeholder
      self.enableHaptics = enableHaptics
      self.enableSoundFeedback = enableSoundFeedback
      self.enableSearch = enableSearch
      self.isAbsolute = isAbsolute
      self.isMultiSelect = isMultiSelect
      self.checkAll = checkAll
      self.checkAllTitleOverride = checkAllTitleOverride
    }
  }

  public var selectorOptions: SelectorOptions = SelectorOptions()
  @Binding public var stateName: Set<String>
  @State private var isExpanded = false
  @State private var internalOptions: [SelectOption]
  @State private var inlineGapHeight: CGFloat = 0
  @State private var pickerHeight: CGFloat = 36
  @State private var pickerFrame: CGRect = .zero
  // compatibility with async data
  @State private var isLoading: Bool = false
  private let optionsLoader: (() async -> [SelectOption])?
  private let componentId = UUID()
  // Throttle overlay updates to avoid multiple mutations in a single frame
  @State private var overlayUpdateTask: Task<Void, Never>? = nil
  #if os(macOS)
  @State private var windowResizeObserver: NSObjectProtocol?
  #endif
  
  @Environment(\.dropdownManager) private var dropdownManager
  @Environment(\.dropdownSettings) private var dropdownSettings

  public init(
    options: [SelectOption] = [],
    optionsLoader: (() async -> [SelectOption])? = nil,
    selectorOptions: SelectorOptions = SelectorOptions(),
        labelOptions: LabelOptions = LabelOptions(),
        errorMessage: String? = nil,
    isLoading: Bool = false,
        stateName: Binding<Set<String>> = .constant([])
    
  ) {
    self._internalOptions = State(initialValue: options)
    self.optionsLoader = optionsLoader
    self.selectorOptions = selectorOptions
        self.labelOptions = labelOptions
        self.errorMessage = errorMessage
    self._isLoading = State(initialValue: isLoading)
        self._stateName = stateName
    }
  

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
      // Resolve effective style/background once to avoid scattering logic
      let effectiveStyle: ListOptions.Style = {
        switch dropdownSettings.style ?? .connected {
        case .connected: return .connected
        case .detached: return .detached
        }
      }()
      let effectiveBackground: ListOptions.Background = {
        switch dropdownSettings.background ?? .system {
        case .system: return .system
        case .light: return .light
        case .dark: return .dark
        case .glass: return .glass
        }
      }()
      let pickerRoundedCorners: RectCorner = {
        // Always round all corners when not expanded
        guard isExpanded else { return .allCorners }
        // When expanded, only round top corners for absolute + connected style
        if selectorOptions.isAbsolute && (effectiveStyle == .connected) {
          return [.topLeft, .topRight]
        }
        return .allCorners
      }()
      let currentValueText: String = {
        if stateName.isEmpty { return selectorOptions.placeholder }
        if stateName.count == 1, let only = stateName.first,
           let match = internalOptions.first(where: { $0.value == only }) {
          return match.title
        }
        let titles = internalOptions.filter { stateName.contains($0.value) }.map { $0.title }
        return titles.isEmpty ? selectorOptions.placeholder : titles.joined(separator: ", ")
      }()
      // Compute optional "All …" title for multi-select
      let checkAllTitle: String? = {
        let isMulti = selectorOptions.isMultiSelect || dropdownSettings.isMultiSelect
        guard isMulti && selectorOptions.checkAll else { return nil }
        if let override = selectorOptions.checkAllTitleOverride, !override.isEmpty { return override }
        let base = labelOptions.label ?? "Options"
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let plural: String = {
          if trimmed.lowercased().hasSuffix("s") { return trimmed }
          return trimmed + "s"
        }()
        return "All \(plural)"
      }()
      SwiftSelectLabelHeader(labelOptions: labelOptions)
      // Debug: show sharp-corner conditions when in absolute mode

        HStack(spacing: 8) {
          HStack(spacing: 4) {
            Image(systemName: selectorOptions.isAbsolute ? "checkmark.circle.fill" : "xmark.circle")
            Text("Absolute")
          }
          HStack(spacing: 4) {
            Image(systemName: (effectiveStyle == .connected) ? "checkmark.circle.fill" : "xmark.circle")
            Text("Connected")
          }
          HStack(spacing: 4) {
            Image(systemName: isExpanded ? "checkmark.circle.fill" : "xmark.circle")
            Text("Expanded")
          }
          Spacer(minLength: 8)
          Text(currentValueText)
            .lineLimit(1)
            .truncationMode(.tail)
        }
        .font(.caption2)
        .foregroundColor(.secondary)
        .padding(.bottom, 4)
  

      ClearOverlay(
        isAbsolute: selectorOptions.isAbsolute,
        isExpanded: isExpanded,
        inlineGapHeight: inlineGapHeight,
        isConnectedStyle: false,
        content: {
          ZStack(alignment: .topLeading) {
            // Picker always above list
            SelectPicker(
              isExpanded: $isExpanded,
              isLoading: isLoading,
              stateName: stateName,
              internalOptions: internalOptions,
              placeholder: selectorOptions.placeholder,
              roundedCorners: pickerRoundedCorners,
              isMultiSelect: selectorOptions.isMultiSelect || dropdownSettings.isMultiSelect,
              onClearSelection: (selectorOptions.isMultiSelect || dropdownSettings.isMultiSelect) ? {
                stateName.removeAll()
              } : nil
            )
            .background(
              GeometryReader { geo in
                Color.clear
                  .onAppear {
                    pickerHeight = geo.size.height
                    pickerFrame = geo.frame(in: .global)
                  }
                  .onChange(of: geo.size.height) { _, newValue in pickerHeight = newValue }
                  .onChange(of: geo.frame(in: .global)) { _, newValue in pickerFrame = newValue }
              }
            )
            .zIndex(1)

            if isExpanded && !selectorOptions.isAbsolute {
              // Inline placement settings
              let enableSearchValue = selectorOptions.enableSearch || dropdownSettings.enableSearch
              let isMultiSelectValue = selectorOptions.isMultiSelect || dropdownSettings.isMultiSelect
              let layout: InlineLayout = InlineLayout.make(
                for: effectiveStyle,
                pickerHeight: pickerHeight,
                enableSearch: enableSearchValue,
                isMultiSelect: isMultiSelectValue
              )
              OptionsListView(
                metadata: DropdownMetadata(
                  id: componentId,
                  options: internalOptions,
                  selection: $stateName,
                  isMultiSelect: selectorOptions.isMultiSelect || dropdownSettings.isMultiSelect,
                  anchor: CGRect(x: 0, y: 0, width: 0, height: 0),
                  listOptions: ListOptions(
                    maxHeight: dropdownSettings.maxHeight ?? 250,
                    style: effectiveStyle,
                    background: effectiveBackground
                  ),
                  enableHaptics: selectorOptions.enableHaptics,
                  enableSound: selectorOptions.enableSoundFeedback,
                  enableSearch: selectorOptions.enableSearch || dropdownSettings.enableSearch,
                  close: { withAnimation { isExpanded = false } },
                  isAbsolute: false,
                  onHeightChange: { _ in inlineGapHeight = layout.inlineGap },
                  checkAllTitle: checkAllTitle
                ),
                rootViewProxy: nil
              )
              .modifier(InlineListPositionModifier(offsetY: layout.offsetY))
              .zIndex(0)
            }
          }
        }
      )
      // Keep absolute list in top overlay rather than inline
      .onChange(of: isExpanded) { _, _ in scheduleOverlayUpdate() }
      .onChange(of: pickerFrame) { _, _ in scheduleOverlayUpdate() }

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .padding(.leading, 10)
                    .offset(y: (isExpanded && !selectorOptions.isAbsolute && !(selectorOptions.enableSearch || dropdownSettings.enableSearch)) ? 20 : 0)
            }
        }
        .padding(10)
    .task {
      if let loader = optionsLoader, isLoading {
        let loaded = await loader()
        await MainActor.run {
          self.internalOptions = loaded
          self.isLoading = false
        }
      }
    }
    #if os(macOS)
    .onAppear {
      setupWindowResizeObserver()
    }
    .onDisappear {
      removeWindowResizeObserver()
    }
    .onChange(of: isExpanded) { _, _ in
      // Reset observer when expanded state changes
      removeWindowResizeObserver()
      if isExpanded {
        setupWindowResizeObserver()
      }
    }
    #endif
  }
}

// MARK: - Overlay wiring for absolute mode
extension SwiftSelect {
  @MainActor
  private func scheduleOverlayUpdate() {
    overlayUpdateTask?.cancel()
    overlayUpdateTask = Task { @MainActor in
      // Yield to next runloop tick to coalesce rapid geometry changes
      try? await Task.sleep(nanoseconds: 1_000_000)
      updateOverlayMetadata()
    }
  }
  private func updateOverlayMetadata() {
    guard selectorOptions.isAbsolute else { dropdownManager.current = nil; return }
    if isExpanded == false { dropdownManager.current = nil; return }

    let style: ListOptions.Style = {
      switch dropdownSettings.style ?? .connected {
      case .connected: return .connected
      case .detached: return .detached
      }
    }()
    let bg: ListOptions.Background = {
      switch dropdownSettings.background ?? .system {
      case .system: return .system
      case .light: return .light
      case .dark: return .dark
      case .glass: return .glass
      }
    }()

    // compute checkAll title here as well
    let checkAllTitle: String? = {
      let isMulti = selectorOptions.isMultiSelect || dropdownSettings.isMultiSelect
      guard isMulti && selectorOptions.checkAll else { return nil }
      if let override = selectorOptions.checkAllTitleOverride, !override.isEmpty { return override }
      let base = labelOptions.label ?? "Options"
      let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
      let plural: String = trimmed.lowercased().hasSuffix("s") ? trimmed : (trimmed + "s")
      return "All \(plural)"
    }()

    dropdownManager.current = DropdownMetadata(
      id: componentId,
      options: internalOptions,
      selection: $stateName,
      isMultiSelect: selectorOptions.isMultiSelect || dropdownSettings.isMultiSelect,
      anchor: pickerFrame,
      listOptions: ListOptions(
        maxHeight: dropdownSettings.maxHeight ?? 250,
        style: style,
        background: bg
      ),
      enableHaptics: selectorOptions.enableHaptics,
      enableSound: selectorOptions.enableSoundFeedback,
      enableSearch: selectorOptions.enableSearch || dropdownSettings.enableSearch,
      close: { withAnimation { isExpanded = false } },
      isAbsolute: true,
      onHeightChange: { _ in },
      checkAllTitle: checkAllTitle
    )
  }
  
  #if os(macOS)
  private func setupWindowResizeObserver() {
    guard windowResizeObserver == nil else { return }
    
    // Capture the binding's projected value to access the binding
    let expandedBinding = _isExpanded
    
    windowResizeObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.didResizeNotification,
      object: nil,
      queue: .main
    ) { _ in
      Task { @MainActor in
        guard expandedBinding.wrappedValue else { return }
        // Close dropdown when window resizes (works for both inline and absolute)
        withAnimation { expandedBinding.wrappedValue = false }
      }
    }
  }
  
  private func removeWindowResizeObserver() {
    if let observer = windowResizeObserver {
      NotificationCenter.default.removeObserver(observer)
      windowResizeObserver = nil
    }
  }
  #endif
}

fileprivate struct InlineListPositionModifier: ViewModifier {
  let offsetY: CGFloat
  func body(content: Content) -> some View { content.offset(y: offsetY) }
}

fileprivate struct InlineLayout {
  let offsetY: CGFloat      // visual offset to place list under picker
  let inlineGap: CGFloat    // spacer height below ZStack to make room for painted list

  static func make(for style: ListOptions.Style, pickerHeight: CGFloat, enableSearch: Bool = false, isMultiSelect: Bool = false) -> InlineLayout {
    switch style {
    case .connected:
      // Visual: list positioned below picker
      // When search is enabled, there's a search bar (~52pt), so offset is 10
      // When search is disabled, need to adjust down by ~30pt to account for missing search bar
      let baseOffset: CGFloat = 10
      let searchAdjustment: CGFloat = enableSearch ? 0 : 20
      return InlineLayout(offsetY: baseOffset + searchAdjustment, inlineGap: 10)
    case .detached:
      // Visual: list 6 below bottom of picker. Spacer: ~pickerHeight + 6
      // 10 gap here matches 6 gap on the absolute side.
      return InlineLayout(offsetY: pickerHeight + 10, inlineGap: pickerHeight + 10)
    }
  }
}

// Able to view even though this is a package
#if DEBUG && canImport(SwiftUI)
@available(iOS 13.0, macOS 12.0, tvOS 13.0, watchOS 6.0, *)
struct SwiftSelect_Previews: PreviewProvider {
    static let dinnerOptions: [SelectOption] = [
      .init(
        "Vegan Cheeseburger with Extra Pickles", value: "veganCheeseburger",
        icon: Image(systemName: "leaf.fill"),
        description: "A healthy and delicious plant-based option.", group: "Vegan"),
      .init(
        "Ice Cream", value: "iceCream", icon: Image(systemName: "cloud.fill"), group: "Dairy Option"
      ),
      .init(
        "Mashed Potatoes", value: "mashedPotatoes", icon: Image(systemName: "cloud.fill"),
        group: "Parve"),
        .init("Beef Stroganoff", value: "stroganoff", group: "Fleishig"),
      .init("Candy", value: "candy"),
    ]

    static var previews: some View {
        VStack(alignment: .leading, spacing: 16) {
            SwiftSelect(
                options: dinnerOptions,
          selectorOptions: .init(placeholder: "Select..."),
                labelOptions: .init(
            label: "Select...",
                    sublabel: "Choose your favorite",
                    isRequired: true,
                    showsInfoIcon: true,
                    infoAction: { print("info tapped") },
            style: .init(
              font: .headline, fontWeight: .bold, color: .primary, sublabelFont: .footnote,
              sublabelColor: .secondary, asteriskColor: .red)
                )
            )

            SwiftSelect(
                options: dinnerOptions,
          selectorOptions: .init(placeholder: "No label variant")
            )
        }
    }
}
#endif  // DEBUG && canImport(SwiftUI)
