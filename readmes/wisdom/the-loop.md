# The Loop

**Source:** Bill James, 2026-07-17

---

1. **Define metrics.** Before acting, name what you will measure. If you
   can't name the metric, you don't understand the goal.

2. **Try now.** Not after more study. Not after the perfect plan. Now.
   Propensity for action. The first attempt is data, not failure.

3. **Measure in retrospection outcomes.** After the action, measure what
   happened against what you said would happen. The gap between prediction
   and outcome is the lesson.

4. **Adjust.** Change the approach based on what the measurement revealed.
   Not what you hoped. Not what you planned. What you measured.

5. **Loop to home in on the optimum of this frame.** Repeat 1–4. Each
   iteration narrows the gap between action and outcome. Each loop makes
   the next loop faster and more accurate. This is convergence.

6. **Then inspect the frame.** After convergence — not before — question
   whether the frame itself is right. Are we optimizing the right thing?
   Is the metric measuring what matters? Is the goal still the goal?
   Adjust the frame or confirm it. Then loop again within the new frame.

---

## Why Frame Inspection Comes Last

The temptation is to question the frame before trying. "Are we even
measuring the right thing?" becomes an excuse for not measuring at all.

Run the loop first. Converge within the frame. The convergence itself
reveals whether the frame is viable:

- **If the loop converges and outcomes improve** → the frame is viable.
  Keep it. Refine it.

- **If the loop converges but outcomes don't improve** → the frame is
  wrong. The metric doesn't connect to what matters. Change the frame.

- **If the loop doesn't converge** → the system is chaotic within this
  frame. The frame is too narrow or too broad. Adjust scope.

You cannot know which of these is true without running the loop.
Frame inspection without data is philosophy. Frame inspection with
data is engineering.

---

## Applied Everywhere

| Domain | Define metric | Try now | Measure | Adjust | Inspect frame |
|--------|-------------|---------|---------|--------|---------------|
| Reports | use_count, user_count | Barn clean today | Usage after 30 days | Deactivate unused, promote popular | Are these the right report categories? |
| Templates | adoption_count, feedback_score | Submit to library | Review outcomes | Improve layout, update description | Is pdfme the right engine? |
| JPods physical | motor_current, trip_duration | Run pods | Nora/Sally baselines | Replace worn parts, recalibrate | Are we measuring the right sensors? |
| Alice coaching | question_accuracy, user_satisfaction | Deploy quiz | Score responses | Refine training data | Are we coaching the right behaviors? |
| WC3 transactions | conversion_rate, error_rate | Process orders | GL reconciliation | Fix flow, update validation | Is the transaction model right? |
| Network design | mode_shift_%, payback_years | Build Greenville | Traffic counts post-deploy | Adjust station placement | Is the demand model right? |
| Collaboration | accept_rate, submit_rate | Enable WCHQ sync | Monthly review | Tune categories on/off | Is the library model right? |

---

## The Relationship to Other Principles

**Memory → Measurement → Retrospection** (from CLAUDE.md):
The Loop is the operational form of this axiom. Memory markers are
the metrics. Retrospection is the measurement step. The loop is what
makes the axiom do work instead of sitting on a page.

**Fear → Delight** (from fear-and-delight.md):
The Loop is how fear transforms into delight. Fear says "don't try."
The Loop says "try, measure, adjust." After a few iterations, the user
has data instead of fear. Data produces confidence. Confidence produces
action. Action produces delight.

**Suffer now so our children do not suffer later** (from agent-flags.md):
The Loop is the mechanism. Suffering = trying and failing in iteration 1.
Not suffering later = the convergence that iterations 2–N produce.
The red flag that should have been an orange is a loop that wasn't run.

**Excellence is the process of relentlessly improving:**
The Loop is that process, made concrete and measurable.

---

## Constrained Variability Before Frame Inspection

> *"Until we have constrained variability, we do not know if we are
> dealing with an action issue or a concept issue."*

This is why frame inspection comes after convergence, not before.

When variability is high — results scatter, outcomes are unpredictable,
the same inputs produce different outputs — you cannot tell whether
the problem is execution (action) or design (concept). Both look
the same from the outside.

The Loop constrains variability. Each iteration reduces scatter.
As the system converges, the signal separates from the noise.
Only then can you see:

- **Variability constrained, outcomes good** → action and concept both right
- **Variability constrained, outcomes bad** → concept is wrong (frame issue)
- **Variability won't constrain** → action is wrong (execution issue)

Questioning the concept before constraining the variability is
premature. You'll change the design based on noise, not signal.

## Fear of Scars Is Fear of Wisdom

> *"We only learn through scars. Fear of scars is fear of wisdom."*

The Loop produces scars. Iteration 1 fails. Iteration 2 fails
differently. Each failure is a scar — and each scar is data.

The difference between scars and wounds:
- A **wound** is damage without learning. The same mistake repeated.
- A **scar** is damage with learning. The mistake that taught something.

The Loop converts wounds to scars. Without measurement, failure is
just a wound — it hurts and teaches nothing. With measurement, failure
becomes a scar — it hurts and produces wisdom.

Fear of scars is fear of the Loop. Fear of the Loop is fear of
improvement. And fear of improvement is how systems calcify into
the 292-form barns that users drown in.

The barn cleaner is scar-making, deliberately. Every report trashed
is a small scar: "I decided this had no value." Some of those
decisions will be wrong. The recovery cost is small. The wisdom
gained — "I know what I need and why" — is permanent.
