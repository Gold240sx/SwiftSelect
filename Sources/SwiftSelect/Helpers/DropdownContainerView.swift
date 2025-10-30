//
//  DropdownContainerView.swift
//  SwiftSelect
//
//  Created by Michael Martell on 10/27/25.
//

import SwiftUI
#if canImport(SDWebImageSwiftUI)
import SDWebImageSwiftUI
#endif
#if canImport(SDWebImageSVGCoder)
import SDWebImageSVGCoder
#endif
#if !os(macOS)
import AVFoundation
#endif


@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
struct DropdownContainerView: View {
    let metadata: DropdownMetadata
    var rootViewProxy: GeometryProxy?
    @Binding private var selection: Set<String>
    @FocusState private var isSearchFieldFocused: Bool
    @FocusState private var isListFocused: Bool
    @Environment(\.dropdownSettings) private var globalSettings
    @Environment(\.colorScheme) private var envColorScheme

    @State private var isVisible = false
    @State private var dynamicMaxHeight: CGFloat = 250
    @State private var focusedOptionID: UUID? = nil
    @State private var searchText: String = ""
    @State private var contentHeight: CGFloat = 0

    init(metadata: DropdownMetadata, rootViewProxy: GeometryProxy? = nil) {
        self.metadata = metadata
        self.rootViewProxy = rootViewProxy
        self._selection = metadata.selection
        #if canImport(SDWebImageSVGCoder)
        _ = DropdownContainerView.registerSVGCoder
        #endif
    }

    private var dropdownCorners: RectCorner {
        if metadata.listOptions.style == .connected {
            return [.bottomLeft, .bottomRight]
        }
        return .allCorners
    }

