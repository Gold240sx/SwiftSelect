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

@available(iOS 13.0, macOS 12.0, tvOS 13.0, watchOS 6.0, *)
fileprivate struct NoOpacityButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .opacity(1.0)  // Force full opacity, no transparency changes
  }
}

@available(iOS 13.0, macOS 12.0, tvOS 13.0, watchOS 6.0, *)
public struct SelectPicker: View {
  @Binding var isExpanded: Bool
  public let isLoading: Bool
  public let stateName: Set<String>
  public let internalOptions: [SelectOption]
  public let placeholder: String
  public let roundedCorners: RectCorner
  public let isMultiSelect: Bool
  public let onClearSelection: (() -> Void)?
  @State private var isHovered: Bool = false
  @State private var isPressed: Bool = false
  @State private var cachedUrlToImage: [URL: Image] = [:]
  #if os(iOS)
  private var pixelScale: CGFloat { UIScreen.main.scale }
  #else
  private var pixelScale: CGFloat { NSScreen.main?.backingScaleFactor ?? 2.0 }
  #endif
  @Environment(\.dropdownSettings) private var dropdownSettings
  @Environment(\.colorScheme) private var colorScheme
  
  private var textColor: Color {
    switch dropdownSettings.background ?? .system {
    case .light:
      return .black
    case .dark:
      return .white
    default:
      return .primary
    }
  }

  // Register SVG coder once
  #if canImport(SDWebImageSVGCoder)
  private static let registerSVGCoder: Void = {
    let coder = SDImageSVGCoder.shared
    SDImageCodersManager.shared.addCoder(coder)
  }()
  #endif

  public init(
    isExpanded: Binding<Bool>,
    isLoading: Bool,
    stateName: Set<String>,
    internalOptions: [SelectOption],
    placeholder: String,
    roundedCorners: RectCorner = .allCorners,
    isMultiSelect: Bool = false,
    onClearSelection: (() -> Void)? = nil
  ) {
    self._isExpanded = isExpanded
    self.isLoading = isLoading
    self.stateName = stateName
    self.internalOptions = internalOptions
    self.placeholder = placeholder
    self.roundedCorners = roundedCorners
    self.isMultiSelect = isMultiSelect
    self.onClearSelection = onClearSelection
    #if canImport(SDWebImageSVGCoder)
    _ = SelectPicker.registerSVGCoder
    #endif
  }

