//
//  GlassCard.swift
//  SwiftSelect
//
//  Created by Michael Martell on 10/27/25.
//

import SwiftUI
#if os(iOS)
import CoreMotion
#endif

@available(iOS 13.0, macOS 14.0, tvOS 13.0, *)
struct GlassCard: View {
    let id: Int
    let title: String
    @Binding var selectedIDs: Set<Int>
    #if os(iOS)
    @ObservedObject private var motion = MotionManager()
    #endif
    @State private var isHovered = false

    var isSelected: Bool { selectedIDs.contains(id) }

    var body: some View {
        #if os(iOS)
        let tiltX = CGFloat(motion.roll) * 10
        let tiltY = CGFloat(motion.pitch) * 10
        #else
        let tiltX: CGFloat = 0
        let tiltY: CGFloat = 0
        #endif
        let shape = RoundedRectangle(cornerRadius: 25)

        ZStack {
            Group {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .background(.ultraThinMaterial)
                    .clipShape(shape)
            }
            .customOutline(
                LinearGradient(
                    colors: [.white.opacity(0.5), .white.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                shape: shape,
                lineWidth: isSelected || isHovered ? 2.5 : 1
            )
            .shadow(color: .black.opacity(isHovered || isSelected ? 0.25 : 0.1), radius: isHovered || isSelected ? 20 : 5)

            Text(title)
                .font(.headline)
                .foregroundStyle(isSelected ? Color.blue : .white)
                .padding()
        }
        .frame(width: 200, height: 120)
        .rotation3DEffect(.degrees(isHovered ? Double(tiltX) / 2 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
        .rotation3DEffect(.degrees(isHovered ? Double(-tiltY) / 2 : 0), axis: (x: 1, y: 0, z: 0), perspective: 0.4)
        .scaleEffect(isHovered || isSelected ? 1.06 : 1.0)
        .animation(.easeInOut(duration: 0.25), value: isHovered)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        .onTapGesture {
            if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
            #if os(iOS)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            #endif
        }
        .onHover { hovering in isHovered = hovering }
        .focusable(true)
        .focusEffectDisabled()
        #if os(visionOS)
        .onFocusChange { focused in isHovered = focused }
        #endif
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(title) card")
    }
}

#if os(iOS)
final class MotionManager: ObservableObject {
    private let manager = CMMotionManager()
    @Published var roll: Double = 0
    @Published var pitch: Double = 0
    @Published var yaw: Double = 0

    init() {
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        if manager.isDeviceMotionAvailable {
            manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
                guard let s = self, let motion = motion else { return }
                s.roll = motion.attitude.roll
                s.pitch = motion.attitude.pitch
                s.yaw = motion.attitude.yaw
            }
        }
    }

    deinit { manager.stopDeviceMotionUpdates() }
}
#endif
