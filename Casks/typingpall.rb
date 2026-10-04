cask "typingpall" do
  version "1.1.0"
  sha256 "6a5d49646b6e407704e60f98eaa75ec0ff1f33d732ef6cc378295818bc495b96"

  url "https://github.com/Mieraidihaimu/TypingPall/releases/download/v#{version}/TypingPall-v#{version}.zip"
  name "TypingPall"
  desc "Make code patterns familiar, one line at a time"
  homepage "https://typingpall.pages.dev/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :monterey"

  app "TypingPall.app"

  zap trash: [
    "~/Library/Application Support/TypingPall",
    "~/Library/Caches/com.mier.TypingPall",
    "~/Library/Preferences/com.mier.TypingPall.plist",
  ]
end
