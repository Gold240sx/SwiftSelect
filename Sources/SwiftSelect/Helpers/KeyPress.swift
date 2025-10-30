//
//  KeyPress.swift
//  SwiftSelect
//
//  Created by Michael Martell on 10/27/25.
//


import SwiftUI

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
import UIKit

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
import AppKit

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
    func onDropdownKeyPress(_ handler: @escaping (KeyPress) -> KeyPress.Result) -> some View {
        self.background(KeyPressCaptureView(handler: handler))
    }
}
