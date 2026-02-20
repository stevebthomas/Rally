import AVFoundation
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Service for recording audio using AVFoundation
@MainActor
final class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var recordingLevel: Float = 0
    @Published var permissionGranted = false
    @Published var errorMessage: String?

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var recordingURL: URL?

    override init() {
        super.init()
        checkPermission()
    }

    /// Check and request microphone permission
    func checkPermission() {
        #if os(iOS)
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                permissionGranted = true
            case .denied:
                permissionGranted = false
                errorMessage = "Microphone access denied. Please enable in Settings."
            case .undetermined:
                requestPermission()
            @unknown default:
                break
            }
        } else {
            // Fallback for iOS < 17
            let session = AVAudioSession.sharedInstance()
            switch session.recordPermission {
            case .granted:
                permissionGranted = true
            case .denied:
                permissionGranted = false
                errorMessage = "Microphone access denied. Please enable in Settings."
            case .undetermined:
                requestPermission()
            @unknown default:
                break
            }
        }
        #endif
    }

    /// Request microphone permission from user
    func requestPermission() {
        #if os(iOS)
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    self?.permissionGranted = granted
                    if !granted {
                        self?.errorMessage = "Microphone access is required for voice recording."
                    }
                }
            }
        } else {
            // Fallback for iOS < 17
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    self?.permissionGranted = granted
                    if !granted {
                        self?.errorMessage = "Microphone access is required for voice recording."
                    }
                }
            }
        }
        #endif
    }

    /// Start recording audio
    func startRecording() {
        guard permissionGranted else {
            requestPermission()
            return
        }

        // Reset state
        errorMessage = nil
        recordingDuration = 0

        // Configure audio session - allow mixing with other audio so music doesn't stop
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .mixWithOthers])
            try audioSession.setActive(true, options: [])
        } catch {
            errorMessage = "Failed to configure audio session: \(error.localizedDescription)"
            return
        }

        // Create temporary file URL
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "workout_recording_\(UUID().uuidString).m4a"
        recordingURL = tempDir.appendingPathComponent(fileName)

        guard let url = recordingURL else { return }

        // Recording settings for M4A format
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            isRecording = true

            // Start timer for duration and level updates
            startTimer()

            // Haptic feedback
            #if canImport(UIKit)
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            #elseif canImport(AppKit)
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
            #endif

        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }

    /// Stop recording and return the audio file URL
    func stopRecording() -> URL? {
        guard isRecording else { return nil }

        audioRecorder?.stop()
        isRecording = false
        stopTimer()

        // Deactivate audio session and notify others to resume
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        // Haptic feedback
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #elseif canImport(AppKit)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        #endif

        return recordingURL
    }

    /// Cancel recording and delete the file
    func cancelRecording() {
        audioRecorder?.stop()
        isRecording = false
        stopTimer()

        // Delete the recording file
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordingURL = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let recorder = self.audioRecorder else { return }

                self.recordingDuration = recorder.currentTime

                // Update audio level
                recorder.updateMeters()
                let level = recorder.averagePower(forChannel: 0)
                // Normalize to 0-1 range (level is typically -160 to 0)
                self.recordingLevel = max(0, (level + 60) / 60)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        recordingLevel = 0
    }

    /// Format duration for display
    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                errorMessage = "Recording did not complete successfully."
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            errorMessage = "Recording error: \(error?.localizedDescription ?? "Unknown error")"
        }
    }
}
