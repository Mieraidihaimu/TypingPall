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

            Text("Created by Mier")
            Text("Your scripts stay on this Mac. TypingPall has no analytics, accounts, or network requests. Delete saved scripts from the Library.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct PrivacySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AppearanceSettingsView()
    }
}
