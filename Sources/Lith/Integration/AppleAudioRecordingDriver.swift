#if canImport(AVFoundation)
@preconcurrency import AVFoundation
import Foundation

@MainActor
public final class AppleAudioRecordingDriver: NSObject, AudioRecordingDriver, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    public var onInterruption: (@MainActor @Sendable (String) -> Void)?
    public var currentTime: TimeInterval { recorder?.currentTime ?? 0 }

    public override init() {
        super.init()
        #if os(iOS)
        NotificationCenter.default.addObserver(self, selector: #selector(interrupted(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(mediaReset(_:)), name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
        #endif
    }
    deinit { NotificationCenter.default.removeObserver(self) }

    public func requestPermission() async -> Bool {
        #if os(iOS)
        await AVAudioApplication.requestRecordPermission()
        #else
        await AVCaptureDevice.requestAccess(for: .audio)
        #endif
    }
    public func start(at url: URL) throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
        #endif
        let recorder = try AVAudioRecorder(url: url, settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ])
        self.recorder = recorder
        recorder.delegate = self
        guard recorder.prepareToRecord(), recorder.record() else { throw AudioRecordingError.recordingFailed }
    }
    public func stop() {
        recorder?.delegate = nil
        recorder?.stop()
        recorder = nil
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }
    nonisolated public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        let message = error?.localizedDescription ?? "Audio encoding failed. The available recording was retained."
        let identifier = ObjectIdentifier(recorder)
        Task { @MainActor [weak self] in
            guard let self, let current = self.recorder, ObjectIdentifier(current) == identifier else { return }
            self.onInterruption?(message)
        }
    }
    nonisolated public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let identifier = ObjectIdentifier(recorder)
        Task { @MainActor [weak self] in
            guard let self, let current = self.recorder, ObjectIdentifier(current) == identifier else { return }
            self.onInterruption?(flag ? "Audio recording ended." : "Audio recording was interrupted.")
        }
    }
    #if os(iOS)
    @objc private func interrupted(_ notification: Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
        onInterruption?("Audio recording was interrupted. The available recording was retained.")
    }
    @objc private func mediaReset(_ notification: Notification) {
        onInterruption?("The audio system restarted. The available recording was retained.")
    }
    #endif
}
#endif
