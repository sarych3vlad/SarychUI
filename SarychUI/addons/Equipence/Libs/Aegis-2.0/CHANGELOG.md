# Changelog

## 2.0.2 - 2026-05-10

Release-ready embedded build for Equipence 1.0.

### Added
- Retail-shaped compatibility namespaces used by Equipence: `C_Item`, `C_Spell`, `C_TooltipInfo`, `C_Texture`, `Enum`, `FlagsUtil`, `LinkUtil`, `TooltipUtil`, and `TextureUtil`.
- Legacy-safe item loading, tooltip scanning, atlas lookup, global string fallback, and namespace trust services.
- Object API compatibility layer for `Item` and `ItemLocation`.

### Changed
- Native namespace usage is filtered through explicit environment trust rules.
- Tooltip fallback data is normalized toward Retail `TooltipData` semantics where practical.
- Texture-kit setup routes through Aegis atlas handling for Classic and Legacy clients.

### Fixed
- Reduced unsafe global fallback exposure in taint sensitive paths.
- Fixed legacy item data loading edge cases used by inspect and socket extraction.
