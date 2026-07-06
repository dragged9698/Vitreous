# Vitreous

High-performance Emby media client for Linux, Android, iOS, macOS, Windows, and tvOS. Fork of [Plezy](https://github.com/edde746/plezy). Repo: [dragged9698/Vitreous](https://github.com/dragged9698/Vitreous).

## Features

### Browse & Discover
- Libraries, collections, and playlists
- Discover hub — Continue Watching, Next Up, trending, and recommendations
- Cross-server search
- Filtering, sorting, and alphabetical jump navigation
- Extras — trailers, deleted scenes, behind-the-scenes

### Playback
- Wide codec support (HEVC, AV1, VP9, and more)
- HDR and Dolby Vision[^1]
- Full ASS/SSA subtitles with customizable styling
- Online subtitle search & download[^2]
- Audio & subtitle choices remembered per title
- Progress sync and resume
- Auto-play next episode with skip intro / skip credits
- Chapter navigation with thumbnail scrub previews
- Playback speed, audio sync offset, sleep timer
- Ambient lighting and GLSL shader presets[^3]
- Picture-in-Picture[^4]
- Refresh-rate matching[^5]
- External player launch (VLC, MX Player, etc.)

### Live TV & DVR
- Live TV channel browsing with favorites
- DVR support with EPG guide, recording rules, and scheduled recordings[^2]
- Multi-server Live TV support where available

### Downloads & Offline
- Download media for offline viewing
- Background queue with pause / resume
- Sync rules for automatic downloads
- Offline browsing with watch state sync-back on reconnect

### Watch Together
- Synchronized playback with friends
- Real-time play / pause / seek sync

### Integrations
- Discord Rich Presence[^6]
- Trakt, MyAnimeList, AniList, and Simkl tracking & rating
- Vitreous Remote — control desktop and TV from mobile
- Watch Next row

### Platform & Customization
- Desktop, mobile, and TV — full D-pad, keyboard, and gamepad support
- Customizable keyboard shortcuts[^6]
- Metadata and artwork editing
- Settings import/export
- Localized in English plus 14 translations

[^1]: Not available on Linux.
[^2]: Plex only.
[^3]: Not available on iOS or tvOS.
[^4]: Android, iOS, and macOS.
[^5]: Windows, Android, and tvOS.
[^6]: Desktop only.

## Building from Source

### Prerequisites
- Flutter SDK 3.38.4+
- An Emby server with user credentials (Jellyfin/Plex legacy paths may still exist during migration)

### Setup

```bash
flutter pub get
cd packages/emby_core && dart pub get
scripts/codegen.sh
flutter run -d linux
```

## Emby API smoke test (no UI)

```bash
cd packages/emby_core
EMBY_SERVER_URL=http://localhost:8096 EMBY_USERNAME=user EMBY_PASSWORD=pass dart run tool/smoke.dart
```

## Integration tests

```bash
cd packages/emby_core
EMBY_SERVER_URL=... EMBY_USERNAME=... EMBY_PASSWORD=... dart test test/integration/emby_live_server_test.dart
```

## Architecture

- `packages/emby_core/` — standalone Emby REST client (auth, DTOs, repositories)
- `lib/services/emby_client.dart` — Vitreous `MediaServerClient` implementation
- `lib/domain/media_data_source.dart` — UI-facing repository abstraction
- `lib/data/emby_media_data_source.dart` — adapter over `EmbyClient`
