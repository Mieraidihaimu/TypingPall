import SwiftUI

struct ReferenceRow: Identifiable, Equatable {
    enum Marker: Equatable { case neededSecondLook, notTheBug, plantedBug, differs }
    let sourceIndex: Int
    let text: String
    var isCurrent = false
    var isSkipped = false
    var isMasked = false
    var marker: Marker? = nil
    var id: Int { sourceIndex }
}

struct ReferenceCodeView: View {
    let rows: [ReferenceRow]
    let fontSize: Double          // the typing size; rows draw at referenceFontSize(for:)
    let currentIndex: Int
    let contentKey: String        // changes when a new pattern loads → scroll to top
    var onSelectRow: ((Int) -> Void)? = nil
    var minHeight: CGFloat = 180

    static func referenceFontSize(for typingSize: Double) -> Double { min(22, max(11, (typingSize * 0.7).rounded())) }

    static func split(_ line: String) -> (indent: String, code: String) {
        let indent = line.prefix { $0 == " " || $0 == "\t" }
        return (String(indent), String(line.dropFirst(indent.count)))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(rows) { row in
                        Group {
                            if let onSelectRow {
                                Button { onSelectRow(row.sourceIndex) } label: { content(of: row) }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("referenceLine\(row.sourceIndex)")
                            } else {
                                content(of: row).accessibilityElement(children: .ignore)
                            }
                        }
                        .accessibilityLabel(spokenLabel(for: row))
                        .id(row.sourceIndex)
                    }
                }.padding(.vertical, 12)
            }
            .onChange(of: currentIndex) { index in
                withAnimation { proxy.scrollTo(index, anchor: .center) }
            }
            .onChange(of: contentKey) { _ in proxy.scrollTo(currentIndex, anchor: .top) }
        }
        .frame(minHeight: minHeight, idealHeight: 300)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func content(of row: ReferenceRow) -> some View {
        let line = Self.split(row.text), code = Text(line.code.isEmpty ? " " : line.code)
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(row.sourceIndex + 1)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .trailing)
            Text(glyph(for: row))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 14)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(line.indent)
                (row.isSkipped ? code.italic() : code)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.system(size: Self.referenceFontSize(for: fontSize), design: .monospaced))
        }
        .foregroundColor(row.isSkipped || row.isMasked ? .secondary : .primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(row.isCurrent ? Color.accentColor.opacity(0.15) : Color.clear)
        .overlay(alignment: .leading) {
            if row.isCurrent { Rectangle().fill(Color.accentColor).frame(width: 3) }
        }
        .contentShape(Rectangle())
    }

    private func glyph(for row: ReferenceRow) -> String {
        switch row.marker {
        case .neededSecondLook?: return "•"
        case .notTheBug?: return "○"
        case .plantedBug?: return "✕"
        case .differs?: return "≠"
        case nil: return row.isSkipped ? "⤼" : ""
        }
    }

    private func spokenLabel(for row: ReferenceRow) -> String {
        var parts = ["Line \(row.sourceIndex + 1)"]
        if row.isCurrent { parts.append("current line") }
        switch row.marker {
        case .neededSecondLook?: parts.append("needed a second look")
        case .notTheBug?: parts.append("not the bug")
        case .plantedBug?: parts.append("the bug")
        case .differs?: parts.append("differs")
        case nil: if row.isSkipped { parts.append("skipped") }
        }
        guard row.isMasked else { return parts.joined(separator: ", ") + ": " + row.text }
        let revealed = row.text.filter { $0 != "━" }.trimmingCharacters(in: .whitespaces)
        parts.append(revealed.isEmpty ? "hidden" : "hint: \(revealed)")
        return parts.joined(separator: ", ")
    }
}
