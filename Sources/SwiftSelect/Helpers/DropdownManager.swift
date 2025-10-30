//
//  DropdownManager.swift
//  SwiftSelect
//
//  Created by Michael Martell on 10/27/25.
//

import SwiftUI

#if os(macOS)
import AppKit
#endif

class DropdownManager: ObservableObject {
    @Published var current: DropdownMetadata?
}

struct DropdownEnvironmentKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: DropdownManager = DropdownManager()
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
    let isAbsolute: Bool
    let onHeightChange: (CGFloat) -> Void
    let checkAllTitle: String?
}


@available(iOS 15.0, macOS 14.0, tvOS 15.0, watchOS 8.0, *)
public struct DropdownOverlay: ViewModifier {
    @StateObject private var manager = DropdownManager()
    #if os(macOS)
    @State private var windowSizeObserver: NSObjectProtocol?
    #endif

    public func body(content: Content) -> some View {
        content
            .environment(\.dropdownManager, manager)
            .overlay(alignment: .topLeading) {
                if let metadata = manager.current {
                    GeometryReader { proxy in
                        OptionsListView(
                            metadata: metadata,
                            rootViewProxy: proxy
                        )
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
            .onChange(of: manager.current?.id) { _, _ in
                // Reset observer when current changes
                removeWindowResizeObserver()
                if manager.current != nil {
                    setupWindowResizeObserver()
                }
            }
            #endif
    }
    
    #if os(macOS)
    private func setupWindowResizeObserver() {
        guard windowSizeObserver == nil else { return }
        
        windowSizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: nil,
            queue: .main
        ) { [weak manager] _ in
            guard let manager = manager, let metadata = manager.current else { return }
            // Close dropdown when window resizes
            metadata.close()
        }
    }
    
    private func removeWindowResizeObserver() {
        if let observer = windowSizeObserver {
            NotificationCenter.default.removeObserver(observer)
            windowSizeObserver = nil
        }
    }
    #endif
}

@available(iOS 15.0, macOS 14.0, tvOS 15.0, watchOS 8.0, *)
public extension View {
    func dropdownOverlay() -> some View { self.modifier(DropdownOverlay()) }
}
