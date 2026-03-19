---
description: Interview the user about requirements, surface contradictions, and produce a requirements document
---

# Skill: interview-me

Conduct a structured requirements interview. Ask focused questions one at a time, identify contradictions or gaps as they emerge, then synthesize everything into a requirements document.

## Steps

1. Use `AskUserQuestion` to ask: *"What are you trying to build or solve? Give me a rough description."*
2. Based on the answer, ask 3–5 targeted follow-up questions — one at a time — to clarify:
   - Who is the user / who benefits?
   - What does success look like?
   - What are the constraints (time, tech stack, team size)?
   - What must NOT happen (non-goals, anti-requirements)?
   - Are there any existing systems or dependencies involved?
3. After each answer, silently note any tension or contradiction with previous answers. Do not call them out mid-interview — collect them.
4. Once you have enough signal (or the user says they're done), present:
   - **Contradictions found** — specific conflicts between stated requirements, with a suggested resolution for each
   - **Open questions** — things that were not answered but matter for delivery
   - **Requirements** — a structured requirements document based on the confirmed answers, with sections:
     - **Goal** — one sentence describing what is being built
     - **Functional requirements** — numbered list of concrete behaviours the system must exhibit
     - **Non-functional requirements** — constraints (performance, security, UX, etc.)
     - **Out of scope** — explicit non-goals
     - **Open questions** — unresolved decisions that must be answered before or during implementation
5. Ask the user if they want to save the requirements document using the `create-requirement` skill.

## Rules

- Ask one question at a time using `AskUserQuestion`. Never ask multiple questions in a single prompt.
- Do not propose solutions during the interview — just ask and listen.
- Do not skip to the requirements early. Complete the interview first.
- If the user's answer introduces a contradiction with something said earlier, note it internally but continue the interview.
- The requirements must be grounded only in what the user said — no invented assumptions.
- If a critical gap remains unresolved, flag it explicitly in the Open questions section rather than filling it in silently.
