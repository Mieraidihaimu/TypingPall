cask "typingpall" do
  version "1.3.0"
  sha256 "89b383801b1156a62a93df150127aa41dbf568a521d0f73d77431e2b848ee864"

  url "https://github.com/Mieraidihaimu/TypingPall/releases/download/v#{version}/TypingPall-v#{version}-arm64.zip"
  name "TypingPall"
  desc "Make code patterns familiar, one line at a time"
  homepage "https://typingpall.pages.dev/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "TypingPall.app"

  zap trash: [
    "~/Library/Application Support/TypingPall",
    "~/Library/Caches/com.mier.TypingPall",
    "~/Library/Preferences/com.mier.TypingPall.plist",
  ]
end
