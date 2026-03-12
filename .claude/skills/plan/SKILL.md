---
name: plan
description: Create a structured implementation plan for complex tasks. Analyzes the codebase, considers architectural trade-offs, identifies affected files, and produces a step-by-step strategy for review before any code changes.
model: opus
---

 ## Instructions

  1. **Gather context:**
     - If a file path is provided, read it and use its contents as the primary source for the plan. This file MUST be referenced in the plan under a "Source" section.
     - If no file is provided, ask the user to describe what they want to implement.

  2. **Explore the codebase:**
     - Identify relevant files, modules, and patterns.
     - Understand existing architecture and conventions.
     - Note any dependencies or constraints.

  3. **Create the plan:**
     - Write a markdown file with clear, actionable implementation steps.
     - Include sections for: Source (if applicable), Overview, Affected Files, Implementation Steps, and Considerations.
     - Keep steps concrete and sequential.

  4. **Save the plan:**
     - Plans are stored in the `plans/` folder at the project root or next to the prompt file that is used as an argument.
     - Create the folder if it doesn't exist.
     - Name the file with sequential numbering: `0001_{plan_name}.md`, `0002_{plan_name}.md`, etc.
     - Check existing files in `plans/` to determine the next number.
     - Use lowercase with underscores for the plan name (e.g., `0003_user_authentication.md`).

  5. **Present for review:**
     - Show the user the plan location and a summary.
     - Wait for approval before any implementation begins.

  ## Plan Template

  ```markdown
  ---
  source: {path to source file, if provided}
  created: {date}
  ---
  # Plan: {Title}

  ## Overview

  {Brief description of what will be implemented}

  ## Affected Files

  - `path/to/file.ts` - {what changes}
  - `path/to/other.ts` - {what changes}

  ## Implementation Steps

  1. {First step}
  2. {Second step}
  3. {Third step}
  ...

  ## Considerations

  - {Trade-offs, risks, or notes}