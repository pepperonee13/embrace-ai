# Presentation Outline: Claude Code — From Solo to Team

**Talk duration:** 20 minutes
**Audience:** Developers who have been introduced to Claude Code basics
**Goal:** Show how CLAUDE.md, Memory, and Skills solve the "it forgets everything" problem — both for individuals and teams

---

## Narrative Arc

> Day 1: Claude Code is amazing.
> Day 5: You're repeating yourself every session.
> Day 10: Your teammate gets completely different behavior than you.
> **Here's how to fix that.**

The talk is structured around this progression. Each tool is introduced as the answer to a concrete frustration — not as a feature to learn.

---

## Slides

### 1. Title Slide
**Title:** Claude Code — From Solo to Team
**Subtitle:** CLAUDE.md · Memory · Skills

---

### 2. Agenda
- The Problem: Claude Forgets
- CLAUDE.md — Team Context
- Memory — Personal Context
- Skills — Shared Workflows
- Context Management Best Practices
- Putting It Together

---

### 3. The Problem — Claude Forgets Everything

**Headline:** Every session starts blank.

**Content:**
- Claude has no persistent memory by default
- Day 1: great results — you set up the conversation well
- Day 5: you're re-explaining your coding standards every time
- Day 10: a teammate gets different behavior — they set up the context differently

**Visual suggestion:** A simple timeline: Day 1 → Day 5 → Day 10 with a short label on each

**Key insight (highlighted box):** The features we'll cover don't make Claude smarter — they make the *context* persistent and consistent.

---

### 4. Three Tools, Three Problems

**Headline:** Different problems need different tools.

**Table:**
| Frustration | Tool | Who benefits |
|---|---|---|
| "I have to re-explain our rules every time" | CLAUDE.md | The whole team |
| "Claude doesn't know my role or preferences" | Memory | Just you |
| "We keep doing the same workflow manually" | Skills | You or the team |

**Key insight:** CLAUDE.md is *shared* (it lives in git). Memory and Skills can be personal or shared.

---

### 5. How Features Load Into Context

**Section label:** Context Basics

**Headline:** Not everything loads the same way.

**Visual:** Embed `context-loading.svg` — the official Claude docs diagram showing when each feature enters the context window.

**Annotation / speaker notes:**
- CLAUDE.md: always loaded, every request — keep it tight
- Skills: only their *description* loads at session start; full content loads when invoked
- Hooks & Subagents: run outside the main context — zero token cost
- This diagram explains why context management matters: some things are free, some are always-on costs

**Key insight (highlighted box):** CLAUDE.md is always in your context window — even when you don't invoke it. That's power, but also cost. Keep it focused.

---

### 6. CLAUDE.md — What It Is

**Section label:** CLAUDE.md

**Headline:** A prompt that's always loaded.

**Content:**
- A markdown file Claude reads at the start of every session
- Lives in the repo root — checked into git
- Scope: applies to everyone working in that repo
- Use it for: coding standards, architectural rules, project context, "never do X"
- Path-based: subdirectories can have their own CLAUDE.md for more specific rules

**Code block (shell):**
```
project/
├── CLAUDE.md          ← always loaded
├── src/
│   └── CLAUDE.md      ← loaded only when working in src/
```

---

### 6. CLAUDE.md — Demo

**Section label:** CLAUDE.md

**Headline:** Watch Claude self-correct.

**Demo steps:**
1. Show a CLAUDE.md rule: `"Never use the 'any' type in TypeScript"`
2. Ask Claude: *"Add a helper function that takes an unknown input and logs it"*
3. Claude uses `unknown` instead of `any` — and explains why, citing the rule

**Key insight:** If you explicitly ask for `any`, Claude will comply — but tells you it's overriding the rule. It never silently breaks your standards.

**Callout:** This is also how you onboard Claude to a new project — one CLAUDE.md, and every session starts informed.

---

### 7. Memory — What It Is

**Section label:** Memory

**Headline:** Context that's yours, not the repo's.

