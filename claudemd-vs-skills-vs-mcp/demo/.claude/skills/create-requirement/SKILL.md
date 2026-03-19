---
description: Save a requirements document to the ./requirements/ folder as a sequentially numbered markdown file
---

# Skill: create-requirement

Save a requirements document to `./requirements/` as a sequentially numbered markdown file with YAML frontmatter.

## Steps

1. **Determine requirement content:**
   - If text was passed as an argument to the skill, use that as the document body.
   - Otherwise, look for a section titled "Requirements" (or equivalent) in the current conversation and extract it.
   - If neither is available, synthesize a requirements summary from the conversation context.

2. **Derive a title:**
   - Use the **Goal** line in the content, or the first heading/sentence if no Goal exists.
   - Slugify it: lowercase, spaces → hyphens, strip all non-alphanumeric characters except hyphens.
   - Truncate to 50 characters max.

3. **Determine the next sequence number:**
   - Scan `./requirements/` for files matching the pattern `NNN-*.md` (three-digit prefix).
   - Find the highest `NNN` and increment by 1.
   - If the folder is empty or does not exist, start at `001`.
   - Zero-pad to 3 digits (e.g. `001`, `002`, `042`).

4. **Create the `./requirements/` directory** if it does not already exist.

5. **Write the file** to `./requirements/NNN-slugified-title.md` with this structure:

   ```markdown
   ---
   title: <derived title>
   created: <YYYY-MM-DD using today's date>
   ---

   <requirement content>
   ```

6. **Confirm** to the user by outputting the full relative file path that was saved.

## Rules

- Never overwrite an existing file. If a collision occurs (same number already exists), increment until a free slot is found.
- The `created` date must use today's actual date from the environment (available in the system context as `currentDate`).
- Do not alter the requirement content — save it exactly as-is (after the frontmatter).
- If no requirement content can be determined, ask the user to provide it before proceeding.
