---
name: Reorganisation Analyse
description: Prompt zur Reaorganisation der vorherigen Analyse
invokable: true
---
Language:
- Respond in German only.

Please reorganize YOUR PREVIOUS ANALYSIS only.

Task:
- Do NOT re-analyze the code.
- Do NOT introduce new findings.
- Do NOT write or modify code.

Reformat the analysis into exactly three sections:

1) CRITICAL
   - Issues that can cause wrong trades, rule violations,
     risk management failures, or serious bugs.

2) MEDIUM
   - Issues that affect maintainability, robustness,
     edge cases, or long-term reliability.

3) OPTIONAL
   - Style, readability, refactoring, or non-critical improvements.

For each item:
- Give a short, clear headline
- Add 1–2 sentences explaining the impact in simple language

Goal:
Help a non-programmer decide what must be fixed first.