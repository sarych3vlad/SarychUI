# Changelog

## 1.0.5 - 2026-05-10

Release-ready embedded build for Equipence 1.0.

### Added
- Standalone `Aegis-Settings-1.0` LibStub library.
- Schema-driven settings controls for checkboxes, sliders, buttons, dropdowns, headers, descriptions, sections, and compact control groups.
- Runtime floating panel, InterfaceOptions fallback panel, and modern Settings registration bridge.
- XML templates for panel shells, sections, descriptions, sliders, buttons, dropdowns, and dropdown lines.
- Host-owned localization, saved data, metadata, defaults, slash commands, and apply handlers.

### Changed
- Former addon local Options code is now an engine independent embedded settings library.
- Addon specific definitions and display scope values stay outside the library.
- Labels, tooltips, and dropdown entries are localized once through schema control info before rendering or registration.
- XML owns stable structure while Lua owns branch specific behavior and compatibility.

### Fixed
- Runtime checkbox changes persist correctly on Legacy clients.
- InterfaceOptions and runtime controls no longer collide through shared widget names.
- Slider row layout clears stale points and uses `inlineLayout` for compact horizontal presentation.
- Retail XML parser compatibility is preserved by keeping backdrop data Lua-owned.
