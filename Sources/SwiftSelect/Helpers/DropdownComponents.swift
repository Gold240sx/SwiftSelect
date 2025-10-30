//
//  DropdownComponents.swift
//  SwiftSelect
//
//  Created by Michael Martell on 10/27/25.
//

import SwiftUI
#if os(macOS)
import AppKit

// Convert NSBezierPath to CGPath without using the macOS 14+ cgPath property
extension NSBezierPath {
    var ssCGPath: CGPath {
        let path = CGMutablePath()
        var points = [NSPoint](repeating: .zero, count: 3)
        for index in 0..<self.elementCount {
            switch self.element(at: index, associatedPoints: &points) {
            case .moveTo:
                path.move(to: CGPoint(x: points[0].x, y: points[0].y))
            case .lineTo:
                path.addLine(to: CGPoint(x: points[0].x, y: points[0].y))
            case .curveTo:
                path.addCurve(
                    to: CGPoint(x: points[2].x, y: points[2].y),
                    control1: CGPoint(x: points[0].x, y: points[0].y),
                    control2: CGPoint(x: points[1].x, y: points[1].y)
                )
            case .closePath:
                path.closeSubpath()
            default:
                // Treat any unknown element types conservatively
                break
            }
        }
        return path
    }
}
#endif

// MARK: - Outline helper
struct CustomOutlineModifier<S: ShapeStyle, V: Shape>: ViewModifier {
    let shapeStyle: S
    let shape: V
    let lineWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(
                shape.stroke(shapeStyle, lineWidth: lineWidth)
            )
    }
}

public extension View {
    func customOutline<S: ShapeStyle, V: Shape>(
        _ shapeStyle: S,
        shape: V,
        lineWidth: CGFloat = 1
    ) -> some View {
        self.modifier(
            CustomOutlineModifier(
                shapeStyle: shapeStyle,
                shape: shape,
                lineWidth: lineWidth
            )
        )
    }

    // Apply focusEffectDisabled only on platforms/versions where available
    @ViewBuilder
    func focusEffectDisabledCompat() -> some View {
        #if os(macOS)
        if #available(macOS 14.0, *) { self.focusEffectDisabled() } else { self }
        #else
        self
        #endif
    }

    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}

// MARK: - Shapes
public struct RectCorner: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let topLeft = RectCorner(rawValue: 1 << 0)
    public static let topRight = RectCorner(rawValue: 1 << 1)
    public static let bottomLeft = RectCorner(rawValue: 1 << 2)
    public static let bottomRight = RectCorner(rawValue: 1 << 3)

    public static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

@available(macOS 12.0, iOS 13.0, tvOS 13.0, *)
struct RoundedCornerShape: Shape {
    var radius: CGFloat = .infinity
    var corners: RectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        #if os(macOS)
        let path = NSBezierPath()
        let cornerRadius = min(radius, rect.width / 2, rect.height / 2)

        let topLeft = rect.origin
        let topRight = CGPoint(x: rect.maxX, y: rect.minY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)

        path.move(to: CGPoint(x: topLeft.x + cornerRadius, y: topLeft.y))

        path.line(to: CGPoint(x: topRight.x - cornerRadius, y: topRight.y))
        if corners.contains(.topRight) {
            path.appendArc(withCenter: CGPoint(x: topRight.x - cornerRadius, y: topRight.y + cornerRadius), radius: cornerRadius, startAngle: 270, endAngle: 360)
        } else {
            path.line(to: topRight)
        }

        path.line(to: CGPoint(x: bottomRight.x, y: bottomRight.y - cornerRadius))
        if corners.contains(.bottomRight) {
            path.appendArc(withCenter: CGPoint(x: bottomRight.x - cornerRadius, y: bottomRight.y - cornerRadius), radius: cornerRadius, startAngle: 0, endAngle: 90)
        } else {
            path.line(to: bottomRight)
        }

        path.line(to: CGPoint(x: bottomLeft.x + cornerRadius, y: bottomLeft.y))
        if corners.contains(.bottomLeft) {
            path.appendArc(withCenter: CGPoint(x: bottomLeft.x + cornerRadius, y: bottomLeft.y - cornerRadius), radius: cornerRadius, startAngle: 90, endAngle: 180)
        } else {
            path.line(to: bottomLeft)
        }

        path.line(to: CGPoint(x: topLeft.x, y: topLeft.y + cornerRadius))
        if corners.contains(.topLeft) {
            path.appendArc(withCenter: CGPoint(x: topLeft.x + cornerRadius, y: topLeft.y + cornerRadius), radius: cornerRadius, startAngle: 180, endAngle: 270)
        } else {
            path.line(to: topLeft)
        }

        path.close()
        return Path(path.ssCGPath)
        #else
        var uiKitCorners: UIRectCorner = []
        if corners.contains(.topLeft) { uiKitCorners.insert(.topLeft) }
        if corners.contains(.topRight) { uiKitCorners.insert(.topRight) }
        if corners.contains(.bottomLeft) { uiKitCorners.insert(.bottomLeft) }
        if corners.contains(.bottomRight) { uiKitCorners.insert(.bottomRight) }

        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: uiKitCorners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
        #endif
    }
}
