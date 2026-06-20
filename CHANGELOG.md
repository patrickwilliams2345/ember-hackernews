# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-06-20

### Added
- Mac and large-iPad support via Mac Catalyst, with an adaptive three-pane layout (sidebar, story list, discussion) on regular-width windows.
- Offline reading: a bounded JSON disk cache for feed lists, story items, and comment trees, served automatically as a fallback when offline. Cache size and a clear action are in Settings.
- Reading typography set in the bundled Inter font, scaled with Dynamic Type, with comfortable leading and a constrained reading measure.
- A dedicated share button in the story toolbar (article or discussion link).

### Changed
- Higher-contrast metadata text and more generous spacing in Settings and the feed.
- Compact, branded feed header that reclaims vertical space.

## [1.0.0] - 2026-06-20

### Added
- Story feeds: Top, New, Best, Ask HN, Show HN, and Jobs with a pinned filter bar, pull-to-refresh, and pagination.
- Story detail with a native-rendered comment thread: collapsible threads, depth indicators, tappable links, quotes, and code blocks, loaded in a single Algolia request.
- Full-text search across Hacker News by relevance or recency.
- Saved stories with on-device persistence and offline access.
- Read-state tracking that dims visited stories.
- In-app Safari reader with optional Reader mode, or system-browser hand-off.
- User profiles with karma, join date, about, and recent submissions.
- Smart first-run onboarding that detects device appearance and accessibility settings, pre-configures the app, and previews choices live.
- Accessibility: color-independent status cues, VoiceOver labels and custom actions, Dynamic Type, Reduce Motion support, and underlined links.
- Six accent themes, full light/dark support, haptics, and a generated app icon.

[1.1.0]: https://github.com/DatanoiseTV/ember-hackernews/releases/tag/v1.1.0
[1.0.0]: https://github.com/DatanoiseTV/ember-hackernews/releases/tag/v1.0.0
