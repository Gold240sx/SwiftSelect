//
//  DropDownSettings.swift
//  SwiftSelect
//
//  Created by Michael Martell on 10/27/25.
//

import SwiftUI

public enum DropdownStyle: String, CaseIterable, Sendable {
    case connected, detached
}
public enum Mode: String, CaseIterable, Sendable {
    case inline, absolute
}
public enum DropdownBackground: String, CaseIterable, Sendable {
    case system, light, dark, glass
}

public struct DropdownSettings: Sendable {
    public var maxHeight: CGFloat?
    public var style: DropdownStyle?
    public var background: DropdownBackground?
    public var enableHaptics: Bool
    public var enableSound: Bool
    public var enableSearch: Bool
    public var isAbsolute: Mode?
    public var isMultiSelect: Bool
    public var enableKeyboardNavigation: Bool

    public init(
        maxHeight: CGFloat? = nil,
        style: DropdownStyle? = nil,
        background: DropdownBackground? = nil,
        enableHaptics: Bool = true,
        enableSound: Bool = true,
        enableSearch: Bool = false,
        isAbsolute: Mode? = .inline,
        isMultiSelect: Bool = false,
        enableKeyboardNavigation: Bool = true
    ) {
        self.maxHeight = maxHeight
        self.style = style
        self.background = background
        self.enableHaptics = enableHaptics
        self.enableSound = enableSound
        self.enableSearch = enableSearch
        self.isAbsolute = isAbsolute
        self.isMultiSelect = isMultiSelect
        self.enableKeyboardNavigation = enableKeyboardNavigation
    }
}

private struct DropdownSettingsKey: EnvironmentKey {
    static let defaultValue: DropdownSettings = DropdownSettings()
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public extension EnvironmentValues {
    var dropdownSettings: DropdownSettings {
        get { self[DropdownSettingsKey.self] }
        set { self[DropdownSettingsKey.self] = newValue }
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public extension View {
    func dropdownSettings(_ settings: DropdownSettings) -> some View {
        environment(\.dropdownSettings, settings)
    }
}

