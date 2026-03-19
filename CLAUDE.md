# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

A multi-project collection demonstrating AI-assisted development with Claude Code. Contains coding katas, educational content, and tooling built around specification-driven development.

## Project Map

| Path | Description | Stack |
|------|-------------|-------|
| `katas/kata-1/` | TimeToAct DocumentAI parser | C# (.NET 8), F# (.NET 8), JavaScript |
| `katas/kata-2/` | WebUI LLM Tool (spec only) | – |
| `katas/kata-3-slide-generator/` | TIMETOACT branded slide generator | HTML/CSS |
| `schleupen-tools/ContributionAnalyzer/` | TFS code ownership dashboard | Vue 3 + Pinia + D3.js + PowerShell |
| `intro-to-claudecode/` | Educational content about Claude Code | Markdown + HTML |
| `.claude/skills/` | Reusable Claude Code skills | – |

Each subdirectory with active code has its own `CLAUDE.md` with project-specific details.

## Common Commands

### Kata-1: TimeToAct DocumentAI

```bash
# F# implementation
cd katas/kata-1/fsharp
dotnet build TimeToActParser.sln
dotnet test TimeToActParser.Tests
dotnet test TimeToActParser.Tests --filter "TestMethodName"

# C# implementation
cd katas/kata-1/csharp
dotnet build TimeToActDocumentAI.sln
dotnet test TimeToActDocumentAI.Tests
dotnet test TimeToActDocumentAI.Tests --filter "TestMethodName"

# JavaScript implementation
cd katas/kata-1/js
node run-tests.js
```

### ContributionAnalyzer Vue App

```bash
cd schleupen-tools/ContributionAnalyzer/Vue-App
npm install
npm run dev      # http://localhost:5173
npm run build
```

## Architecture Notes

### Kata-1 (DocumentAI)
Spec-driven parser converting structured business documents to JSON. Three implementations (C#, F#, JS) all pass the same test suite derived from `katas/kata-1/spec.md`. Test data lives in `katas/kata-1/test-data/`.

Data flow: `Input text → Lexer → Parser → Domain objects → JSON`

### ContributionAnalyzer
Two-layer system:
1. **PowerShell scripts** fetch TFS data → CSV (`Product,Author,ContributionCount,FileCount`)
2. **Vue 3 frontend** loads CSV + JSON mappings → D3.js charts

State lives in `stores/useOwnershipStore.js` (Pinia). Author/team normalization is in `author_mappings.json` and `team_mappings.json`. Product names follow `{area}.{product}` pattern extracted from TFS paths.

### Slide Generator (`kata-3-slide-generator/third-try/`)
Produces self-contained HTML presentations using TIMETOACT brand design system. References `component-library.css` and `logo.svg` externally. See the CLAUDE.md in that directory for strict output rules before generating slides.

### `.claude/skills/presentation-generator`
A Claude Code skill that generates branded presentations. Invoked via `/presentation-generator`. The `layout.html` is the shell template; `styleguide.html` contains the component library.
