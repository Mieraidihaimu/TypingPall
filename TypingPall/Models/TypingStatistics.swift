import Foundation
import Combine

/// Accuracy describes the current input; WPM uses correct characters / 5.
/// A monotonic clock avoids changes caused by wall-clock adjustments.
final class TypingStatistics: ObservableObject {
    @Published private(set) var wpm = 0.0
    @Published private(set) var accuracy = 100.0
    @Published private(set) var errorCount = 0
    @Published private(set) var correctCharacters = 0
    @Published private(set) var timeElapsed: TimeInterval = 0
    @Published private(set) var isActive = false
    @Published private(set) var isComplete = false
    private var startTime: TimeInterval?
    private var accumulatedTime: TimeInterval = 0
    private var timer: Timer?
    private let now: () -> TimeInterval

    init(now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.now = now
    }

    deinit { timer?.invalidate() }

    func update(typedText: String, targetText: String) {
        guard !isComplete else { return }
        if !typedText.isEmpty && !isActive { resume() }
        correctCharacters = zip(typedText, targetText).reduce(0) { $0 + ($1.0 == $1.1 ? 1 : 0) }
        errorCount = typedText.count - correctCharacters
        accuracy = typedText.isEmpty ? 100 : Double(correctCharacters) / Double(typedText.count) * 100
        tick()
        if !targetText.isEmpty && typedText == targetText {
            pause()
            isComplete = true
        }
    }

    func resume() {
        guard !isActive, !isComplete else { return }
        startTime = now()
        isActive = true
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func pause() {
        tick()
        accumulatedTime = timeElapsed
        startTime = nil
        isActive = false
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        pause()
        accumulatedTime = 0
        timeElapsed = 0
        wpm = 0
        accuracy = 100
        errorCount = 0
        correctCharacters = 0
        isComplete = false
    }

    private func tick() {
        if let startTime { timeElapsed = accumulatedTime + max(0, now() - startTime) }
        wpm = timeElapsed > 0 ? Double(correctCharacters) / 5 * 60 / timeElapsed : 0
    }

    var formattedTime: String {
        String(format: "%02d:%02d", Int(timeElapsed) / 60, Int(timeElapsed) % 60)
    }
}