    #if canImport(SDWebImageSVGCoder)
    private static let registerSVGCoder: Void = {
        let coder = SDImageSVGCoder.shared
        SDImageCodersManager.shared.addCoder(coder)
    }()
    #endif

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
                    .fill(Color(UIColor.systemBackground))
                    .overlay(shape.fill(Color.black.opacity(0.05)))
            )
            #else
            return AnyView(
                shape
                    .fill(Color(NSColor.windowBackgroundColor))
                    .overlay(shape.fill(Color.black.opacity(0.05)))
            )
            #endif
        case .light:
            return AnyView(
                shape
                    .fill(Color.white)
                    .overlay(shape.fill(Color.black.opacity(0.06)))
            )
        case .dark:
            return AnyView(shape.fill(Color.black))
        case .glass:
            return AnyView(shape.fill(.clear).background(.ultraThinMaterial, in: shape))
        }
    }

    private var listSecondaryTextColor: Color {
        if metadata.listOptions.background == .light { return .black.opacity(0.6) }
        return .secondary
    }
    
    private func checkAllRow(title: String) -> some View {
        let eligible = metadata.options.filter { !$0.isDisabled }
        let allSelected = eligible.allSatisfy { selection.contains($0.value) }
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                if allSelected { selection.subtract(eligible.map { $0.value }) }
                else { eligible.forEach { selection.insert($0.value) } }
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.headline)
                    .foregroundColor(metadata.listOptions.background == .light ? .black : .primary)
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
        HStack(spacing: 8) {
            let iconColor: Color = (metadata.listOptions.background == .light) ? .blue : .secondary
            Image(systemName: "magnifyingglass").foregroundColor(iconColor)
            TextField("Search...", text: $searchText)
                .textFieldStyle(.plain)
                .focused($isSearchFieldFocused)
                .foregroundColor(metadata.listOptions.background == .light ? .black : .primary)
                .tint(metadata.listOptions.background == .light ? .blue : .accentColor)
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
            if metadata.isMultiSelect && !selection.isEmpty {
                Button(action: { withAnimation { selection.removeAll() } }) {
                    Text("Clear Selection").font(.caption).foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, metadata.listOptions.style == .connected ? 4 : 12)
        .padding(.vertical, 8)
        .background(
            Group {
                if metadata.listOptions.style == .detached {
                    searchBackgroundColor
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Color.primary.opacity(0.05)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        )
        .padding(metadata.listOptions.style == .detached ? 8 : 0)
        .padding(.horizontal, metadata.listOptions.style == .connected ? 4 : 0)
        .padding(.top, (metadata.listOptions.style == .connected && !metadata.isAbsolute) ? 25 : 0)
    }

    private var searchBackgroundColor: Color {
        switch metadata.listOptions.background {
        case .dark:
            return Color.white.opacity(0.08)
        case .system:
            return (envColorScheme == ColorScheme.dark) ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
        case .glass:
            return Color.black.opacity(0.15)
        case .light:
            return Color.black.opacity(0.06)
        }
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

    private func optionRow(_ option: SelectOption, isVisible: Bool, animationDelay: Double) -> some View {
        let isSelected = selection.contains(option.value)
        let isFocused = focusedOptionID == option.id

        let textColor: Color = (metadata.listOptions.background == .light) ? .black : .primary
        let secondaryTextColor: Color = (metadata.listOptions.background == .light) ? .black.opacity(0.6) : .secondary

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
                    case .url(let url):
                        #if canImport(SDWebImageSwiftUI)
                        WebImage(url: url)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .cornerRadius(4)
                        #else
                        #if os(iOS)
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            Color.secondary.opacity(0.1)
                        }
                        .frame(width: 18, height: 18)
                        .cornerRadius(4)
                        #else
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            Color.secondary.opacity(0.1)
                        }
                        .frame(width: 18, height: 18)
                        .cornerRadius(4)
                        #endif
                        #endif
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(isSelected ? .headline : .body)
                        .foregroundColor(option.isDisabled ? .secondary : textColor)
                    if let description = option.description {
                        Text(description).font(.caption).foregroundColor(secondaryTextColor)
                    }
                }
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
    
    var body: some View {
        let dropdownList = VStack(spacing: 0) {
            if metadata.enableSearch { searchBar }
            if metadata.isMultiSelect, let allTitle = metadata.checkAllTitle { checkAllRow(title: allTitle) }
            ScrollView {
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

                if filteredOptions.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        Text("No items found").font(.footnote).foregroundColor(listSecondaryTextColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(12)
                }
            }
            .frame(maxHeight: min(dynamicMaxHeight, max(contentHeight, 44)))

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
        .contentShape(Rectangle())
        .transition(.opacity.combined(with: .move(edge: .top)))
        .onDropdownKeyPress { globalSettings.enableKeyboardNavigation ? handleKeyPress($0) : .ignored }
        .onChange(of: searchText) { _, _ in
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
                    .frame(width: metadata.anchor.width)
                    .position(
                        x: metadata.anchor.midX,
                        y: {
                            // Always position below: anchor.maxY + spacing + halfHeight
                            let spacing: CGFloat = (metadata.listOptions.style == .connected) ? 6: (metadata.isAbsolute ? 10 : 4)
                            let effectiveHeight = min(dynamicMaxHeight, max(contentHeight, 44))
                            return metadata.anchor.maxY + spacing + (effectiveHeight / 2)
                        }()
                    )
                    .background(GeometryReader { geo in
                        Color.clear.onChange(of: geo.size.height) { _, newHeight in metadata.onHeightChange(newHeight) }
                    })
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
                    .padding(.bottom, metadata.listOptions.style == .connected ? 28 : 36)
            }
        }
        .padding(.top, metadata.isAbsolute ? 35 : 0)
    }
}

#if canImport(SwiftUI)
@available(macOS 14.0, *)
#Preview {
    struct PreviewHost: View {
        @State private var selection: Set<String> = []

        var body: some View {
            let options: [SelectOption] = [
                .init("United States", value: "US"),
                .init("Canada", value: "CA"),
                .init("Japan", value: "JP")
            ]

            let metadata = DropdownMetadata(
                id: UUID(),
                options: options,
                selection: $selection,
                isMultiSelect: true,
                anchor: CGRect(x: 160, y: 120, width: 220, height: 36),
                listOptions: ListOptions(maxHeight: 250, style: .connected, background: .system),
                enableHaptics: false,
                enableSound: false,
                enableSearch: true,
                close: {},
                isAbsolute: false,
                onHeightChange: { _ in },
                checkAllTitle: nil
            )

            return ZStack {
                Color.gray.opacity(0.1).ignoresSafeArea()
                DropdownContainerView(metadata: metadata, rootViewProxy: nil)
            }
            .frame(width: 600, height: 420)
        }
    }

    return PreviewHost()
}
#endif


