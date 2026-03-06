# 🤖 Claude Code: What I Learned So You Don't Have To
### Learning & Sharing Session — ~20 min

> *"I survived the Embrace AI challenge and all I got was this presentation... and honestly a lot of time saved."*

---

# 🎯 Agenda

1. What is Claude Code?
2. Why does it matter?
3. Claude model lineup
4. Common use cases (+ which model to pick)
5. Tokens, limits & pricing
6. Customization & automation
7. How Claude Code actually works

---

# 1. 🐣 What is Claude Code?

**TL;DR:** It's an AI coding agent that can operate directly on your codebase.

Originally launched as a **terminal-based CLI tool**, Claude Code is now accessible through multiple interfaces:

- **CLI agent** (`claude` command in your terminal)
- **Claude web app**
- **Integrations and automation workflows**

Unlike simple AI assistants, Claude Code can **interact with your repository and development tools**.

It can:

- read files
- write code
- run commands
- execute tests
- refactor code
- analyze repositories
- create commits and pull requests

Think of it as a **junior developer that can operate tools**, not just generate text.

---

## Install (CLI)

npm install -g @anthropic-ai/claude-code

Then inside a project:

claude

---

## Simplified workflow

You describe a task
↓
Claude explores the repository
↓
Claude performs actions (tools)
↓
You review results
↓
Iterate

---

# 2. 🔥 Why Does It Matter?

Most AI coding tools behave like this:

> "Here's some code. Good luck."

Claude Code behaves more like this:

> "I'll try implementing it, run tests, debug failures, and refine the solution."

This difference is often called **agentic behavior**.

### Key capabilities

Claude Code can:

- execute **multi-step tasks**
- analyze **entire repositories**
- refactor across **multiple files**
- run tests and fix failures
- review pull requests
- generate documentation
- assist with migrations

This shifts the workflow from:

writing code → debugging

to

reviewing AI-generated code → refining

---

# 3. 🧠 Claude Model Lineup

Claude models come in **three families**, each optimized for different workloads.

| Model | Personality | Best For |
|------|-------------|----------|
| **Haiku** | Very fast, inexpensive | Automation, tooling, simple tasks |
| **Sonnet** | Balanced performance | Daily coding tasks |
| **Opus** | Highest reasoning ability | Complex architecture & debugging |

Typical workflow:

- **Haiku** → automation scripts
- **Sonnet** → daily coding tasks
- **Opus** → difficult reasoning problems

---

## Example model switch (CLI)

/model claude-opus

Rule of thumb:

> Start with Sonnet. Switch to Opus when the problem gets hard.

---

# 4. 🛠 Common Use Cases

## 🟢 Quick wins

Sonnet usually works great for:

- fixing bugs
- writing unit tests
- generating documentation
- explaining unfamiliar code
- reviewing pull requests

Example:

Find and fix the null pointer bug in AuthService

---

## 🟡 Medium complexity

Still usually handled well by Sonnet:

- feature implementation
- codebase exploration
- dependency upgrades
- API migrations

Example:

Migrate these REST calls from API v1 to v2

---

## 🔴 Heavy lifting

When problems require deeper reasoning, **Opus shines**.

Examples:

- architectural tradeoffs
- debugging legacy code
- large refactors
- complex system design

Example:

Explain why this distributed transaction occasionally deadlocks

---

# 5. 🪙 Tokens, Limits & Pricing

Unfortunately we have to talk about **tokens and limits**.

---

## What is a token?

A token is roughly **¾ of a word**.

Examples:

| Content | Tokens |
|-------|-------|
| short prompt | ~20 |
| long function | ~200 |
| medium source file | 1k+ |

Everything counts toward usage:

- input prompts
- files read
- generated responses
- tool outputs

---

## Claude.ai Plans

Claude offers subscription plans for the hosted assistant.