**Content:**
- Two flavors:
  - `/memory` command — quick note, stored in a CLAUDE.md at user/project level
  - Auto-memory — structured files Claude writes and recalls contextually (more powerful)
- Scope: personal — *not* shared with teammates
- Use it for: your role, your preferences, ongoing personal context

**Two-column layout:**
- Left — `/memory`: fast, manual, stored as plain text in CLAUDE.md
- Right — Auto-memory: file-based, recalled selectively, scales better

**Key insight (highlighted box):** Memory ≠ CLAUDE.md. Memory is for *you*. CLAUDE.md is for the *project*.

---

### 8. Memory — Demo

**Section label:** Memory

**Headline:** Claude remembers who you are.

**Demo steps:**
1. Tell Claude: *"I'm a backend developer, I primarily work on the API layer, Anna is our tech lead and reviews all PRs"*
2. Ask Claude to save this to memory
3. Start a new session
4. Ask: *"Who should I ask to review this PR?"* — Claude recalls Anna

**Key insight:** This is the difference between a tool you configure once and one you re-explain forever.

---

### 9. Skills — What They Are

**Section label:** Skills

**Headline:** Encode how your team works.

**Content:**
- A skill is a reusable prompt stored as a file in `.claude/skills/`
- Invoked with a slash command: `/commit`, `/review-pr`, `/interview-me`
- Can use tools: read files, run commands, ask follow-up questions
- Skills can be personal or checked into the repo (shared with the team)

**Key insight:** Skills aren't just shortcuts — they encode *your team's process*. A `/review-pr` skill with your team's checklist is better than any generic one.

---

### 10. Skills — Demo 1: /commit

**Section label:** Skills

**Headline:** Automate the boring stuff.

**Demo steps:**
1. Make a small change to a TypeScript file
2. Invoke `/commit`
3. Claude reads the diff, derives a conventional commit message, stages and commits

**Key insight:** The skill knows your commit conventions (from CLAUDE.md) — it doesn't ask, it just applies them.

---

### 11. Skills — Demo 2: /interview-me

**Section label:** Skills

**Headline:** Skills can have structured conversations.

**Demo steps:**
1. Invoke `/interview-me`
2. Claude starts asking structured questions using `AskUserQuestion` tool
3. Show that it's not just outputting text — it's driving a real back-and-forth

**Key insight:** Skills can use any Claude tool. This one uses `AskUserQuestion` to turn a monologue into a dialogue — great for retrospectives, planning sessions, or learning exercises.

---

### 12. Context Management — Why It Matters

**Section label:** Context Management

**Headline:** Context has a cost.

**Content:**
- Everything in the context window costs tokens — and affects quality
- What fills your context: open files, conversation history, CLAUDE.md, tool outputs
- Symptoms of a bloated context: slower responses, repeated mistakes, hitting usage limits
- Common mistake: running one long session for everything

**Highlight box (warm):** Usage limits aren't just about volume — they're often a sign the context is doing too much work.

---

### 13. Context Management — Best Practices

**Section label:** Context Management

**Headline:** Keep the context clean and focused.

**Bullet list:**
- Use `/clear` between unrelated tasks — start fresh
- Keep CLAUDE.md tight: rules and context, not documentation
- Use Skills to avoid re-explaining workflows in every session
- Use Memory so you don't re-introduce yourself each time
- Don't dump large files into context — reference them, let Claude read what it needs

**Takeaway rows:**
- One task per session → better results, lower token cost
- CLAUDE.md is always loaded → keep it short and high-signal
- Skills + Memory = most of your setup is done once

---

### 14. Putting It Together

**Section label:** Summary

**Headline:** Which tool, when?

**Table:**
| I want to... | Use |
|---|---|
| Give Claude our team's rules and standards | CLAUDE.md |
| Tell Claude about my role and preferences | Memory |
| Encode a repeatable workflow | Skill |
| Keep sessions fast and focused | /clear + small CLAUDE.md |
| Share a workflow with the team | Skill checked into git |

---

### 15. Thank You

**Closing line:** Claude Code works best when the context is intentional — not accidental.
