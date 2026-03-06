Use latest info from official sources:
- https://platform.claude.com/docs/en/home
- https://claude.com/pricing
- https://claude.com/platform/api

  
# 🤖 Claude Code: What I Learned So You Don't Have To
### Learning & Sharing Session — ~20 min

> *"I survived the Embrace AI challenge and all I got was this presentation... and honestly a lot of time saved."*

---

## 🎯 Agenda

1. What is Claude Code?
2. Why does it matter?
3. Which models are available?
4. Common use cases (+ which model to pick)
5. Tokens & usage limits — the unsexy but important stuff
6. Customization & automation (+ live demo!)

---

## 1. 🐣 What is Claude Code?

**TL;DR:** It's an AI coding agent that lives in your terminal.

- A **CLI tool** by Anthropic — not a plugin, not a sidebar, not a chat box
- It can **read files, write code, run tests, make commits**, and push PRs
- Powered by Anthropic's Claude models under the hood
- Think of it as a dev who never sleeps, never complains about legacy code, and actually reads the docs

**Install in one line:**
```bash
npm install -g @anthropic-ai/claude-code
```
Then just run `claude` in your project directory. That's it.

**How it works (oversimplified):**
> You describe what you want → Claude reads your codebase → Claude acts → you review → repeat

---

## 2. 🔥 Why Does It Matter?

**The agentic difference:**
- Most AI tools: "here's some code, good luck"
- Claude Code: "I'll write it, run it, see it fail, fix it, and commit it"

**Key powers:**
- Autonomous multi-step task execution (not just autocomplete)
- Understands your *actual* codebase — not a generic snippet machine
- Can review PRs automatically (via GitHub App integration)
- Works well on refactors, migrations, debugging, documentation

**The vibe shift:** You go from *writing* code to *reviewing* code. Your job title stays the same, your Friday afternoons get better.

---

## 3. 🧠 Available Models

//TODO: include all models from https://platform.claude.com/docs/en/about-claude/models/overview
Claude Code lets you choose your model. Here's the lineup as of early 2026:

| Model | Personality | Good for |
|---|---|---|
| **Claude Sonnet 4.6** | Fast, sharp, cost-efficient | Day-to-day coding, fast iteration |
| **Claude Opus 4** | Slower, deeper reasoning | Complex architecture, hard bugs |

**Model switching:**
```bash
/model claude-opus-4-20250514
```

**Default behavior (Pro plan):** Uses Sonnet until you hit ~50% of your usage window, then stays on Sonnet. Opus requires Max plan or API access.

**Rule of thumb:** Sonnet for "get stuff done", Opus for "figure this thing out".

---

## 4. 🛠 Common Use Cases

### 🟢 Quick wins — Sonnet is perfect here
- **Bug fixing** — "Find and fix the null pointer in AuthService"
- **Writing tests** — "Add unit tests for the payment module"
- **Code review** — "Review this PR and flag actual bugs, not style nitpicks"
- **Documentation** — "Write a README for this repo"
- **Refactoring** — "Extract this logic into a reusable utility"

### 🟡 Medium complexity — Sonnet, maybe Opus
- **Feature implementation** from a spec or ticket
- **Codebase exploration** — "How does our auth flow actually work?"
- **Migration tasks** — "Migrate these API calls from v1 to v2"

### 🔴 Heavy lifting — Opus earns its keep
- **Architectural decisions** — "Should this be a microservice or a module?"
- **Debugging haunted legacy code** — the kind that has no tests and three authors
- **Complex multi-file refactors** with lots of interdependencies

**Pro tip:** Start with Sonnet. If it starts going in circles, switch to Opus.

---

## 5. 🪙 Tokens & Usage Limits

*Yes, we have to talk about this. It's like checking your phone battery — annoying but necessary.*

### What's a token?
- Roughly ~¾ of a word. A 200-line file ≈ a few thousand tokens.
- Every file Claude reads, every line it writes, every tool result — all count.

### The usage model (Claude.ai plans)

Source: https://claude.com/pricing

