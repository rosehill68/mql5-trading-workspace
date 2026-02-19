---
name: Reparatur zu bestimmten Issues 
description: Prompt zur Reparatur von ganz bestimmten Issues aus der Analyse von BeWater_v7.40
invokable: true
---

Working Mode: Fix

Language:
- Respond in German only.

Scope:
CRITICAL issues 1 to 3 ONLY.

Rules:
- Fix ONLY the issues listed below
- Do NOT change any other logic
- Do NOT refactor unrelated code
- Preserve all existing features, inputs and comments
- Apply minimal changes only
- Update the version number
- Code must compile cleanly under MQL5

Issues to fix:

1) News Filter Logik (1 Zeile ändern: return false → return true)

2) Signal-Duplikation (Bar-Check in OnTick einbauen)

3) Implenentation of real Supertrend-Algorithm for Trailing-Stops


Tasks:
- Identify the correct location(s) where these issues originate
- Add or correct the minimal required definitions
- Ensure semantic consistency with existing logic
- Ensure the EA compiles without errors

Output requirements:
- Show only the modified code sections
- Explain briefly what was changed and why
- Confirm that no other functionality was modified