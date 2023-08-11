import SwiftUI

struct PrivacySettingsView: View {
    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "Unknown Version"
    }

    var body: some View {
        VStack {
            Text("Typing Pall")
                .font(.title)
                .padding(.bottom)

            Image("SettingIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .cornerRadius(20)
                .padding()

            Text("App Version: \(appVersion)")

            Text("Original Created by Mier (Mieraidihaim Mieraisan)")
        }
        .padding()
    }
}

struct PrivacySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AppearanceSettingsView()
    }
}
