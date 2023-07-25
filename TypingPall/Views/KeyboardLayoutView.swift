import SwiftUI

struct KeyboardLayoutView: View {
    @Binding var typedLetter: String?

    private let rows = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="],
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L", ";", "'"],
        ["Z", "X", "C", "V", "B", "N", "M", ",", ".", "/"]
    ]

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            ForEach(rows, id: \.self) { row in
                HStack {
                    ForEach(row, id: \.self) { key in
                        Text(key)
                            .frame(width: 46, height: 46)
                            .background(key == typedLetter?.uppercased() ? Color.blue : Color.gray.opacity(0.2))
                            .cornerRadius(6)
                            .padding(1)
                    }
                }
                .padding(.horizontal, Double(rows.firstIndex(of: row) ?? 0) * 8.0)
            }
        }
        .padding()
    }
}

struct KeyboardLayoutView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            KeyboardLayoutView(typedLetter: .constant("k")).frame(width: 600, height: 400)

            KeyboardLayoutView(typedLetter: .constant("k")).frame(width: 800, height: 600)
        }
    }
}
