# Vitreous

High-performance Emby media client for Linux, Android, iOS, macOS, Windows, and tvOS. Fork of [Plezy](https://github.com/edde746/plezy). Repo: [dragged9698/Vitreous](https://github.com/dragged9698/Vitreous).

## Setup

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