  public var body: some View {
    let clipShapeView = RoundedCornerShape(
      radius: 10,
      corners: roundedCorners
    )
    // removed unused 'shape' variable
    // Resolve background based on global dropdown settings
    let bg: AnyView = {
      switch dropdownSettings.background ?? .system {
      case .system:
        #if os(iOS)
        return AnyView(clipShapeView.fill(Color(UIColor.secondarySystemBackground)))
        #else
        return AnyView(clipShapeView.fill(Color(NSColor.windowBackgroundColor)))
        #endif
      case .light:
        return AnyView(clipShapeView.fill(Color.white))
      case .dark:
        return AnyView(clipShapeView.fill(Color.black))
      case .glass:
        return AnyView(
          clipShapeView
            .fill(Color.clear)
            .background(.ultraThinMaterial, in: clipShapeView)
        )
      }
    }()

    Button(action: {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
        isExpanded.toggle()
      }
    }) {
        HStack(spacing: 8) {
        
        if isLoading {
          ProgressView().frame(width: 18, height: 18)
          Text("Loading...").foregroundColor(.secondary)
        } else {
          if let single = selectedSingleOption {
            iconView(for: single)
          }
          Text(displayTitle)
            .fontWeight(stateName.isEmpty ? .regular : .bold)
            .lineLimit(1)
            .allowsTightening(true)
            .foregroundColor(stateName.isEmpty ? textColor.opacity(0.75) : textColor)
        }
        Spacer()
            if isMultiSelect && !stateName.isEmpty, let clearAction = onClearSelection {
              Button(action: { withAnimation { clearAction() } }) {
                Text("Clear Selection")
                  .font(.caption)
                  .foregroundColor(.accentColor)
              }
              .buttonStyle(.plain)
              .fixedSize()
              .padding(.trailing,8)
            }
        Image(systemName: "chevron.down")
          .foregroundColor(textColor)
          .rotationEffect(.degrees(isExpanded ? -180 : 0))
          .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
      }
      .padding(10)
      .frame(minHeight: 36)
      .background(
        ZStack {
          bg
          // Show lighter gray overlay when pressed (full opacity, no transparency change)
          clipShapeView
            .fill(isPressed ? Color.gray.opacity(0.15) : (isHovered ? Color.black.opacity(0.06) : Color.clear))
            .blendMode(.normal)
        }
        .shadow(color: .black.opacity(isExpanded ? 0.25 : 0.12), radius: isExpanded ? 10 : 6, y: isExpanded ? 5 : 3)
      )
      .clipShape(clipShapeView)
    }
    .buttonStyle(NoOpacityButtonStyle())
    .simultaneousGesture(
      DragGesture(minimumDistance: 0)
        .onChanged { _ in
          if !isPressed {
            withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
          }
        }
        .onEnded { _ in
          withAnimation(.easeInOut(duration: 0.1)) { isPressed = false }
        }
    )
    .focusable(true)
    .focusEffectDisabledCompat()
    .disabled(isLoading)
    #if os(macOS)
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
    }
    #endif
    .accessibilityElement()
    .accessibilityAddTraits(.isButton)
    .accessibilityLabel(Text("dropdown"))
    .accessibilityValue(Text(displayTitle))
    .accessibilityHint(Text(isExpanded ? "Double-tap to close" : "Double-tap to open"))
  }

  // Single selected option, if exactly one
  private var selectedSingleOption: SelectOption? {
    guard stateName.count == 1, let only = stateName.first else { return nil }
    return internalOptions.first(where: { $0.value == only })
  }

  // Display title for 0/1/many selections
  private var displayTitle: String {
    if stateName.isEmpty { return placeholder }
    // If 3 or more selected, show a compact counter instead of listing all
    if stateName.count > 3 { return "(\(stateName.count)) items selected" }
    if let single = selectedSingleOption { return single.title }
    let titles = internalOptions.filter { stateName.contains($0.value) }.map { $0.title }
    return titles.isEmpty ? placeholder : titles.joined(separator: ", ")
  }

  @ViewBuilder
  private func iconView(for option: SelectOption) -> some View {
    switch option.icon {
    case .image(let image):
      image
        .resizable()
        .scaledToFit()
        .frame(width: 18, height: 18)
        .cornerRadius(4)
    case .emoji(let string):
      Text(string).font(.title3)
    case .url(let url):
      if let cached = cachedUrlToImage[url] {
        cached
          .resizable()
          .scaledToFill()
          .frame(width: 18, height: 18)
          .clipShape(RoundedRectangle(cornerRadius: 4))
      } else {
        #if canImport(SDWebImageSwiftUI)
        WebImage(url: url)
          .resizable()
          .onSuccess { image, _, _ in
            #if os(iOS)
            cachedUrlToImage[url] = Image(uiImage: image)
            #else
            cachedUrlToImage[url] = Image(nsImage: image)
            #endif
          }
          .onFailure { error in
            print("Picker WebImage failed: \(error.localizedDescription)")
          }
          .scaledToFill()
          .frame(width: 18, height: 18)
          .clipShape(RoundedRectangle(cornerRadius: 4))
        #else
        #if os(iOS)
        if #available(iOS 15.0, *) {
          AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
          } placeholder: {
            Color.secondary.opacity(0.1)
          }
          .frame(width: 18, height: 18)
          .clipShape(RoundedRectangle(cornerRadius: 4))
        } else { EmptyView() }
        #else
        if #available(macOS 12.0, *) {
          AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
          } placeholder: {
            Color.secondary.opacity(0.1)
          }
          .frame(width: 18, height: 18)
          .clipShape(RoundedRectangle(cornerRadius: 4))
        } else { EmptyView() }
        #endif
        #endif
      }
    case .none:
      EmptyView()
    }
  }
}
