//
//  Option.swift
//  SwiftSelect
//
//  Created by Michael Martell on 10/27/25.
//


import SwiftUI

public enum IconType {
    case image(Image)
    case emoji(String)
    case url(URL)
}

public struct ListOptions: Equatable {
    public enum Style: Equatable { case connected, detached }
    public enum Background: Equatable { case system, light, dark, glass }

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

public struct SelectOption: Identifiable, Hashable, @unchecked Sendable {
    public let id: UUID
    public let title: String
    public let value: String
    public let icon: IconType?
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

    // Web image initializer (supports SVG via SDWebImageSVGCoder when registered)
    public init(
        id: UUID = UUID(),
        _ title: String,
        value: String,
        iconURL: String,
        description: String? = nil,
        group: String? = nil,
        isDisabled: Bool = false
    ) {
        self.id = id
        self.title = title
        self.value = value
        if let url = URL(string: iconURL) {
            self.icon = .url(url)
        } else {
            self.icon = nil
        }
        self.description = description
        self.group = group
        self.isDisabled = isDisabled
    }

    public func hash(into hasher: inout Hasher) { hasher.combine(title) }
    public static func == (lhs: SelectOption, rhs: SelectOption) -> Bool { lhs.id == rhs.id }
}

public enum DropDownPosition { case top, bottom }

// Image in IconType is not Sendable; we never share across actors. Declare unchecked.
extension IconType: @unchecked Sendable {}
