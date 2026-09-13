import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("typingFontSize") var typingFontSize: Double = 25.0
    @AppStorage("isShowingKeyboard") var isShowingKeyboard = false
    @AppStorage("tabEqualsToSpaces") var spaces: Double = 4

    private var safeFontSize: Double {
        typingFontSize.isFinite ? min(30, max(12, typingFontSize)) : 25
    }

    var body: some View {
        Form {
            Toggle("Show virtual Keyboard", isOn: $isShowingKeyboard)
                .padding(.bottom)

            Slider(value: $typingFontSize, in: 12...30, step: 1.0, label: {
                VStack {
                    Text("\(Int(safeFontSize))")
                    Text("Typing Font size")
                }
            })

            Slider(value: $spaces, in: 2...4, step: 2.0) {
                VStack {
                    Text("\(PracticeText.tabWidth(spaces))")
                    Text("Tabs equal to \(PracticeText.tabWidth(spaces)) Spaces")
                }
            }

            Spacer()
        }
        .padding()
        .onAppear {
            typingFontSize = safeFontSize
            spaces = spaces == 2 ? 2 : 4
        }
    }
}

struct AppearanceSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AppearanceSettingsView()
    }
}
