cask "typingpall" do
  version "1.2.0"
  sha256 "708e9d33b5cf0cfa8749936833117571185d3a730e07926e65fb1830a03791b3"

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
