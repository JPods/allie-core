---
name: Robot agents on Andi
description: Nora/Noelle/Matilda/Sally deployed to Andi with gpt-oss:20b; daily coaching; MQTT router; deploy script at ~/Allie/robots/agents/
type: project
---

2026-08-12: Built complete robot agent infrastructure at ~/Allie/robots/agents/

**Why:** Physical domain agents (Nora, Noelle, Matilda, Sally) need persistent storage + processing that survives Pi reboots and Mac sleep. Andi is always-on sovereign hardware already running Allie and Alice.

**How to apply:**
- Deploy with: `bash ~/Allie/robots/agents/deploy-agents.sh`
- All agents share Andi's gpt-oss:20b Ollama (NOT deepseek-r1:8b — Bill's explicit direction)
- Daily schedule: coaching at 01:00, reflects 02:00-02:45, Allie 03:00, Andi 04:30
- coach-agents.py feeds cross-domain WC3/R25 patterns to all agents daily — keeps distillation loop turning while robots are idle
- MQTT router (agent-mqtt-router.py) feeds live telemetry to agent inboxes when robots run
- NOT YET DEPLOYED to Andi as of 2026-08-12

**Next session (2026-08-13):** Bill wants whole team review of WC3 + robot codebases (JRobots_4WD, JPodsSM_RPi) + su_jpods to write forward plan. Also review similar open-source robot code.
