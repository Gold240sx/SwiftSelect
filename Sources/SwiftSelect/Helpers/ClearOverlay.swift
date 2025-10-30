//
//  ClearOverlay.swift
//  SwiftSelect
//
//  Created by Michael Martell on 10/28/25.
//

import SwiftUI

@available(iOS 13.0, macOS 12.0, tvOS 13.0, watchOS 6.0, *)
public struct ClearOverlay<Content: View>: View {
  private let isAbsolute: Bool
  private let isExpanded: Bool
  private let inlineGapHeight: CGFloat
  private let isConnectedStyle: Bool
  private let content: Content

  public init(
    isAbsolute: Bool = false,
    isExpanded: Bool = false,
    inlineGapHeight: CGFloat = 0,
    isConnectedStyle: Bool = false,
    @ViewBuilder content: () -> Content
  ) {
    self.isAbsolute = isAbsolute
    self.isExpanded = isExpanded
    self.inlineGapHeight = inlineGapHeight
    self.isConnectedStyle = isConnectedStyle
    self.content = content()
  }

  public var body: some View {
    VStack(spacing: 0) {
      content
      if isExpanded && !isAbsolute {
        Color.clear.frame(height: inlineGapHeight)
      }
    }
  }
}
