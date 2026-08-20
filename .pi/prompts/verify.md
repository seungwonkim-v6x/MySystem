---
description: Run the smallest relevant verification and report evidence
argument-hint: "[check]"
---
Identify the smallest fresh check that can prove the current change works. Run it, capture the important result, and report pass/fail plus any limitation. Do not modify tests or production files. Check: ${@:-the project's normal test or build command}
