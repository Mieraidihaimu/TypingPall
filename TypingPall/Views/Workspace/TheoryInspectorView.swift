import SwiftUI

struct TheoryInspectorView: View {
    @ObservedObject var viewModel: TypingScreenViewModel
    @ObservedObject var masteryStore = MasteryStore.shared

    init(viewModel: TypingScreenViewModel) {
        self.viewModel = viewModel
    }

    private var currentLesson: PracticeLesson? { viewModel.currentLesson }
    private var lessonID: String { viewModel.currentLessonID ?? viewModel.placeholderText }
    private var record: MasteryRecord { masteryStore.record(for: lessonID) }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header & Mastery Badge
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(viewModel.lessonTitle)
                            .font(.title3)
                            .fontWeight(.bold)
                            .lineLimit(2)

                        Spacer()

                        TriRingMasteryGlyph(level: record.level, isDueForRecall: record.isDueForRecall, size: 22)
                    }

                    Text(viewModel.lessonSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 4)

                Divider()

                // Mastery Status & Retention Telemetry
                VStack(alignment: .leading, spacing: 8) {
                    Text("MASTERY STATUS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Current Stage")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(record.level.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(record.level.color)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Recall Stability")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(Int(record.stability)) days")
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .padding(10)
                    .background(TypingPalette.activeLine.opacity(0.5))
                    .cornerRadius(8)

                    if let nextDate = record.nextReviewDate {
                        HStack(spacing: 6) {
                            Image(systemName: record.isDueForRecall ? "exclamationmark.triangle.fill" : "calendar")
                                .foregroundColor(record.isDueForRecall ? .orange : .secondary)
                                .font(.caption)

                            Text(record.isDueForRecall ? "Review due now for retention" : "Next review: \(nextDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption2)
                                .foregroundColor(record.isDueForRecall ? .orange : .secondary)
                        }
                    }
                }

                Divider()

                // Contextual Lesson Notes
                if let lesson = currentLesson {
                    // Invariant Cue Callout
                    if let invariant = lesson.invariant {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("INVARIANT CUE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)

                            HStack(alignment: .top, spacing: 8) {
                                Rectangle()
                                    .fill(Color.accentColor)
                                    .frame(width: 3)
                                Text(invariant)
                                    .font(.system(size: 13, weight: .regular))
                                    .lineSpacing(3)
                            }
                            .padding(10)
                            .background(Color.accentColor.opacity(0.06))
                            .cornerRadius(6)
                        }
                    }

                    // Problem Anchors
                    if let anchors = lesson.anchors, !anchors.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("PROBLEM ANCHORS")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)

                            ForEach(anchors, id: \.name) { anchor in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(anchor.name).font(.system(size: 12, weight: .semibold))
                                    Text(anchor.trick).font(.system(size: 11)).foregroundColor(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    // Retrieval Triggers
                    if let triggers = lesson.triggers, !triggers.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("RETRIEVAL TRIGGERS")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)

                            ForEach(triggers, id: \.self) { trigger in
                                Text("• \(trigger)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Template (with spoiler blur in Recall mode!)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("CODE TEMPLATE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            if viewModel.mode.isGraded {
                                Label("Hidden in \(viewModel.mode.title)", systemImage: "eye.slash")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if viewModel.mode == .recall {
                            ZStack {
                                Text(lesson.code)
                                    .font(.system(size: 11, design: .monospaced))
                                    .blur(radius: 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)

                                Text("Recall from memory\n(Press ⌘' for hint)")
                                    .multilineTextAlignment(.center)
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                            }
                            .background(TypingPalette.activeLine.opacity(0.3))
                            .cornerRadius(8)
                        } else {
                            Text(lesson.code)
                                .font(.system(size: 11, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(TypingPalette.activeLine.opacity(0.3))
                                .cornerRadius(8)
                                .textSelection(.enabled)
                        }
                    }

                    // Pitfalls
                    if let pitfalls = lesson.pitfalls, !pitfalls.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("COMMON PITFALLS")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)

                            ForEach(pitfalls, id: \.self) { pitfall in
                                Text("⚠️ \(pitfall)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Mantra
                    if let mantra = lesson.mantra {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("TWIN MANTRA")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)

                            Text("“\(mantra)”")
                                .font(.system(size: 13, weight: .medium, design: .serif))
                                .italic()
                                .foregroundColor(Color.accentColor)
                                .padding(10)
                                .background(Color.accentColor.opacity(0.08))
                                .cornerRadius(6)
                        }
                    }
                }
            }
            .padding(16)
        }
        // The split-view host owns sizing; scroll content must not change its bounds.
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .inspectorColumnWidth(min: 280, ideal: 300, max: 340)
        .accessibilityIdentifier("theoryInspector")
    }
}
