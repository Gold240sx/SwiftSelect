//
//  SelectPicker.swift
//  SwiftSelect
//
//  Created by Michael Martell on 10/29/25.
//

import SwiftUI
#if canImport(SDWebImageSwiftUI)
import SDWebImageSwiftUI
#endif
#if canImport(SDWebImageSVGCoder)
import SDWebImageSVGCoder
#endif

#if os(macOS)
  import AppKit
#else
  import UIKit
  import AVFoundation  // 👇 for sound playback (optional)
#endif

// MARK: - Positioning Configuration
/// Configuration for dropdown positioning based on mode and style
/// ⚠️ IMPORTANT: These values are carefully tuned for perfect vertical positioning.
/// DO NOT modify these values without thorough testing across all modes (absolute/inline × connected/detached).
/// 
/// Note: Position is calculated from the TOP edge of the dropdown:
///   topPosition = pickerBottom + spacing + verticalOffset
///   centerPosition = topPosition + (fullDropdownHeight / 2)  // .position() centers the view
private struct DropdownPositionConfig {
    /// Spacing between picker bottom and dropdown top edge
    let spacing: CGFloat
    /// Vertical offset adjustment (positive = down, negative = up)
    let verticalOffset: CGFloat
    /// Padding applied to the container
    let containerPadding: CGFloat
    
    static let absoluteConnected = DropdownPositionConfig(
        spacing: 0,
        verticalOffset: -29,  // Adjust to eliminate gap from shadow/padding (29pt upward)
        containerPadding: 0
    )
    
    static let absoluteDetached = DropdownPositionConfig(
        spacing: 6,
        verticalOffset: -25,  // Raise by 20pt
        containerPadding: 0
    )
    
    static let inlineConnected = DropdownPositionConfig(
        spacing: 0,
        verticalOffset: 0,
        containerPadding: 0
    )
    
    static let inlineDetached = DropdownPositionConfig(
        spacing: 10,  // Note: Not used for inline mode (handled by InlineLayout), kept for consistency
        verticalOffset: 0,
        containerPadding: 0
    )
    
    static func config(isAbsolute: Bool, style: ListOptions.Style) -> DropdownPositionConfig {
        switch (isAbsolute, style) {
        case (true, .connected): return .absoluteConnected
        case (true, .detached): return .absoluteDetached
        case (false, .connected): return .inlineConnected
        case (false, .detached): return .inlineDetached
        }
    }
}

struct OptionsListView: View {
    let metadata: DropdownMetadata
    var rootViewProxy: GeometryProxy?
    @Binding private var selection: Set<String>
    @FocusState private var isSearchFieldFocused: Bool
    @FocusState private var isListFocused: Bool
    @Environment(\.dropdownSettings) private var globalSettings
    @Environment(\.colorScheme) private var colorScheme

    @State private var isVisible = false
    @State private var dynamicMaxHeight: CGFloat = 250
    @State private var focusedOptionID: UUID? = nil
    @State private var searchText: String = ""
    @State private var contentHeight: CGFloat = 0
    @State private var fullDropdownHeight: CGFloat = 0

    #if canImport(SDWebImageSVGCoder)
    private static let registerSVGCoder: Void = {
        let coder = SDImageSVGCoder.shared
        SDImageCodersManager.shared.addCoder(coder)
    }()
    #endif

    init(metadata: DropdownMetadata, rootViewProxy: GeometryProxy? = nil) {
        self.metadata = metadata
        self.rootViewProxy = rootViewProxy
        self._selection = metadata.selection
        #if canImport(SDWebImageSVGCoder)
        _ = OptionsListView.registerSVGCoder
        #endif
    }

    private var dropdownCorners: RectCorner {
        if metadata.listOptions.style == .connected {
            return [.bottomLeft, .bottomRight]
        }
        return .allCorners
    }

    private var filteredOptions: [SelectOption] {
        if searchText.isEmpty { return metadata.options }
        return metadata.options.filter {
            $0.title.lowercased().contains(searchText.lowercased()) ||
            ($0.group?.lowercased().contains(searchText.lowercased()) ?? false)
        }
    }

