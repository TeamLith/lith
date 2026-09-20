import Foundation

@MainActor
public protocol AudioPlaybackDriver: AnyObject {
    var isPlaying: Bool { get }
    var currentTime: TimeInterval { get }
    func play(url: URL) throws
    func pause()
    func stop()
}

#if canImport(AVFoundation)
@preconcurrency import AVFoundation

@MainActor
public final class AppleAudioPlaybackDriver: AudioPlaybackDriver {
    private var player: AVAudioPlayer?
    private var currentURL: URL?
    public init() {}
    public var isPlaying: Bool { player?.isPlaying ?? false }
    public var currentTime: TimeInterval { player?.currentTime ?? 0 }
    public func play(url: URL) throws {
        #if os(iOS)
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try AVAudioSession.sharedInstance().setActive(true)
        #endif
        if currentURL != url || player == nil {
            player = try AVAudioPlayer(contentsOf: url)
            currentURL = url
        }
        guard player?.play() == true else { throw AudioRecordingError.recordingFailed }
    }
    public func pause() { player?.pause() }
    public func stop() {
        player?.stop()
        player = nil
        currentURL = nil
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }
}
#endif
