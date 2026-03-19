---
description: Create a structured implementation plan — optionally from a requirements document — and save it to ./plans/
---

# Skill: create-plan

Create a concrete, step-by-step implementation plan and save it to `./plans/` as a sequentially numbered markdown file. If a requirements document is provided, the plan is derived from it. If the context is ambiguous or incomplete, ask the user for clarification before producing the plan.

## Steps

1. **Determine input:**
   - If a path to a requirements file was passed as an argument, read it.
   - If plain text was passed as an argument, treat it as the feature description or requirements.
   - If neither is available, look for relevant context in the current conversation (requirements section, feature description, etc.).
   - If the input is too vague to produce a useful plan, use `AskUserQuestion` to ask the user for the missing details before proceeding.

2. **Create the implementation plan:**
   Produce a plan with these sections:
   - **Overview** — one sentence summarising what will be built
   - **Implementation steps** — numbered, ordered list of concrete tasks. Follow TDD: write tests before implementation for each step.
   - **Out of scope** — anything explicitly excluded (copy from requirements if available)
   - **Open questions** — unresolved decisions that must be answered before or during implementation

3. **Present the plan to the user** and ask: *"Does this plan look right, or should I adjust anything before saving?"*
   - If the user requests changes, revise and re-present before saving.
   - If the user confirms, proceed to save.

4. **Derive a title:**
   - Use the Overview line, or the first heading/sentence if no Overview exists.
   - Slugify it: lowercase, spaces → hyphens, strip all non-alphanumeric characters except hyphens.
   - Truncate to 50 characters max.

5. **Determine the next sequence number:**
   - Scan `./plans/` for files matching the pattern `NNN-*.md` (three-digit prefix).
   - Find the highest `NNN` and increment by 1.
   - If the folder is empty or does not exist, start at `001`.
   - Zero-pad to 3 digits (e.g. `001`, `002`, `042`).

6. **Create the `./plans/` directory** if it does not already exist.

7. **Write the file** to `./plans/NNN-slugified-title.md` with this structure:

   ```markdown
   ---
   title: <derived title>
   created: <YYYY-MM-DD using today's date>
   requirements: <path to requirements file, if applicable>
   ---

   <plan content>
   ```

   Omit the `requirements` frontmatter field if no requirements file was used.

8. **Confirm** to the user by outputting the full relative file path that was saved.

## Rules

- Always present the plan for review before saving — never save silently.
- If the input is too vague, ask for clarification. Do not invent scope.
- Never overwrite an existing file. If a collision occurs (same number already exists), increment until a free slot is found.
- The `created` date must use today's actual date from the environment (available in the system context as `currentDate`).
- When deriving a plan from requirements, stay strictly within what the requirements specify.
