# Generate Changelog — Claude Code Skill

A Claude Code skill that generates structured changelogs from conventional commit history.

## Installation

Copy `.claude/skills/generate-changelog/` into your project's `.claude/skills/` directory.

## Usage

In Claude Code, just say: "generate a changelog" or "create release notes for v1.2.0"

The skill will:
1. Scan git history for conventional commits
2. Categorize by type
3. Group by version tag
4. Output clean markdown
