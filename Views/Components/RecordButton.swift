import SwiftUI

/// Hold-to-record button with pulsing animation
struct RecordButton: View {
    let isRecording: Bool
    let audioLevel: Float
    let onStart: () -> Void
    let onStop: () -> Void

    @State private var isPressing = false
    @State private var pulseScale: CGFloat = 1.0

    private let buttonSize: CGFloat = 100
    private let maxPulseScale: CGFloat = 1.5

    var body: some View {
        ZStack {
            // Outer pulse ring (visible when recording)
            Circle()
                .fill(Color.red.opacity(0.3))
                .frame(width: buttonSize * pulseScale, height: buttonSize * pulseScale)
                .opacity(isRecording ? 1 : 0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: pulseScale)

            // Audio level ring
            Circle()
                .fill(Color.red.opacity(0.2))
                .frame(
                    width: buttonSize * (1 + CGFloat(audioLevel) * 0.5),
                    height: buttonSize * (1 + CGFloat(audioLevel) * 0.5)
                )
                .opacity(isRecording ? 1 : 0)
                .animation(.easeOut(duration: 0.1), value: audioLevel)

            // Main button
            Circle()
                .fill(isRecording ? Color.red : Color.rallyOrange)
                .frame(width: buttonSize, height: buttonSize)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 4)
                )
                .scaleEffect(isPressing ? 0.9 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressing)

            // Icon
            Image(systemName: isRecording ? "waveform" : "mic.fill")
                .font(.system(size: 40, weight: .medium))
                .foregroundColor(.white)
                .symbolEffect(.variableColor.iterative, isActive: isRecording)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressing {
                        isPressing = true
                        onStart()
                        startPulseAnimation()
                    }
                }
                .onEnded { _ in
                    isPressing = false
                    onStop()
                    stopPulseAnimation()
                }
        )
        .accessibilityLabel(isRecording ? "Recording. Release to stop." : "Hold to record workout")
        .accessibilityHint("Press and hold to record your workout description")
    }

    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            pulseScale = maxPulseScale
        }
    }

    private func stopPulseAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            pulseScale = 1.0
        }
    }
}

/// Tap-to-toggle record button variant
struct TapRecordButton: View {
    let isRecording: Bool
    let audioLevel: Float
    let duration: String
    let onToggle: () -> Void

    private let buttonSize: CGFloat = 80

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Audio level ring
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(
                        width: buttonSize * (1 + CGFloat(audioLevel) * 0.3),
                        height: buttonSize * (1 + CGFloat(audioLevel) * 0.3)
                    )
                    .opacity(isRecording ? 1 : 0)
                    .animation(.easeOut(duration: 0.1), value: audioLevel)

                // Main button
                Circle()
                    .fill(isRecording ? Color.red : Color.rallyOrange)
                    .frame(width: buttonSize, height: buttonSize)
                    .overlay(
                        Group {
                            if isRecording {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white)
                                    .frame(width: 24, height: 24)
                            } else {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 30, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                    )
            }
            .onTapGesture {
                #if canImport(UIKit)
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                #elseif canImport(AppKit)
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
                #endif
                onToggle()
            }

            // Duration label
            if isRecording {
                Text(duration)
                    .font(.system(.title2, design: .monospaced))
                    .foregroundColor(.secondaryText)
            }
        }
        .accessibilityLabel(isRecording ? "Recording \(duration). Tap to stop." : "Tap to start recording")
    }
}

#Preview {
    VStack(spacing: 50) {
        RecordButton(
            isRecording: false,
            audioLevel: 0,
            onStart: {},
            onStop: {}
        )

        RecordButton(
            isRecording: true,
            audioLevel: 0.5,
            onStart: {},
            onStop: {}
        )

        TapRecordButton(
            isRecording: true,
            audioLevel: 0.7,
            duration: "0:15",
            onToggle: {}
        )
    }
    .padding()
}