    private var dropdownBackgroundColor: AnyView {
        let shape = RoundedCornerShape(radius: 10, corners: dropdownCorners)
        switch metadata.listOptions.background {
        case .system:
            #if os(iOS)
            return AnyView(
                shape
                    .fill(Color(UIColor.systemBackground).opacity(0.95))
                    .overlay(shape.fill(Color.black.opacity(0.05)))
            )
            #else
            return AnyView(
                shape
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.95))
                    .overlay(shape.fill(Color.black.opacity(0.05)))
            )
            #endif
        case .light:
            return AnyView(
                shape
                    .fill(Color.white.opacity(0.95))
                    .overlay(shape.fill(Color.black.opacity(0.06)))
            )
        case .dark:
            return AnyView(shape.fill(Color.black.opacity(0.95)))
        case .glass:
            return AnyView(shape.fill(.clear).background(.ultraThinMaterial, in: shape))
        }
    }

    private var listSecondaryTextColor: Color {
        if metadata.listOptions.background == .light || (metadata.listOptions.background == .system && colorScheme == .light) { return .black.opacity(0.6) }
        return .secondary
    }

    var body: some View {
        let dropdownList = VStack(spacing: 0) {
            if metadata.enableSearch {
                searchBar
                    .padding(.top, metadata.listOptions.style == .connected ? 4 : 0)
            }
            if metadata.isMultiSelect, let allTitle = metadata.checkAllTitle {
                checkAllRow(title: allTitle)
            }
            ScrollView {
                if filteredOptions.isEmpty {
                    VStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            Text("No items found").font(.footnote).foregroundColor(listSecondaryTextColor)
                        }
                        .padding(.horizontal, 12)
                        Spacer()
                    }
                    .frame(height: 140)
                } else {
                    let grouped = Dictionary(grouping: filteredOptions, by: { $0.group })
                    let sortedKeys = grouped.keys.sorted {
                        switch ($0, $1) {
                        case (nil, nil): return false
                        case (nil, _): return true
                        case (_, nil): return false
                        case let (a?, b?): return a < b
                        }
                    }
                    VStack(spacing: 5) {
                        var step = 0
                        ForEach(sortedKeys, id: \.self) { key in
                            if let group = key {
                                groupHeaderRow(title: group, isVisible: isVisible, animationDelay: Double(step) * 0.05)
                                let _ = { step += 1 }()
                            }
                            if let options = grouped[key] {
                                ForEach(options) { option in
                                    optionRow(option, isVisible: isVisible, animationDelay: Double(step) * 0.05)
                                    let _ = { step += 1 }()
                                }
                            }
                        }
                    }
                    .padding(8)
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear { contentHeight = geo.size.height }
                                .onChange(of: geo.size.height) { _, newValue in contentHeight = newValue }
                        }
                    )
                }
            }
            .scrollDisabled(filteredOptions.isEmpty)
            .frame(minHeight: filteredOptions.isEmpty ? 140 : nil, maxHeight: filteredOptions.isEmpty ? 140 : min(dynamicMaxHeight, max(contentHeight, 44)))

            if metadata.isMultiSelect && !selection.isEmpty && false {
                Divider().padding(.horizontal, 8)
                let titles = metadata.options.filter { selection.contains($0.value) }.map { $0.title }
                Text("(\(selection.count)) items selected... \(titles.joined(separator: ", "))")
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
        .frame(minHeight: nil, alignment: .top)
        .allowsHitTesting(true)
        .contentShape(Rectangle())
        .transition(.opacity.combined(with: .move(edge: .top)))
        .onDropdownKeyPress { globalSettings.enableKeyboardNavigation ? handleKeyPress($0) : .ignored }
        .onChange(of: searchText) {
            let options = filteredOptions
            if options.count == 1 { focusedOptionID = options.first?.id }
        }

        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture { metadata.close() }

            if let proxy = rootViewProxy {
                dropdownList
                    .frame(width: metadata.anchor.width, alignment: .topLeading)
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear {
                                    fullDropdownHeight = geo.size.height
                                    metadata.onHeightChange(geo.size.height)
                                }
                                .onChange(of: geo.size.height) { _, newHeight in
                                    fullDropdownHeight = newHeight
                                    metadata.onHeightChange(newHeight)
                                }
                        }
                    )
                    .position(
                        x: metadata.anchor.midX,
                        y: {
                            let config = DropdownPositionConfig.config(
                                isAbsolute: metadata.isAbsolute,
                                style: metadata.listOptions.style
                            )
                            // Position from top edge: anchor.maxY + spacing + verticalOffset
                            // Since .position() centers the view, we need to add half the height to position the center correctly
                            // Use actual measured height if available, otherwise estimate based on visible components
                            let estimatedHeight: CGFloat = {
                                let searchBarHeight: CGFloat = metadata.enableSearch ? 52 : 0
                                let checkAllHeight: CGFloat = (metadata.isMultiSelect && metadata.checkAllTitle != nil) ? 52 : 0
                                let scrollHeight = filteredOptions.isEmpty ? 140 : min(dynamicMaxHeight, max(contentHeight, 44))
                                return searchBarHeight + checkAllHeight + scrollHeight
                            }()
                            let height = fullDropdownHeight > 0 ? fullDropdownHeight : estimatedHeight
                            let topY = metadata.anchor.maxY + config.spacing + config.verticalOffset
                            return topY + (height / 2)
                        }()
                    )
                    .onAppear {
                        // Calculate available space below for max height
                        if let proxy = rootViewProxy {
                            let safeArea = proxy.safeAreaInsets
                            let rootFrame = proxy.frame(in: .global)
                            let spaceBelow = (rootFrame.height + rootFrame.origin.y - safeArea.bottom) - metadata.anchor.maxY
                            dynamicMaxHeight = min(metadata.listOptions.maxHeight, max(spaceBelow - 20, 44))
                        }
                        withAnimation { isVisible = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.isListFocused = true }
                    }
            } else {
                // Inline fallback when no rootViewProxy is provided (positioning handled by caller)
                dropdownList
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear { metadata.onHeightChange(geo.size.height) }
                                .onChange(of: geo.size.height) { _, newValue in metadata.onHeightChange(newValue) }
                        }
                    )
                    .onAppear { withAnimation { isVisible = true } }
            }
        }
    }

    private func checkAllRow(title: String) -> some View {
        let eligible = metadata.options.filter { !$0.isDisabled }
        let allSelected = eligible.allSatisfy { selection.contains($0.value) }
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                if allSelected {
                    selection.subtract(eligible.map { $0.value })
                } else {
                    eligible.forEach { selection.insert($0.value) }
                }
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundColor(.accentColor)
                Text("Select All \(title)")
                    .font(.headline)
                    .foregroundColor((metadata.listOptions.background == .light || (metadata.listOptions.background == .system && colorScheme == .light)) ? .black : .primary)
                Spacer()
                if allSelected { Image(systemName: "checkmark.circle.fill").foregroundColor(.accentColor) }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(0.05))
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var searchBar: some View {
        let isLight = metadata.listOptions.background == .light || (metadata.listOptions.background == .system && colorScheme == .light)
        let iconColor: Color = isLight ? .blue : .secondary
        let textColor: Color = isLight ? .black : .primary
        
        return HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(iconColor)
            ZStack(alignment: .leading) {
                if searchText.isEmpty {
                    Text("Search...")
                        .foregroundColor(isLight ? .black.opacity(0.5) : .secondary)
                }
                TextField("", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFieldFocused)
                    .foregroundColor(textColor)
                    .tint(isLight ? .blue : .accentColor)
            }
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) { Image(systemName: "xmark.circle.fill").foregroundColor(iconColor) }
                    .buttonStyle(.plain)
            }
            #if os(iOS)
            if !isSearchFieldFocused {
                Button(action: { isSearchFieldFocused = true }) { Image(systemName: "keyboard").foregroundColor(iconColor) }
                    .buttonStyle(.plain)
            }
            #endif
        }
        .padding(.horizontal, metadata.listOptions.style == .connected ? 4 : 12)
        .padding(.vertical, 8)
        .background(
            Group {
                if metadata.listOptions.style == .detached {
                    // Detached: rounded chip with theme-aware background
                    searchBackgroundColor
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    // Connected: subtle single-layer background
                    let isLight = metadata.listOptions.background == .light || (metadata.listOptions.background == .system && colorScheme == .light)
                    (isLight ? Color.gray.opacity(0.20) : Color.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        )
        .padding(metadata.listOptions.style == .detached ? 8 : 0)
        .padding(.horizontal, metadata.listOptions.style == .connected ? 4 : 0)
        .padding(.top, (metadata.listOptions.style == .connected && !metadata.isAbsolute) ? 25 : 0)
        .padding(metadata.listOptions.style == .connected ? 4 : 0)
    }

    private var searchBackgroundColor: Color {
        switch metadata.listOptions.background {
        case .dark:
            return Color.white.opacity(0.08)
        case .system:
            return (colorScheme == ColorScheme.dark) ? Color.white.opacity(0.08) : Color.gray.opacity(0.20)
        case .glass:
            return Color.black.opacity(0.15)
        case .light:
            return Color.gray.opacity(0.20)
        }
    }

    private func groupHeaderRow(title: String, isVisible: Bool, animationDelay: Double) -> some View {
        Text(title)
            .font(.caption)
            .foregroundColor((metadata.listOptions.background == .light || (metadata.listOptions.background == .system && colorScheme == .light)) ? .black.opacity(0.6) : .secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.top, 6)
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : -15)
            .animation(.spring(response: 0.2, dampingFraction: 0.6).delay(animationDelay), value: isVisible)
    }

    private func optionRow(_ option: SelectOption, isVisible: Bool, animationDelay: Double) -> some View {
        let isSelected = selection.contains(option.value)
        let isFocused = focusedOptionID == option.id

        let textColor: Color = (metadata.listOptions.background == .light || (metadata.listOptions.background == .system && colorScheme == .light)) ? .black : .primary
        let secondaryTextColor: Color = (metadata.listOptions.background == .light || (metadata.listOptions.background == .system && colorScheme == .light)) ? .black.opacity(0.6) : .secondary

        return Button(action: {
            #if !os(macOS)
            if metadata.enableHaptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
            if metadata.enableSound { AudioServicesPlaySystemSound(1104) }
            #endif
            withAnimation(.easeInOut(duration: 0.15)) {
                if metadata.isMultiSelect {
                    if isSelected { selection.remove(option.value) } else { selection.insert(option.value) }
                } else {
                    selection = [option.value]
                    metadata.close()
                }
            }
        }) {
            // Split into small subviews to help the type-checker
            HStack(spacing: 8) {
                optionIconView(option)
                optionTextStack(option, textColor: textColor, secondaryTextColor: secondaryTextColor, isSelected: isSelected)
                Spacer()
                if isSelected { Image(systemName: "checkmark.circle.fill").foregroundColor(.accentColor) }
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
        .focusable(true)
        .focusEffectDisabledCompat()
        .accessibilityElement()
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text(option.title))
        .accessibilityValue(Text(isSelected ? "Selected" : "Not selected"))
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : -15)
        .animation(.spring(response: 0.2, dampingFraction: 0.6).delay(animationDelay), value: isVisible)
        .onHover { hovering in
            #if os(macOS)
            withAnimation(.easeInOut(duration: 0.2)) { if hovering { focusedOptionID = option.id } }
            #endif
        }
    }

    @ViewBuilder
    private func optionIconView(_ option: SelectOption) -> some View {
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
            case .url(let url):
                #if canImport(SDWebImageSwiftUI)
                WebImage(url: url)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                #else
                #if os(iOS)
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.secondary.opacity(0.1)
                }
                .frame(width: 18, height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                #else
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.secondary.opacity(0.1)
                }
                .frame(width: 18, height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                #endif
                #endif
            }
        }
    }

    @ViewBuilder
    private func optionTextStack(_ option: SelectOption, textColor: Color, secondaryTextColor: Color, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(option.title)
                .font(isSelected ? .headline : .body)
                .foregroundColor(option.isDisabled ? .secondary : textColor)
            if let description = option.description {
                Text(description).font(.caption).foregroundColor(secondaryTextColor)
            }
        }
    }

    private func rowBackgroundColor(for option: SelectOption, isFocused: Bool) -> Color {
        if option.isDisabled { return .gray.opacity(0.05) }
        if selection.contains(option.value) { return .accentColor.opacity(0.12) }
        #if os(macOS)
        if isFocused { return .gray.opacity(0.10) }
        #endif
        return .clear
    }

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .upArrow: moveFocus(direction: -1); return .handled
        case .downArrow: moveFocus(direction: 1); return .handled
        case .return: selectFocusedOption(); return .handled
        case .space: selectFocusedOption(); return .handled
        case .tab: return .ignored
        case .escape: metadata.close(); return .handled
        }
    }

    private func moveFocus(direction: Int) {
        let options = filteredOptions
        guard !options.isEmpty else { return }
        let currentIndex = options.firstIndex(where: { $0.id == focusedOptionID })
        let newIndex: Int
        if let currentIndex { newIndex = (currentIndex + direction + options.count) % options.count }
        else { newIndex = direction > 0 ? 0 : options.count - 1 }
        focusedOptionID = options[newIndex].id
    }

    private func selectFocusedOption() {
        guard let focusedID = focusedOptionID,
              let option = metadata.options.first(where: { $0.id == focusedID }),
              !option.isDisabled else { return }
        #if !os(macOS)
        if metadata.enableHaptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        if metadata.enableSound { AudioServicesPlaySystemSound(1104) }
        #endif
        withAnimation(.easeInOut(duration: 0.15)) {
            if metadata.isMultiSelect {
                if selection.contains(option.value) { selection.remove(option.value) }
                else { selection.insert(option.value) }
            } else {
                selection = [option.value]
                metadata.close()
            }
        }
    }
}
