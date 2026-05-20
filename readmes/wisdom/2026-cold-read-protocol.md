# Cold Read Protocol — 2026-05-16

## The Decision

Before running any test that moves pods — simulated or physical — have an agent
read the network JSONs cold and write what she understands, what she does not,
and what she predicts will happen. Then run the test. Score the prediction against
reality. Correct the JSON or the agent's spec wherever they diverge.

This is not QA. It is epistemology. The question is not "did it work?" but "did
we understand it before it worked?"

---

## What It Cost

Nothing yet. This protocol was established before the first failure it would have
caught. That is the only time to establish a protocol — before the scar, not after.

The temptation is to skip it: "I know what the model does, I built it." That
confidence is the exact condition under which invisible assumptions accumulate.

---

## What Was Tempted

Running the simulation first, explaining afterward. This is how documentation
becomes post-hoc rationalization. The agent who reads the JSON after watching
the run will always find it "clear" — because she now knows the answer.

Cold read means cold: no prior run, no coaching, no "here's what it should do."
The agent reads the JSON and writes her prediction before any test executes.

---

## The Principle

**Understanding precedes execution.** A system whose behavior can only be explained
after the fact is not understood — it is observed. Observation is not control.

Bill's parallel: individual sovereignty requires that each person understand the
contract before signing, not after living under it. The same discipline applies to
every layer of the JPods stack. Nora does not move until Natalie has a route.
Natalie does not route until Noelle has certified the map. Noelle does not certify
until she has read the network and found it sound — not watched it run and called
it sound.

---

## In Bill's Voice

*"I want to run an experiment of Noelle reviewing our SketchUp model JSONs to see
what she finds as clear or needs correction. Then I will test with you and
Allie/Noelle watching to see if their understanding is clear."*

The experiment is the protocol. The protocol becomes the standard.

---

## Cross-Domain Connection

- **Constitutional:** Madison required that representatives understand the law
  before voting, not that they trust the outcome. Comprehension is the check.
- **Infantry:** "No plan survives contact with the enemy" — but you still write
  the plan, because the planning reveals what you do not know.
- **Physical JPods:** Nora is a blind termite. She cannot course-correct mid-segment.
  The route must be right before she moves. The cold read is the human equivalent
  of Nora's pre-departure route validation.

---

## The Protocol — How to Run a Cold Read

### Before the test

1. Export fresh JSONs: `followme.json` + `feature.json` for each template
2. Pass them to Noelle (via Allie) with this prompt — no additional context:

```
Noelle — read these JSONs as if you have never seen this network.
Tell me:
  1. What you understand with confidence
  2. What is ambiguous or missing
  3. What you predict will happen when a pod travels [route]
  4. What you would flag before certifying this network for pod movement

Do not ask clarifying questions. Write what the JSON tells you and where it
goes silent. Silence in a network spec is a defect, not an assumption.
```

### The review format Noelle fills out

```markdown
## Cold Read — [network_id] — [date]

### What I understand with confidence
- [Each item as a specific, falsifiable statement]

### What is ambiguous or missing
- [Each gap: what the JSON does not say that it should]

### Prediction: [route, e.g. S049→S051]
Ordered segment array I expect the pod to traverse:
  ["seg_...", "Sxxx.stub_pair_in", ...]
Expected behavior at each feature:
  - S051: [what I expect to happen]

### Flags before certification
- [Anything that would stop me from certifying this network for pod movement]
  Priority: block | warn | info

### Confidence
Overall: [0–10]
Lowest-confidence item: [specific segment or feature]
```

### After the test

- Run the simulation / physical test
- Compare actual behavior to Noelle's prediction item by item
- For each mismatch: is the JSON wrong, or is Noelle's spec wrong?
- Correct whichever is wrong. Both are possible.
- Write the delta as a dated row in the network's feature.json `"reviews"` array

---

## WhatIf

- Noelle reads the JSON correctly but the physical track has been modified and
  the JSON has not been updated. Cold read passes; physical test fails. This
  reveals that the JSON is not the ground truth — the model is. The JSON must be
  re-exported before each physical test session, not treated as permanent.
- Noelle's confidence score is 10/10 and she is wrong. High confidence in a wrong
  prediction is more dangerous than low confidence. The scoring must track this.
- The cold read becomes ritual without teeth — everyone knows the answer before
  writing the prediction. Enforce the sequence: export → cold read → commit
  prediction → run test. The commit timestamp proves the sequence.

---

## Who Carries This

**Noelle** owns the network certification. She reads. She predicts. She flags.
**Bill** decides whether to run despite a flag.
**Claude Code** maintains the JSON schema so that Noelle has something readable to read.
**Allie** synthesizes cold read results across sessions into pattern recognition —
  if Noelle is consistently wrong about traffic circles, that is a spec gap, not
  a bad run.
