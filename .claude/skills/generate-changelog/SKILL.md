---
name: generate-changelog
description: Analyzes git history using conventional commits and generates a structured changelog in markdown, grouped by version and type (feat, fix, chore, etc.)
trigger: when the user asks to "generate changelog", "create release notes", "what changed", or before any release
---

# Generate Changelog

Generate a structured changelog from a git repository's conventional commit history.

## When to use

- Before a release
- When asked "what changed"
- When creating release notes

## Steps

1. Check the repo has conventional commits (`git log --oneline -5`)
2. Ask for version tag if this is a release
3. Run: `git log --oneline --no-decorate $(git describe --tags --abbrev=0 2>/dev/null || git rev-list --max-parents=0 HEAD)..HEAD`
4. Parse commits into categories: Features, Bug Fixes, Documentation, Refactoring, Performance, Chores
5. Group by version if multiple tags exist
6. Output formatted markdown with dates

## Output format

```
# Changelog

## [v1.2.0] - 2026-06-06

### Features
- add user authentication (abc123)

### Bug Fixes
- fix login crash on null token (def456)
```