//TODO: find and list per Input/Output token costs
| Plan | Approx. tokens / 5h window | Opus access |
|---|---|---|
| **Free** | ~limited / no agentic features | ❌ |
| **Pro** (~$20/mo) | ~44,000 tokens | ❌ |
| **Max 5x** (~$100/mo) | ~88,000 tokens | ✅ |
| **Max 20x** (~$200/mo) | ~220,000 tokens | ✅ |

- Usage **resets every 5 hours** (rolling window)
- There are also **weekly caps** (introduced Aug 2025) — affects <2% of users with Sonnet
- All Claude surfaces (claude.ai, Claude Code, Claude Desktop) share the **same usage pool**
- **API users** get separate pay-per-token billing — no rolling windows

### Commands to track your usage
```bash
/cost      # see token spend for current session
/usage     # see remaining quota + reset timer
```

### Token-saving tips that actually work
- Use `/clear` often — don't drag old context into new tasks
- Write a lean `CLAUDE.md` — Claude reads it every session, so keep it tight
- Be specific in your prompts — "fix the login bug in UserController.java" > "fix the login stuff"
- Big diffs in one prompt > lots of small "refine this" follow-ups

---

## 6. ✨ Customization & Automation

*Here's where Claude Code goes from "pretty cool" to "actually magic".*

### 📄 CLAUDE.md — Your project's brain transplant

A markdown file at the root of your project (or `~/.claude/CLAUDE.md` globally) that Claude reads at the start of every session.

```markdown
# My Project

- Always use TypeScript strict mode
- Run `npm test` before committing
- Branch naming: feature/[ticket-id]-short-description
- Never edit files in /generated — these are auto-generated
```

Think of it as onboarding docs for your AI colleague. Commit it to git — your whole team benefits.

---

### ⚡ Custom Slash Commands — Macros for your workflow

Create repeatable workflows by dropping markdown files in `.claude/commands/`:

```bash
mkdir -p .claude/commands
```

Example: `.claude/commands/review.md`
```markdown
Review the staged changes for bugs and security issues only.
Be concise. No style comments.
```

Then in any session:
```bash
/review
```

Parameterized version for tickets:
```bash
/fix-issue 1337
```

---

### 🪝 Hooks — The "always do this" automation layer

Hooks run deterministic shell commands at specific lifecycle points. Unlike CLAUDE.md suggestions, hooks are rules that *always* fire.

**Example: Auto-run Prettier after every file write**
```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Write(*.ts)",
      "hooks": [{ "type": "command", "command": "prettier --write $file" }]
    }]
  }
}
```

**Available hook events:** `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `Stop`, and more.

Configure them via the interactive `/hooks` command — no JSON editing required.

---

### 🔌 Plugins — Share it all as a bundle

Plugins package slash commands + hooks + MCP servers into one installable unit. Great for team-wide consistency.

```bash
/plugin install <plugin-name>
```

---

## 🎬 Live Demo (~3 min)

> **What we'll do:** Start Claude Code in a small project, show CLAUDE.md in action, and fire a custom `/review` slash command.

Steps:
1. `cd my-demo-project && claude`
2. Show the auto-loaded CLAUDE.md context
3. Ask Claude to find a bug
4. Run `/review` on staged changes
5. Watch it not hallucinate variable names 🤞

---

## 🏁 Key Takeaways

- Claude Code is **agentic** — it does things, not just suggests things
- **Sonnet** for speed and daily work; **Opus** for hard problems (Max plan)
- Usage runs on a **5-hour rolling window** — shared across all Claude surfaces
- `CLAUDE.md` is the most impactful 15 minutes you'll spend on your AI setup
- Custom slash commands + hooks = your personalized dev co-pilot

---

## 🔗 Resources

- Docs: https://docs.claude.com/en/docs/claude-code/overview
- Awesome Claude Code (community): https://github.com/hesreallyhim/awesome-claude-code
- Usage limits explained: https://support.claude.com/en/articles/11647753-understanding-usage-and-length-limits

---

*Made with Claude Code. Obviously.*