| Plan | Typical usage | Notes |
|----|----|----|
| Free | Limited usage | Lower priority access |
| Pro | Higher limits | Popular individual plan |
| Max | Much higher limits | Access to more compute |

Important notes:

- usage is **not defined by fixed token quotas**
- limits depend on **model and workload**
- usage resets periodically (rolling windows)

Heavy tasks may consume more of your usage allowance.

---

## API Pricing

The API uses **pay-per-token billing**.

Typical structure:

| Model | Cost Profile |
|------|-------------|
| Haiku | cheapest |
| Sonnet | mid-range |
| Opus | most expensive |

Pricing depends on:

- input tokens
- output tokens
- model used

See official pricing for details.

---

## Practical token tips

Things that reduce token usage:

- clearing old context
- using focused prompts
- referencing specific files
- avoiding long conversation chains

---

# 6. ✨ Customization & Automation

This is where Claude Code becomes **extremely powerful**.

---

# 📄 CLAUDE.md — Your AI onboarding document

Claude automatically reads a `CLAUDE.md` file at the root of your repository.

Example:

# Project Rules

Always run tests before committing.

Use TypeScript strict mode.

Branch naming convention:
feature/[ticket-id]-short-description

Never edit files in /generated

Think of it as **team onboarding instructions for your AI colleague**.

Benefits:

- consistent behavior
- shared team conventions
- reusable automation

---

# ⚡ Custom Slash Commands

Claude supports custom commands defined in:

.claude/commands/

Example:

.claude/commands/review.md

Content:

Review the staged changes for bugs and security issues only.
Ignore formatting and style comments.

Usage:

/review

---

# 🪝 Hooks

Hooks run **automatic commands during agent activity**.

Example: run Prettier after file writes.

{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Write(*.ts)",
      "hooks": [{
        "type": "command",
        "command": "prettier --write $file"
      }]
    }]
  }
}

Hooks enable:

- automatic linting
- formatting
- test execution
- policy enforcement

---

# 🔌 Plugins

Plugins bundle:

- commands
- hooks
- integrations

This allows teams to share workflows.

Example:

/plugin install <plugin-name>

---

# 7. 🧠 How Claude Code Actually Works

Claude Code is built around **tool-based agents**.

Instead of directly editing files, Claude calls tools like:

| Tool | Purpose |
|----|----|
| ReadFile | inspect source code |
| WriteFile | modify code |
| RunCommand | execute shell commands |
| Search | explore repository |
| Git tools | commit, diff, PR workflows |

Workflow:

User task
↓
Claude plans actions
↓
Claude uses tools
↓
Results returned
↓
Claude decides next step

This enables **multi-step autonomous work**.

---

# Model Context Protocol (MCP)

Claude can also interact with **external tools via MCP servers**.

Examples:

- GitHub repositories
- databases
- documentation systems
- internal APIs

This allows Claude to **query external systems safely**.

---

# 🎬 Live Demo (~3 min)

Example demo flow:

1. Start Claude Code in a project

claude

2. Show `CLAUDE.md`

3. Ask Claude to analyze a bug

Find potential null pointer bugs in the auth module

4. Stage a change

5. Run custom command

/review

---

# 🏁 Key Takeaways

- Claude Code is an **AI coding agent**, not just an autocomplete tool
- Model families: **Haiku, Sonnet, Opus**
- Sonnet is ideal for **daily development**
- Opus helps solve **hard reasoning problems**
- `CLAUDE.md` dramatically improves results
- Hooks and commands allow **automation of workflows**
- Claude operates through **tools and agents**

---

# 🔗 Resources

Official documentation  
https://docs.claude.com/en/docs/claude-code/overview

Model documentation  
https://platform.claude.com/docs/en/about-claude/models

Pricing  
https://claude.com/pricing

API  
https://claude.com/platform/api

Community resources  
https://github.com/hesreallyhim/awesome-claude-code

---

*Made with Claude Code. Obviously.*
