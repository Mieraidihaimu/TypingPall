cask "typingpall" do
  version "1.2.1"
  sha256 "05e8480d2c8a6a6f33e79e11cfaeff96321223cd2dc72046c65185ac7418c29d"

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
