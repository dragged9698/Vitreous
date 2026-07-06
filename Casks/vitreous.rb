cask "vitreous" do
  version "2.8.0"
  sha256 "78df0227fc9a578c259fa7cdda526a2679fe46f5be6620f7a020e18d08f206f5"

  url "https://github.com/dragged9698/Vitreous/releases/download/#{version}/vitreous-macos.dmg"
  name "Vitreous"
  desc "Modern Plex and Jellyfin client built with Flutter"
  homepage "https://github.com/dragged9698/Vitreous"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true

  app "Vitreous.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/Vitreous.app"],
                   sudo: false
  end

  uninstall quit: "com.dragged9698.vitreous"

  zap trash: [
    "~/Library/Application Support/com.dragged9698.vitreous",
    "~/Library/Caches/com.dragged9698.vitreous",
    "~/Library/HTTPStorages/com.dragged9698.vitreous",
    "~/Library/Preferences/com.dragged9698.vitreous.plist",
    "~/Library/Saved Application State/com.dragged9698.vitreous.savedState",
    "~/Library/WebKit/com.dragged9698.vitreous",
  ]
end
