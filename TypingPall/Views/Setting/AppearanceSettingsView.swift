import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("typingFontSize") var typingFontSize: Double = 25.0
    @AppStorage("isShowingKeyboard") var isShowingKeyboard = false

    var body: some View {
        Form {
            Toggle("Show virtual Keyboard", isOn: $isShowingKeyboard)
                .padding(.bottom)

            Slider(value: $typingFontSize, in: 12...30, step: 1.0, label: {
                VStack {
                    Text("\(Int(typingFontSize))")
                    Text("Typing Font size")
                }
            })

            Spacer()
        }
        .padding()
    }
}

struct AppearanceSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AppearanceSettingsView()
    }
}
