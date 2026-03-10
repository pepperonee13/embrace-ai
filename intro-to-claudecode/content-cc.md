# Intro to Claude Code
## Brownbag Session Outline (~20 minutes)

**Format:** Breadth-first overview — scratch the surface on many topics, go deep on none.

---

## 1. What Is Claude Code?

Claude Code is Anthropic's agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster through natural language commands. Unlike traditional AI chat assistants where you copy-paste code back and forth, Claude Code operates directly in your development environment — it can read files, edit code, run shell commands, manage git workflows, and connect to external services.

It launched as a research preview in February 2025 and became generally available in May 2025. The growth since has been extraordinary: as of February 2026, approximately 4% of all public GitHub commits (~135,000 per day) are authored by Claude Code — and at current growth rates, SemiAnalysis projects that figure will exceed 20% of all daily commits by end of 2026.

[Personal note: "I'm one of those commits — and this talk is about why I got hooked."]

**Sources:**
- Official docs: https://code.claude.com/docs/en/overview
- GitHub repo: https://github.com/anthropics/claude-code
- SemiAnalysis report (primary source for commit stats): https://newsletter.semianalysis.com/p/claude-code-is-the-inflection-point
- Growth stats (secondary): https://blakecrosley.com/guides/claude-code
- $1B revenue milestone & Bun acquisition: https://www.anthropic.com/news/anthropic-acquires-bun-as-claude-code-reaches-usd1b-milestone

---

## 2. Where Can You Use It?

Claude Code started as a terminal CLI and that remains its core, most full-featured interface. But it also meets you where you are — there are extensions for VS Code, Cursor, and JetBrains IDEs, a desktop app, and a browser-based version at claude.ai/code that requires no local setup at all.
For installation and platform-specific setup, the official docs cover everything: https://code.claude.com/docs/en/setup

**Sources:**
- Official setup docs: https://code.claude.com/docs/en/setup
- Official overview: https://code.claude.com/docs/en/overview

---

## 3. Why Does It Work So Well?

Most AI coding tools are built around a single interaction: you ask, it answers, you copy-paste. 
Claude Code is built around a different idea entirely — it works *with* your environment, 
not alongside it.

Two things set it apart:

### It actually understands your codebase
Claude Code doesn't just read the file you point it at. It explores your project structure, 
follows imports, understands patterns, and reasons about how components relate to each other. 
Ask it to fix a bug or build a feature and it will find the relevant files itself, understand 
the conventions already in place, and make changes that fit — not generic code dropped in 
from nowhere.

### It learns how you work
This is where it gets interesting. Claude Code has a set of primitives that let you encode 
your preferences, standards and workflow directly into the tool:

- **CLAUDE.md** — a file in your project root that Claude reads automatically every session. 
  Document your architecture, coding standards, tech stack, testing approach — and Claude 
  will follow them without being reminded every time.
- **Settings** — fine-grained control over what Claude can and cannot do in your environment.
- **Custom commands** — repeatable workflows you define once and invoke by name.
- **Skills** — reusable packages of instructions and scripts Claude loads dynamically for 
  specialised tasks.

The result is a tool that compounds in value the more you invest in it. It doesn't just get 
better over time — it gets more *yours*.

That combination — deep codebase understanding plus a configurable, persistent workflow — 
is what makes it feel qualitatively different from anything that came before it.

---

## 4. Core Capabilities — What Can It Do?

Describe what you want in plain language. Claude Code plans the approach, writes the code, and verifies it works.

- **Build features:** "Build a new API endpoint that returns user profiles and write the tests for it."
- **Fix bugs:** Paste an error message or describe the symptom — Claude traces the issue, identifies root cause, and implements a fix.
- **Understand code:** "Walk me through how our authentication system works."
- **Tedious tasks:** Writing tests, fixing lint errors, resolving merge conflicts, updating dependencies, writing release notes.
- **Git workflows:** Stage changes, write commit messages, create branches, open pull requests — all from natural language.
- **Multi-file editing:** Refactor across many files in a single session.

**Sources:**
- Official overview (use cases): https://code.claude.com/docs/en/overview
- Comprehensive guide with examples: https://www.eesel.ai/blog/claude-code-overview-docs

---

## 5. Key Concepts to Know

### CLAUDE.md — Project Memory
A special markdown file in your project root that Claude reads automatically. Use it to document coding standards, architecture, tech stack, file organization, and testing instructions. This is how you give Claude persistent context about your project across sessions.

### Slash Commands
Built-in commands you run during a session: `/help`, `/compact` (compress context), `/cost` (token usage), `/model` (switch models), `/status`, `/bug` (report issues), and more. You can also create custom commands as markdown files in `.claude/commands/`.

### Subagents — Delegation
Claude Code can spawn sub-agents with clean context windows to handle focused tasks (exploration, planning, implementation), then return only summaries to the main conversation. This prevents context bloat and keeps costs down.

### Permission System
Claude asks before performing potentially impactful actions (editing files, running commands). You can configure fine-grained permissions in `.claude/settings.json` to allow or block specific tools.

**Sources:**
- CLI reference and slash commands: https://code.claude.com/docs/en/cli-reference
- CLAUDE.md and configuration: https://shipyard.build/blog/claude-code-cheat-sheet/
- Architecture (core/delegation/extension layers): https://blakecrosley.com/guides/claude-code
- Complete command guide: https://github.com/Cranot/claude-code-guide

---

