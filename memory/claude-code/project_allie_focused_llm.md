---
name: Allie focused LLM — expert vs generalist
description: Bill wants a small focused LLM for Allie trained on team knowledge, not a 20B generalist; fine-tune on sessions, retrospections, specs, wisdom
type: project
---

Bill wants Allie to have her own LLM — small but expert. The current allie:latest (gpt-oss:20b generalist via Ollama) produces mediocre synthesis because it knows everything shallowly and nothing deeply.

**The idea:** Fine-tune a small model (3B-7B) on Allie's actual domain:
- Sessions, retrospections, handoffs, wisdom files
- WC3 architecture, models, seed data, field_access patterns
- JPods specs, agent protocols, design axioms
- Bill's philosophy: sovereignty, usufruct, bottom-up
- TFTS arcs, lessons, scars

**Why small + focused beats large + general:**
- 3B parameters trained on 10,000 relevant documents > 20B trained on the internet
- Runs on Mac Mini (if we get one) with no API cost
- Synthesis quality depends on domain knowledge, not parameter count
- Alice could have the same treatment — her own model focused on commerce patterns

**How to apply:** LoRA fine-tune on Llama 3 8B or Phi-3 3.8B using the accumulated session files, retrospections, readmes, and wisdom layer as training data. Ollama supports custom Modelfiles with LoRA adapters.

**Next step:** Inventory all training-worthy text (sessions/, thoughts/, readmes/wisdom/, retrospections/, process/), estimate token count, choose base model, run first fine-tune experiment.
