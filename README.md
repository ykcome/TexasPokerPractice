# TexasPoker (Training App)

TexasPoker is an educational poker training and study app built with SwiftUI. It focuses on learning and practice (rules, hand evaluation, probabilities, ranges, and training scenarios) and is **not** a real-money gambling app.

## What this project is (and isn’t)

- **No real-money gambling**: no deposits, withdrawals, payouts, or betting with real currency.
- **Training-first**: designed for practicing decision-making and studying poker fundamentals.
- **Offline-friendly**: core features work locally; bundled reference tables are shipped as JSON resources.

## Features

- Practice mode with an in-app “tournament” flow and action selection (check/call/raise/fold).
- Hand evaluation utilities and rule-based tests.
- Player profile with statistics and learning utilities.
- Built-in **Probability / Range Charts**:
  - `Resources/RangeCharts.json` contains 13 reference charts (including a 13×13 beginner preflop range matrix).
  - Charts are rendered as structured tables in-app, with localized headers and optional English row translations.

## Project structure

- `Sources/App` – app entry and main tabs
- `Sources/UI/Views` – SwiftUI views (game UI, profile, charts)
- `Sources/GameLogic` – gameplay flow, betting manager, coach engine, exporting utilities
- `Sources/Models` – cards, players, game state
- `Resources` – bundled JSON reference data and asset catalog
- `Tools/gto-tablegen` – optional Rust tool used to generate GTO-related JSON tables
- `Tests` – unit and integration tests

## Requirements

- Xcode (recent version recommended)
- iOS Simulator / device (project currently targets iOS 16+)
- macOS for development

## Build & run

1. Open `TexasPoker.xcodeproj` in Xcode.
2. Select the `TexasPoker` scheme.
3. Run on an iOS Simulator (or a connected device).

To run tests:

- In Xcode: Product → Test

## Data files

- `Resources/RangeCharts.json` – probability tables and range matrix configuration
- `Resources/gto_clusters_srp_btn_bb.json` – example bundled GTO cluster table (optional for training features)

## Notes for App Review / compliance

This repository is published as an educational/training tool and does not provide gambling services. If you build and distribute your own fork, you are responsible for:

- accurate age rating / metadata in your distribution channels
- legal compliance in regions where the app is available

## Contributing

Issues and pull requests are welcome. If you’re submitting a PR:

- keep changes focused and well-tested
- avoid committing secrets or keys
- prefer updating chart data via `Resources/RangeCharts.json` when possible

## License

Apache License 2.0. See [LICENSE](LICENSE).
