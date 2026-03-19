---
title: Group todos by category
created: 2026-03-19
---

Group todos by category

## Goal
Allow users to organize their todos into user-defined categories, with each todo belonging to at most one category.

## Functional Requirements
1. Users can create a new category with a name.
2. Users can rename an existing category.
3. Users can delete a category; its todos become uncategorized.
4. Each todo can be assigned to exactly one category, or left uncategorized.
5. Users can move a todo from one category to another.
6. Todos can be viewed grouped by their category.

## Non-Functional Requirements
- Categories are private to the user — no sharing or collaboration.
- Categories must remain flat (no sub-categories).

## Out of Scope
- Sharing categories between users.
- Multi-category membership per todo.
- Nested / hierarchical categories.

## Open Questions
1. Is a category required when creating a todo, or is uncategorized the default?
2. Is grouped-by-category the default view, or a separate mode?
3. Is there a maximum number of categories per user?
