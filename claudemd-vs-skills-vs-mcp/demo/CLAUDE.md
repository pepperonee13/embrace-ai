# CLAUDE.md

## Project Rules

### Test-First Development
Always write tests before implementation (TDD). A feature is not ready until tests pass.

### TypeScript
Never use `any`. All values must be explicitly typed. Prefer `unknown` if the type is truly unknown, then narrow it.

### Code Style
- Keep functions small and pure where possible
- Prefer explicit types over inferred where it aids readability
- No magic strings — use constants or enums
