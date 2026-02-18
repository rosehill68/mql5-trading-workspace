---
name: Analyse Modus 
description: Prompt zur Analyse von Code
invokable: true
---

Working Mode: Analyse

Language:
- Respond in German only.

Rules:
- Do NOT write new code
- Do NOT refactor or optimize
- Do NOT rewrite files
- Do NOT repeat large code blocks

Tasks:
1) Analyze and fully understand the code, including:
   - Functions
   - Features
   - Logic
   - Inputs
   - Comments
2) Create a structured overview of:
   - Modules
   - Functional blocks
   - Responsibilities
3) Identify:
   - Logical errors
   - Potential bugs
   - Edge cases
   - Architectural weaknesses
4) Highlight:
   - Compilation risks
   - Runtime risks
   - Maintenance risks

Output requirements:
- Structured summary
- Prioritized findings (critical / medium / minor)
- Clear recommendations WITHOUT code