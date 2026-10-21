import AVFoundation
import Combine
import Speech

/// Live buffers only: this object never writes an audio file or logs a transcript.
@MainActor
final class SpeechCapture: ObservableObject {
    @Published private(set) var transcript = ""
    @Published private(set) var isListening = false
    @Published private(set) var isProcessing = false
    @Published private(set) var errorMessage: String?
    var onFinished: ((String) -> Void)?
    var onFailure: ((String) -> Void)?

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?
    private var timer: Timer?
    private var completionTimer: Timer?
    private var interruptionObserver: NSObjectProtocol?
    private var captureID = UUID()
    private var active = false
    private var installedTap = false
    private var startedAt = Date()
    private var lastSound: Date?

    init() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let kind = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  kind == AVAudioSession.InterruptionType.began.rawValue else { return }
            Task { @MainActor [weak self] in
                guard let self, self.active else { return }
                self.fail("Recording was interrupted. Review the captured text or record again.")
            }
        }
    }

    deinit {
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
        timer?.invalidate()
        completionTimer?.invalidate()
        recognitionTask?.cancel()
        engine.stop()
        if installedTap { engine.inputNode.removeTap(onBus: 0) }
    }

    /// Call only after the user explicitly taps Record; cancellation also invalidates pending permission replies.
    func start(localeIdentifier: String = "id-ID") async {
        cancel()
        errorMessage = nil
        active = true
        isProcessing = true
        let id = captureID
        let authorization = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard active, captureID == id else { return }
        guard authorization == .authorized else {
            fail("Speech recognition permission is unavailable. Enable it in Settings or type the expense.")
            return
        }
        let microphone = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard active, captureID == id else { return }
        guard microphone else {
            fail("Microphone permission was denied. Enable it in Settings or type the expense.")
            return
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)), recognizer.isAvailable else {
            fail("Speech recognition is unavailable. Check your connection or type the expense.")
            return
        }
        self.recognizer = recognizer
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            // Apple may process recognition online; interpretation of returned text remains local.
            request.requiresOnDeviceRecognition = false
            self.request = request
            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let isFinal = result?.isFinal ?? false
                let failure = error?.localizedDescription
                Task { @MainActor [weak self] in
                    guard let self, self.active, self.captureID == id else { return }
                    if let text { self.transcript = text }
                    if let failure { self.fail("Recognition failed: \(failure). Your captured text is available below.") }
                    else if isFinal { self.deliver() }
                }
            }
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                fail("No microphone input is available. Type the expense or try again.")
                return
            }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                request.append(buffer)
                guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return }
                var energy: Float = 0
                for index in 0..<Int(buffer.frameLength) { energy += samples[index] * samples[index] }
                let decibels = 10 * log10(max(energy / Float(buffer.frameLength), 0.0000000001))
                if decibels > -42 {
                    Task { @MainActor [weak self] in
                        guard let self, self.active, self.captureID == id else { return }
                        self.lastSound = Date()
                    }
                }
            }
            installedTap = true
            engine.prepare()
            try engine.start()
            startedAt = Date()
            lastSound = nil
            isListening = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.isListening else { return }
                    let now = Date()
                    if now.timeIntervalSince(self.startedAt) >= 45 ||
                        (self.lastSound != nil && now.timeIntervalSince(self.lastSound!) >= 1.8) ||
                        (self.lastSound == nil && now.timeIntervalSince(self.startedAt) >= 8) { self.finish() }
                }
            }
        } catch {
            fail("Could not start recording: \(error.localizedDescription). Type the expense or try again.")
        }
    }

    func finish() {
        guard active else { return }
        stopMicrophone()
        request?.endAudio()
        // Allow the recognizer to finalize trailing words, but never leave Done waiting indefinitely.
        completionTimer?.invalidate()
        completionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.active else { return }
                self.fail("Recognition did not finalize. Review your captured text, then retry or save the correction.")
            }
        }
    }

    func cancel() {
        captureID = UUID()
        active = false
        isProcessing = false
        stopMicrophone()
        completionTimer?.invalidate()
        completionTimer = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        request = nil
        recognizer = nil
        transcript = ""
    }

    private func stopMicrophone() {
        timer?.invalidate()
        timer = nil
        engine.stop()
        if installedTap { engine.inputNode.removeTap(onBus: 0); installedTap = false }
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func deliver() {
        guard active else { return }
        let text = transcript
        cancel()
        transcript = text
        onFinished?(text)
    }

    private func fail(_ message: String) {
        let text = transcript
        cancel()
        transcript = text
        errorMessage = message
        onFailure?(message)
    }
}
