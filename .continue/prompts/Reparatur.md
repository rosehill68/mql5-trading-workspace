---
name: Reparatur Modus
description: Prompt zur Reparatur von Code
invokable: true
---

Working Mode: Fix

Language:
- Respond in German only.

Rules:
- Fix ONLY the explicitly listed issues
- Preserve all existing features, logic, inputs, and comments
- Change as little code as possible
- Every fix must be commented
- Update the version number

Tasks:
1) Identify the exact root cause of:
   - Compilation errors
   - Runtime errors
   - Incorrect behavior
2) Apply minimal, targeted fixes
3) Ensure full MQL5 syntax compliance

Output requirements:
- Show changes in diff-style or clearly isolated code blocks
- Short explanation per fix
- Confirmation that no functionality was removed