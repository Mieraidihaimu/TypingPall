import SwiftUI

struct TypingStatisticsView: View {
    @ObservedObject var statistics: TypingStatistics

    var body: some View {
        HStack(spacing: 32) {
            metric("WPM", value: String(format: "%.0f", statistics.wpm))
            metric("Accuracy", value: String(format: "%.0f%%", statistics.accuracy))
            metric("Errors", value: "\(statistics.errorCount)")
            metric("Time", value: statistics.formattedTime)
            Spacer()
            Label(statistics.isComplete ? "Practice complete" : statistics.isActive ? "In progress" : "Ready when you are",
                  systemImage: statistics.isComplete ? "checkmark.circle.fill" : "keyboard")
                .foregroundColor(statistics.isComplete ? .green : .secondary)
                .accessibilityIdentifier("sessionStatus")
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.system(.title2, design: .monospaced)).monospacedDigit()
            Text(title).font(.caption).foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
