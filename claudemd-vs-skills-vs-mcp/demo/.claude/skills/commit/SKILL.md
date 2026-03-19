---
description: Stage all changes, derive a conventional commit message, and commit
disable-model-invocation: false
---

# Skill: commit

Stage all changes, derive a conventional commit message from the diff, and commit.

## Steps

1. Run `git diff HEAD` (and `git status`) to understand what changed.
2. Stage all changes: `git add -A`
3. Derive a conventional commit message:
   - Format: `<type>(<scope>): <subject>`
   - Types: feat | fix | docs | style | refactor | test | chore | perf
   - Subject: ≤50 chars, imperative mood, no trailing period
   - Add a short body (72-char lines) only if the change is non-obvious
4. Commit with the derived message.
5. Show the resulting `git log --oneline -1` to confirm.

## Rules

- Never skip hooks (`--no-verify`).
- Never amend an existing commit unless the user explicitly asks.
- If there is nothing to commit, say so and stop.
- Keep the message atomic — one logical change per commit.
