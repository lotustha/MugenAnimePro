# anime_stream

A Flutter anime streaming app powered by the Cooren API (`anizen` provider).

## Features

- **Home** — spotlight hero carousel + recently-updated grid
- **Search** — debounced, paginated (infinite scroll)
- **Detail** — synopsis, genres, episode list, SUB/DUB toggle, related & recommended rails, favorite ❤️
- **Player** — HLS playback via `media_kit` with the required `Referer` header, external subtitles, skip intro/outro, next/previous episode, resume-from-position
- **Library** — favorites + continue-watching, persisted locally

## Stack

| Concern | Package |
|---|---|
| State / routing / DI | `get` (GetX) |
| Local storage | `get_storage` |
| HTTP | `dio` |
| Video (HLS) | `media_kit` + `media_kit_video` |
| Images | `cached_network_image` |

## Architecture

GetX feature-first layout under `lib/app/`:

```
core/        constants (API endpoints), theme, DI binding
data/        models, providers (Dio ApiClient), repositories, services (GetStorage)
modules/     root, home, search, detail, player, library  (each: controller + view + binding)
routes/      app_pages, app_routes
widgets/     shared UI (anime_card, poster_image, section_header, state_views)
```

## API (Cooren / anizen, base `https://api.mugenstream.fun`)

- `GET /anime/anizen/spotlight`
- `GET /anime/anizen/recent-episodes?page=N`
- `GET /anime/anizen/search/{query}?page=N`
- `GET /anime/anizen/info/{id}`
- `GET /anime/anizen/watch/{episodeId}` — `episodeId` contains `$`/`=` and is URL-encoded by the client

## Running

```bash
flutter pub get
flutter run            # pick a device
```

Verify the data layer headlessly (no GUI/toolchain needed):

```bash
dart run tool/api_smoke.dart
```

> **Note:** Streams require a `Referer` header, so playback works on
> mobile/desktop targets, not in browsers (which forbid that header + enforce CORS).
> The Windows desktop build needs the Visual Studio "Desktop development with C++"
> workload installed.
