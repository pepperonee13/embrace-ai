# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

A multi-project learning repository for AI-assisted development through coding katas and practical tooling. Each subdirectory is an independent project with its own stack, build system, and CLAUDE.md.

## Projects Overview

| Directory | Description | Stack |
|-----------|-------------|-------|
| `kata-1/` | TimeToAct DocumentAI — document parser with 3 parallel implementations | C#, F#, JavaScript |
| `kata-2/` | LLM File Prompter — WebUI for sending file content to LLMs | Express.js |
| `kata-3-oneshot/` | Exploratory ChatGPT integration experiments (versioned v1–v14) | Node.js, Express |
| `kata-3-slide-generator/` | Presentation generator with design tokens and branding | HTML/CSS, Reveal.js |
| `ContributionAnalyzer/` | TFS/Git contribution analytics dashboard | Vue 3, D3.js, PowerShell |
| `intro-to-claudecode/` | Slides and outline for Claude Code introduction talk | Reveal.js |
| `.claude/skills/` | Custom Claude Code skills (e.g., `presentation-generator`) | Markdown + HTML |

Each project with significant complexity has its own `CLAUDE.md` — read it before working in that directory.

## Key Build Commands

### ContributionAnalyzer (Vue App)
```bash
cd ContributionAnalyzer/Vue-App
npm install
npm run dev       # http://localhost:5173
npm run build
```

### kata-1 — C# (from `kata-1/csharp/`)
```bash
dotnet build TimeToActDocumentAI.sln
dotnet test TimeToActDocumentAI.Tests
dotnet test TimeToActDocumentAI.Tests --filter "TestMethodName"
```

### kata-1 — F# (from `kata-1/fsharp/`)
```bash
dotnet build TimeToActParser.sln
dotnet test TimeToActParser.Tests
```

### kata-1 — JavaScript (from `kata-1/js/`)
```bash
node documentai.test.js
node run-tests.js
```

### kata-2 (from `kata-2/src/`)
```bash
npm run dev   # nodemon
npm start
```

## Architecture Notes

### ContributionAnalyzer
- **Data flow**: PowerShell ETL (TFS → CSV) → PapaParse → Pinia store → Vue components → D3.js charts
- `author_mappings.json` / `team_mappings.json` normalize raw VCS identities
- CSV format: `Product,Author,ContributionCount,FileCount`; last line: `Since=YYYY-MM-DD,Until=YYYY-MM-DD`

### kata-1 (DocumentAI)
- All three implementations (C#, F#, JS) conform to the same `spec.md`; test data lives in `test-data/`
- C#: immutable records, parsing pipeline with `DocumentParser` + `Lexer`
- F#: discriminated unions, active patterns, pure functional parsing
- JS: single-file recursive descent parser

### Presentation Skill (`.claude/skills/presentation-generator/`)
- Uses Reveal.js with a custom design token system and component library (`layout.html`)
- Invoked via `/presentation-generator` skill in Claude Code
