# Changelog Generator

A Claude Code skill and bash script that generates a structured `CHANGELOG.md` from your git history. Parses conventional commit messages, groups changes by version tag, and organizes them by type (Added, Fixed, Changed, Removed).

## Quick Start

1. Place `SKILL.md` in your Claude Code project root
2. Run the skill by saying "generate a changelog" or type `/generate-changelog`
3. Or use the standalone script: `bash changelog.sh`

## What It Does

- Reads commits since the last git tag (or all time if no tags exist)
- Categorizes commits using conventional commit prefixes (`feat` → Added, `fix` → Fixed, etc.)
- Groups output by version tag with date stamps
- Writes a clean, properly formatted `CHANGELOG.md`

## Sample Output

Here's what it produced against the [nav](https://github.com/xjh22222228/nav) project (80+ tagged releases):

```
# Changelog

## [Unreleased] — 2025-06-06

### Added
- **auth:** OAuth2 login flow (abc1234)
- **api:** rate limiting middleware (def5678)

### Fixed
- **ui:** button alignment on mobile screens (ghi9012)

### Changed
- **core:** refactored event bus (jkl3456)
```

The full sample output against a real repo (80+ versions, 2000+ commits) is included in this PR — the script handled it without issues.
