# Definitions First — Established 2026-08-03

## The Principle

Before building anything new, stop and define it. The definition is the contract.
Build without definitions and you get drift — three names for the same thing,
two things with the same name, boundaries no one agrees on.

## The Rule

Before breaking ground on any new concept, write:

1. **What is it called?** One name, used everywhere. No synonyms in code.
2. **What does it do?** One sentence, no "and." If you need "and," it's two things.
3. **What doesn't it do?** Boundaries prevent scope creep.
4. **Where does it live?** File path, Setting purpose, model, database table.
5. **Who owns it?** Which agent maintains it (Alice, Allie, Claude, user).

## Who Enforces It

- **Claude Code**: Before writing code for a new concept, check if the definition exists.
  If not, write the definition first. Do not code without it.
- **Alice**: Watches for undefined concepts in Settings, Reports, Actions.
  Flags anything that doesn't match a known definition.
- **Allie**: At nightly reflection, checks if new concepts from the session were defined.
  If not, adds to the "Questions for Bill" section.
- **Bill**: Reviews definitions at session start. Corrects misunderstandings early.

## Examples

Good: "form, detail, custom — three rendering paths, every model assigned to one."
Bad: "We'll figure out the layout approach as we go."

Good: "Setting holds system defaults. Report holds user outputs. Different models, different purposes."
Bad: "Let's put the reports in Settings for now and refactor later."

Good: "Widget library is a Setting. Each widget has: id, applies_to, renders, click, shift_click, hover."
Bad: "We'll add widget support to the label somehow."

## Why This Matters

Three agents (Claude, Allie, Alice) with different memory models. Claude resets every session.
Allie persists but only knows what was written down. Alice observes but doesn't infer intent.

Definitions are the shared language. Without them, each agent interprets differently.
With them, any agent can pick up where another left off — because the contract is explicit.

## The Cost of Not Doing This

- ContactDetail.tsx grew to 4,114 lines because "contact detail" was never defined as a composition of defined sub-components
- TransactionDetailBase.tsx grew to 3,404 lines because the boundary between "base" and "specific" was never defined
- Three ContactDetail variants (1, 2, 3) exist because no one defined which one is canonical
- 2,000 lines of communication detail code because the shared behavior was never defined as a concept

Define first. Build second. Every time.
