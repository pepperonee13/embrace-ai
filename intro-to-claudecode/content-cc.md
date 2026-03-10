# Intro to Claude Code
## Brownbag Session Outline (~20 minutes)

**Format:** Breadth-first overview — scratch the surface on many topics, go deep on none.

---

## 1. What Is Claude Code?

Claude Code is Anthropic's agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster through natural language commands. Unlike traditional AI chat assistants where you copy-paste code back and forth, Claude Code operates directly in your development environment — it can read files, edit code, run shell commands, manage git workflows, and connect to external services.

It launched as a research preview in February 2025 and became generally available in May 2025. As of early 2026, approximately 4% of public GitHub commits (~135,000 per day) are authored by Claude Code.

**Sources:**
- Official overview: https://code.claude.com/docs/en/overview
- GitHub repo: https://github.com/anthropics/claude-code
- Growth stats: https://blakecrosley.com/guides/claude-code (cites 4% of GitHub commits as of Feb 2026)
- $1B revenue milestone & Bun acquisition: https://www.anthropic.com/news/anthropic-acquires-bun-as-claude-code-reaches-usd1b-milestone

---

## 2. Where Can You Use It?

Claude Code is available across multiple surfaces — it's not just a terminal tool anymore:

- **Terminal CLI** — the original and full-featured interface. Install via Homebrew (macOS/Linux) or WinGet (Windows), then run `claude` in any project directory.
- **VS Code / Cursor extension** — inline diffs, @-mentions, plan review, and conversation history directly in the editor.
- **JetBrains plugin** — works with IntelliJ, PyCharm, WebStorm, and other JetBrains IDEs.
- **Desktop app** — standalone app for reviewing diffs visually, running multiple sessions, scheduling tasks, and cloud sessions.
- **Web (claude.ai/code)** — browser-based, no local setup needed. Run long tasks and check back later. Launched October 2025.

**Sources:**
- Official overview (lists all surfaces): https://code.claude.com/docs/en/overview
- Web launch: https://mlq.ai/news/anthropic-launches-claude-code-on-the-web/ (October 20, 2025)

---

## 3. How to Get Access (Pricing)

Claude Code requires at least a Pro subscription or API credits — it's not available on the Free tier.

- **Pro plan ($20/month):** Includes Claude Code with Sonnet model access. Good for learning and smaller projects, but you may hit usage limits during heavy coding sessions.
- **Max 5x plan ($100/month):** 5x Pro usage, access to Opus 4.6, priority access during peak times.
- **Max 20x plan ($200/month):** 20x Pro usage, effectively unlimited for most individual users. Near-zero latency priority.
- **API (pay-as-you-go):** Sonnet 4.6 at $3/$15 per million tokens (input/output). Opus 4.6 at $5/$25 per million tokens. Average developer spend is roughly $6/day on API.
- **Team & Enterprise plans** also available for organizations.

**Sources:**
- Max plan details: https://support.claude.com/en/articles/11049741-what-is-the-max-plan
- Pricing breakdown: https://claudelog.com/claude-code-pricing/
- Average developer cost stats: https://intuitionlabs.ai/articles/claude-pricing-plans-api-costs

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

## 10. Getting Started — Try It Now

Quick start in under 2 minutes:
1. Have a Pro/Max subscription or API key
2. Install: `brew install claude-code` (macOS/Linux) or `winget install Anthropic.ClaudeCode` (Windows)
3. Navigate to your project: `cd your-project`
4. Run: `claude`
5. Start talking: "Explain the architecture of this project" or "Write tests for the auth module"

Or skip local setup entirely at **claude.ai/code**.

**Sources:**
- Official overview / quickstart: https://code.claude.com/docs/en/overview
- Cheatsheet for getting productive fast: https://shipyard.build/blog/claude-code-cheat-sheet/