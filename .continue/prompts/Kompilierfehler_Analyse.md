---
name: Kompilierfehler Analyse
description: Prompt zur Analyse und Zusammenfassung von Kompilierfehlern
invokable: true
---

Working Mode: Analysis

Language:
- Respond in German only.

Scope:
Compiler errors ONLY.

Rules:
- Do NOT write or modify code
- Do NOT refactor
- Do NOT fix anything yet

Task:
Analyze the following MetaEditor compiler error list.

Goals:
- Group errors by root cause
- Identify which errors are primary causes and which are follow-up errors
- Propose a minimal fix order (Root Cause 1, 2, 3, ...)
- Map each root cause to the affected files and lines

Output requirements:
- Clear list of root causes (numbered)
- For each root cause:
  - short explanation
  - affected files
  - estimated impact
- Do NOT propose code changes yet