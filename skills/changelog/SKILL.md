---
name: generate-changelog
description: Generate a structured CHANGELOG.md from git history, grouped by version tags and organized by type
trigger: the user asks to generate, update, or create a changelog, or types /generate-changelog
---

# Generate a Structured CHANGELOG

When asked to generate a changelog, pull the repository's git history, parse conventional commit messages, and produce a clean CHANGELOG.md organized by version and type.

## Steps

### 1. Check for existing CHANGELOG.md

If one already exists, ask the user: want me to regenerate from scratch or append the latest version?

### 2. Gather git history and tags

```
git log --oneline --format="%ad||%h||%s" --date=short --all
```

Also grab version tags (sorted newest first):

```
git tag --sort=-v:refname
```

### 3. Map conventional commits to changelog categories

| Commit Prefix | Changelog Category |
|---|---|
| `feat` | **Added** |
| `fix` | **Fixed** |
| `refactor`, `perf`, `style`, `format` | **Changed** |
| `revert`, `remove`, `deprecate` | **Removed** |
| `docs`, `doc` | **Changed** (or a standalone Docs section — your call) |
| `chore`, `build`, `ci`, `test`, `deps` | leave out or put at the bottom under **Other** |

If your categories need to differ from the ones above, just ask the user.

Strip the prefix from the message. Include the short commit hash (first 7 chars) as a reference.

### 4. Group by version

For each tag, identify which commits fall between it and the next-older tag. Commits since the newest tag go under **Unreleased**. If there are no tags, use a single **Unreleased** section or ask the user what version to use.

### 5. Scope display

If a commit has a scope like `feat(api): add endpoint`, show it as `- **api:** add endpoint`.

### 6. Output format

```markdown
# Changelog

## [Unreleased] — 2025-06-06

### Added
- **auth:** OAuth2 login flow (abc1234)
- **api:** rate limiting middleware (def5678)

### Fixed
- **ui:** button alignment on mobile screens (ghi9012)
- **db:** connection pool timeout (jkl3456)

### Changed
- **core:** refactored event bus (mno7890)

### Removed
- **legacy:** deprecated v1 endpoints (pqr1234)
```

### 7. Write CHANGELOG.md

Write to the repository root. Most-recent version at the top.

## Notes

- Only use data from actual git log output. Don't invent commits.
- For repos with hundreds of commits, ask the user to scope the range.
- No AI catchphrases. Just the facts and the markdown.