## 6. Extensibility — Hooks, MCP, and Skills

### Hooks
Shell commands that fire automatically at specific lifecycle events (pre-commit, post-tool-use, etc.). Use them for linting, formatting, security checks — anything that must run deterministically every time, not just when the model decides to.

### MCP (Model Context Protocol)
An open standard for connecting Claude Code to external data sources and services — databases, GitHub, Sentry, Slack, and 300+ others. Browse and install servers via the MCP Registry. MCP has been donated to the Agentic AI Foundation (Linux Foundation).

### Skills
Organized folders of instructions, scripts, and resources that Claude loads dynamically. Think of them as reusable expertise packages — custom slash commands on steroids.

**Sources:**
- Hooks & MCP real-world setup: https://okhlopkov.com/claude-code-setup-mcp-hooks-skills-2026/
- Comprehensive CLI guide (layers explanation): https://introl.com/blog/claude-code-cli-comprehensive-guide-2025
- Awesome Claude Code (community ecosystem): https://github.com/hesreallyhim/awesome-claude-code
- MCP Registry: https://registry.modelcontextprotocol.io/

---

## 7. CI/CD & Automation

Claude Code integrates with GitHub Actions and GitLab CI/CD pipelines. The official GitHub Action (`anthropics/claude-code-action`) lets you:

- Trigger Claude by mentioning `@claude` in PR comments or issues
- Automate code reviews on every PR
- Turn issues into working code and PRs automatically
- Translate strings, update documentation, fix lint errors
- Run with headless mode (`claude -p`) for scripting and pipelines

Setup is straightforward: run `/install-github-app` inside Claude Code, configure your API key as a GitHub secret, and add a workflow YAML file.

**Sources:**
- Official GitHub Actions docs: https://code.claude.com/docs/en/github-actions
- GitHub Action repo: https://github.com/anthropics/claude-code-action
- GitHub Marketplace: https://github.com/marketplace/actions/claude-code-action-official
- CI/CD practical guide: https://noqta.tn/en/blog/claude-code-ci-cd

---

## 8. Security — Claude Code Security (New!)

Announced February 20, 2026, Claude Code Security is a new capability that scans codebases for vulnerabilities and suggests targeted patches for human review. Key highlights:

- Goes beyond traditional static analysis by reasoning about code like a human security researcher — understanding component interactions, data flows, and business logic.
- Using Opus 4.6, Anthropic's team found over 500 previously unknown vulnerabilities in production open-source codebases.
- Nothing is applied without human approval — Claude provides confidence ratings for each finding.
- Available as a limited research preview to Enterprise/Team customers, with expedited access for open-source maintainers.

**Sources:**
- Official announcement: https://www.anthropic.com/news/claude-code-security
- Industry analysis: https://www.csoonline.com/article/4136294/anthropics-claude-code-security-rollout-is-an-industry-wakeup-call.html
- Snyk perspective: https://snyk.io/articles/anthropic-launches-claude-code-security/

---

## 9. The Bigger Picture — Where It's Heading

- **Agent Teams (research preview, Feb 2026):** Multiple autonomous coding agents working in parallel on different components of a project.
- **Claude Cowork:** Extending the "Claude Code magic" beyond developers to all knowledge workers — connecting to Google Drive, Gmail, DocuSign, and more.
- **1M token context window** (beta with Opus 4.6) — analyze entire large codebases in one session.
- **Community ecosystem** is thriving: plugins, custom skills, agent orchestrators, statusline tools, and more on the awesome-claude-code list.
- Anthropic reached $1B in annualized revenue from Claude Code (announced Nov 2025) and acquired Bun (JavaScript runtime) to accelerate infrastructure.

**Sources:**
- Claude Cowork & enterprise direction: https://venturebeat.com/orchestration/anthropic-says-claude-code-transformed-programming-now-claude-cowork-is
- Bun acquisition & $1B milestone: https://www.anthropic.com/news/anthropic-acquires-bun-as-claude-code-reaches-usd1b-milestone
- Agent Teams & feature timeline: https://github.com/wesammustafa/Claude-Code-Everything-You-Need-to-Know
- Community ecosystem: https://github.com/hesreallyhim/awesome-claude-code

---

## 10. Getting Started — The Cost of Entry is Low

You need a Pro subscription ($20/month) or an API key — Claude Code is not available on the free tier. But the entry point is intentionally low. Pro gives you access to all models including Opus 4.6 and is sufficient for most developers getting started. If you hit usage limits with heavy daily use, Max plans are available at $100/month (5x Pro usage) or $200/month (20x Pro usage) — the difference between tiers is purely usage volume, not model access.

- **macOS/Linux:** `brew install --cask claude-code`
- **Windows (recommended):** `irm https://claude.ai/install.ps1 | iex` in PowerShell
- **Windows (alternative):** `winget install Anthropic.ClaudeCode`

> Note: the old `npm install -g @anthropic-ai/claude-code` method still circulates in older tutorials but is now deprecated — use one of the above instead.

Navigate to your project, run `claude`, and start talking to your codebase. Most people are up and running in under 2 minutes.

Or skip local setup entirely at **claude.ai/code** — no installation needed.

**Sources:**
- Official setup docs: https://code.claude.com/docs/en/setup
- Plans & pricing: https://claude.com/pricing
- Opus 4.6 availability: https://www.anthropic.com/claude/opus
- Max plan details: https://support.claude.com/en/articles/11049741-what-is-the-max-plan
