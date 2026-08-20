# CLAUDE.md — WCinfo iOS Project

## Project Overview
- **App name:** WCinfo
- **Platform:** iOS 17+
- **Language:** Swift 5.9
- **UI Framework:** SwiftUI
- **Dependency Manager:** Swift Package Manager (SPM)
- **Project Generator:** XcodeGen (`WCinfo/project.yml`)
- **Bundle ID:** `de.wcinfo.app`

## Purpose
Minimal native iOS app to search nearby public toilets via the existing WC-Info REST API (`https://api2.wc-info.de`).

## Key Dependencies
- `GoogleMaps` (ios-maps-sdk) — embedded Google Map on the results screen
- `GooglePlaces` (ios-places-sdk) — autocomplete and place coordinate lookup on the home screen

Both are declared in `WCinfo/project.yml`.

## Build & Run
1. Generate the Xcode project:
   ```bash
   cd WCinfo
   xcodegen generate
   ```
2. Open `WCinfo/WCinfo.xcodeproj` in Xcode, or build from the command line:
   ```bash
   xcodebuild -project WCinfo/WCinfo.xcodeproj -scheme WCinfo -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' build
   ```
   The available simulator names vary; use `xcodebuild -scheme WCinfo -showdestinations` to list them.

## Secrets & Configuration
- Google API key is stored in `WCinfo/WCinfo/Resources/Config.plist` under `GoogleAPIKey`.
- This file is listed in `.gitignore` and must never be committed.
- The key is loaded at app launch in `WCinfo/WCinfo/WCinfoApp.swift` via `Config.googleAPIKey`.

## Architecture
- `WCinfoApp.swift` — app entry point, provides Google API keys.
- `Models/Toilet.swift` — WC-Info API response models (`Toilet`, `ToiletListItem`, `SearchedLocation`).
- `Services/`
  - `WCInfoAPIService.swift` — URLSession wrapper for WC-Info endpoints.
  - `PlacesService.swift` — Google Places autocomplete + coordinate lookup.
  - `LocationManager.swift` — CLLocation permission and one-shot location requests.
- `Views/`
  - `HomeView.swift` — search input with autocomplete, search & "near me" buttons.
  - `ResultsView.swift` — split list/map screen.
  - `ResizableSplit.swift` — custom draggable split layout.
  - `MapView.swift` — `GMSMapView` wrapper showing markers.
  - `ToiletRowView.swift` — row view for the results list.

## API Endpoints Used
- `GET /toilets/nearby/{lat}/{lon}?distance={km}` — returns `[Toilet]`.
- `GET /toilets/bounds/{south}/{west}/{north}/{east}` — returns `[ToiletListItem]` (currently wired but not heavily used).

The API returns numeric values for `id`, `nr`, `lat`, `lon`; `source` may be `null`; `place_types` may be an array of strings. The decoder handles all of these flexibly.

## UI Notes
- Home screen uses a lavender background image (`lavendel`) and a white template logo (`logo`).
- Results screen uses a vertical split in portrait and horizontal split in landscape; the split ratio is draggable.
- Default ratios: portrait list ~2/3, landscape list ~1/2.

## Git Commit Convention
Prefix commit messages with one of:
- `fix:` — bug fixes
- `feat:` — new features or significant UI additions
- `chore:` — tooling, config, project generation, dependency updates, docs

## Common Issues
- If `xcodebuild` fails because the destination is unavailable, query simulators and pick an existing one.
- If the Google Map shows blank tiles, verify the API key has the iOS Maps SDK enabled and the bundle identifier `de.wcinfo.app` is allowed in the Google Cloud Console.
- If WC-Info decoding fails, check the API response format; the decoder expects either string or number for numeric fields.

## Asset Requirements
- `lavendel` and `logo` must exist in `WCinfo/WCinfo/Assets.xcassets`.
- `Config.plist` must be created manually in `WCinfo/WCinfo/Resources/` with a valid `GoogleAPIKey` before building.
