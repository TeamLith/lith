#if canImport(Speech)
@preconcurrency import Speech
import Foundation

@MainActor
public final class AppleSpeechTranscriptionDriver: SpeechTranscriptionDriver {
    private let locale: Locale
    public init(locale: Locale = .current) { self.locale = locale }

    public func updates(for fileURL: URL) async throws -> AsyncThrowingStream<TranscriptionUpdate, Error> {
        let authorization = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        try Task.checkCancellation()
        guard authorization == .authorized else { throw TranscriptionError.permissionDenied }
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.supportsOnDeviceRecognition else {
            throw TranscriptionError.onDeviceUnavailable
        }
        guard recognizer.isAvailable else { throw TranscriptionError.serviceUnavailable }
        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        let (stream, continuation) = AsyncThrowingStream<TranscriptionUpdate, Error>.makeStream()
        let session = SpeechRecognitionSession(continuation: continuation)
        continuation.onTermination = { @Sendable _ in
            Task { @MainActor in session.cancel() }
        }
        session.start(recognizer: recognizer, request: request)
        return stream
    }
}

@MainActor
private final class SpeechRecognitionSession {
    private var task: SFSpeechRecognitionTask?
    private let continuation: AsyncThrowingStream<TranscriptionUpdate, Error>.Continuation
    private var finished = false
    init(continuation: AsyncThrowingStream<TranscriptionUpdate, Error>.Continuation) { self.continuation = continuation }
    func start(recognizer: SFSpeechRecognizer, request: SFSpeechURLRecognitionRequest) {
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let update = result.map { TranscriptionUpdate(text: $0.bestTranscription.formattedString, isFinal: $0.isFinal) }
            Task { @MainActor in
                guard let self, !self.finished else { return }
                if let update {
                    self.continuation.yield(update)
                    if update.isFinal {
                        self.finished = true
                        self.continuation.finish()
                        self.task = nil
                        return
                    }
                }
                if let error {
                    self.finished = true
                    self.continuation.finish(throwing: error)
                    self.task = nil
                }
            }
        }
    }
    func cancel() {
        finished = true
        task?.cancel()
        task = nil
    }
}
#endif
