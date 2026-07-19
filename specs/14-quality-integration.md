# SPEC-14: Quality Integration — Specs, Actions, and Sprints

**Status:** Draft
**Revision:** 0
**Date:** 2026-07-19
**Responsible:** Bill James
**Sunset:** 2027-07-19
**Standards:** QM-01, QM-09.1, QM-14, ISO 9001, ASTM F770, FTA 49 CFR 673

---

## 1. Intent

The quality plan is not a document that sits next to the work. It IS the work. Every specification requirement, every inspection, every nonconformance, every corrective action, every training task, and every flag resolution lives as an Action record inside a Project, staged into weekly sprints. Nothing exists outside this structure. If it's not an Action in a Project, it's not real.

This spec defines how the 13 engineering specs (SPEC-01 through SPEC-13), Gordy's quality procedures (QM-00 through QM-19), ASTM F24 compliance, FTA 49 CFR 673 safety management, and the daily work of building JPods all converge into one system: WC3 Projects with Actions in sprints.

## 2. Structure

### 2.1 Project Hierarchy

| Level | WC3 Model | QM Equivalent | Example |
|-------|-----------|---------------|---------|
| **Program** | Project (type=program) | QM-09.1 Level 1 | "JPods Quality Program" |
| **Project** | Project (type=project) | QM-09.1 Level 2 | "Bogie v22 Production" |
| **Sprint** | Project (type=sprint, parent=project) | Weekly scrum cycle | "W30 — 2026-07-20" |
| **Action** | Action (parent=sprint) | QM-09.1 Level 3 Task | "Resolve RED: temp range conflict" |
| **Document** | Document (parent=action) | QM-16 Quality Record | "SPEC-01 temp analysis.md" |
| **QA** | QuestionAnswer (parent=action or item) | QM-10 Inspection Record | "Daily pre-op: Bogie 001" |

### 2.2 Program Structure

```
Program: JPods Quality Program
│
├── Project: Engineering Specs
│   ├── Sprint W30: RED flag resolution
│   ├── Sprint W31: ORANGE flag resolution (batch 1)
│   ├── Sprint W32: ORANGE flag resolution (batch 2)
│   └── Backlog: YELLOW flags (promote when understood)
│
├── Project: Production — Bogie v22
│   ├── Sprint W30: First article inspection
│   ├── Sprint W31: Procurement — motor, wheels, spacers
│   └── Backlog: Spare parts system build-out
│
├── Project: Production — 170m Guideway (Al Karia)
│   ├── Sprint W30: Soil borings (RED flag)
│   ├── Sprint W31: Marwan HSS verification
│   └── Backlog: Truss member calc package
│
├── Project: Compliance
│   ├── Sprint W30: ASTM F770 inspection templates loaded
│   ├── Sprint W31: FTA 49 CFR 673 Agency Safety Plan draft
│   └── Backlog: ASTM F24 committee participation
│
├── Project: Onboarding & Training
│   ├── Sprint W30: Git training quiz live
│   ├── Sprint W31: QUIZ-SAFETY-DAILY live
│   └── Backlog: Per-spec quizzes (12 specs × 1 quiz each)
│
├── Project: Inspections (recurring)
│   ├── Daily: Vehicle pre-op (per serialized vehicle)
│   ├── Daily: Station pre-op (per serialized station)
│   ├── Weekly: Guideway segment (per serialized segment)
│   ├── Monthly: MtG calibration (per station)
│   └── Annual: Engineering review (system-wide)
│
└── Project: Document Management
    ├── Sprint W30: Repos created, access control set
    ├── Sprint W31: Vendor onboarding to git
    └── Backlog: CI/CD linting pipeline
```

## 3. Requirements

| ID | Requirement | Justification | RP | Date | Flag |
|----|-------------|---------------|----|------|------|
| R-14-001 | Every spec requirement (R-XX-NNN) with a flag (YELLOW, ORANGE, RED) shall have a corresponding Action record in WC3 | Flags without actions are wishes; actions without owners are orphans | BJ | 2026-07-19 | |
| R-14-002 | RED flags shall be in the current sprint | RED = stop everything; must be resolved this week or explicitly escalated with reason | BJ | 2026-07-19 | |
| R-14-003 | ORANGE flags shall have a fix_by date and be staged into a named sprint | No open-ended ORANGEs; can't set a date → it's YELLOW or RED | BJ | 2026-07-19 | |
| R-14-004 | YELLOW flags shall sit in the backlog until promoted to ORANGE (understood) or dismissed (not applicable) | YELLOWs are honest "I don't know" — the most valuable learning signal; they earn their place in the backlog | BJ | 2026-07-19 | |
| R-14-005 | Every Action shall have: owner (who), description (what), justification (why), sprint (when), spec reference (where), and sunset (when it expires if not acted on) | Gordy's spec template: "Everything practical will have a Responsible Person, reason, date" | BJ | 2026-07-19 | |
| R-14-006 | Recurring inspections (daily, weekly, monthly, annual) shall be recurring Actions that auto-generate from templates | ASTM F770 requires inspections at defined intervals; auto-generation prevents missed inspections | BJ | 2026-07-19 | |
| R-14-007 | Each recurring inspection Action shall stamp QA (QuestionAnswer) records from the Document-based template onto the serialized item being inspected | Inspection history accumulates on the item, not in a filing cabinet; any auditor can pull the full inspection record for any vehicle/station/segment | BJ | 2026-07-19 | |
| R-14-008 | NCR Actions (type=ncr) shall be created immediately when a nonconformance is identified — not at end of shift, not at weekly review | QM-13: "Originator identifies and segregates FIRST, then completes NCR fields 1-8." Delay = risk. | BJ | 2026-07-19 | |
| R-14-009 | CAR Actions (type=car) shall reference the originating NCR Action and track: root cause, corrective action, preventive action, verification, close-out | QM-14 full lifecycle; verification includes "Was action taken effective? Yes/No" | BJ | 2026-07-19 | |
| R-14-010 | D/W Actions (type=dw) shall require approval chain: Responsible Manager → Program Manager → Quality Director → Customer (if applicable) | QM-13.1: Deviation/Waiver has a defined approval chain; Action status transitions enforce this | BJ | 2026-07-19 | |
| R-14-011 | Weekly sprint review shall include: open flag count by color, open NCR/CAR count, overdue Actions, inspection compliance rate | QM-01: Management review covers open actions, changes affecting quality, metrics, improvement opportunities | BJ | 2026-07-19 | |
| R-14-012 | Sprint retrospection shall measure performance against memory markers per CLAUDE.md protocol | "No memory without retrospection. No retrospection without measurement. No measurement without memory markers." | BJ | 2026-07-19 | |
| R-14-013 | Every spec (SPEC-01 through SPEC-13) shall have its own Project or be a sub-project of Engineering Specs | Specs are living documents; their flag resolution, change history, and review cycles are managed as project work | BJ | 2026-07-19 | |
| R-14-014 | Training Actions shall link quiz results (pass/fail/score) to the Contact record of the person trained | QM-18 requires training records per person; FTA §673.29 requires safety promotion documentation | BJ | 2026-07-19 | |
| R-14-015 | Alice shall generate weekly sprint summary: flags resolved, NCRs opened/closed, inspections completed, training passed | Automated reporting; no manual status assembly; Alice reads the same Action records everyone writes | BJ | 2026-07-19 | |
| R-14-016 | Burn-down tracking: each sprint shall show Actions planned vs completed | Spec template Section 7 (Scrum behaviors): "Burn-down charts" | BJ | 2026-07-19 | |
| R-14-017 | Common Parts System (CoPS) reviews shall be a recurring weekly Action | Spec template Section 8: "Daily Common Parts Team approves any new part to any Bill of Materials" — weekly for JPods scale | BJ | 2026-07-19 | |
| R-14-018 | Serialized items (vehicles, stations, guideway segments) shall accumulate their full lifecycle history as Actions: manufacture, inspect, maintain, repair, NCR, CAR | QM-08 Product Identification and Traceability; the item record IS the logbook | BJ | 2026-07-19 | |

## 4. Action Types and Lifecycle

### 4.1 Action Types

| Type | QM Source | Created When | Closed When |
|------|-----------|-------------|-------------|
| `flag_red` | SPEC flags | Spec review identifies RED | Requirement resolved, spec updated, flag removed |
| `flag_orange` | SPEC flags | Spec review identifies ORANGE | Solution implemented, spec updated, flag removed or promoted |
| `flag_yellow` | SPEC flags | Spec review identifies YELLOW | Promoted to ORANGE (understood) or dismissed (not applicable) |
| `ncr` | QM-13 | Nonconformance identified | Disposition complete, item released or scrapped |
| `car` | QM-14 | Root cause investigation needed | Corrective action verified effective |
| `dw` | QM-13.1 | "Use as is" or "repair" disposition | Approval chain complete |
| `inspection` | QM-10, F770 | Schedule (daily/weekly/monthly/annual) | All QA questions answered, disposition recorded |
| `calibration` | QM-11 | Schedule (monthly for MtG sensors) | All sensors verified within tolerance |
| `training` | QM-18 | New person or annual refresh | Quiz passed at required score |
| `design_review` | QM-04.2 | Design phase milestone | Review complete, findings documented |
| `audit` | QM-17 | Annual schedule or triggered | Audit report issued, CARs raised if needed |
| `procurement` | QM-06 | Part needed | Part received, inspected, accepted |
| `common_parts` | QM spec 8 | New part proposed for any BOM | Approved or rejected by CoPS review |
| `spec_change` | QM-05/SPEC-13 | Spec requirement needs modification | PR approved, spec updated, vector store re-indexed |

### 4.2 Action Lifecycle States

```
created → assigned → in_progress → review → approved → closed
                                      ↓
                                   rejected → in_progress (rework)
```

For NCR specifically:
```
identified → segregated → investigated → dispositioned → implemented → re-inspected → closed
```

For D/W specifically:
```
requested → rm_approved → pm_approved → qd_approved → customer_approved → closed
              ↓              ↓              ↓               ↓
           rejected       rejected       rejected        rejected
```

## 5. Sprint Cadence

| Day | Activity | QM Reference |
|-----|----------|-------------|
| **Monday** | Sprint planning — move Actions from backlog to sprint; review flags | QM-09.1 Formulation |
| **Daily** | Standup — barriers to achievement; inspection results | QM-09.1 Implementation |
| **Wednesday** | Code scrub 2PM GMT; commercial clearing 3PM GMT | Weekly coordination day |
| **Friday** | Sprint review — burn-down, flag count, NCR/CAR status, inspection compliance | QM-01 Management Review (condensed) |
| **Friday** | Retrospection — measure against memory markers | CLAUDE.md protocol |

## 6. Metrics Dashboard (Alice generates weekly)

| Metric | Source | Target |
|--------|--------|--------|
| RED flags open | Action records (type=flag_red, status≠closed) | 0 |
| ORANGE flags overdue | Action records (type=flag_orange, fix_by < today) | 0 |
| Open NCRs | Action records (type=ncr, status≠closed) | Trending down |
| Open CARs | Action records (type=car, status≠closed) | Trending down |
| Inspection compliance | Inspections completed / inspections due | 100% |
| Training currency | Contacts with current quiz passes / total contacts | 100% |
| Sprint velocity | Actions closed this sprint / Actions planned | ≥ 80% |
| Common Parts reviews | New parts reviewed / new parts proposed | 100% |
| Document commits | Commits this week to project repos | Tracked (no target) |
| MtG drift alerts | Stations with gap drift > 2mm/30 days | 0 |

## 7. Interfaces

| Interface | Spec | Boundary | Notes |
|-----------|------|----------|-------|
| All specs | SPEC-01–13 | Every flagged requirement = Action | This spec manages the flags |
| Quality Program | SPEC-12 | NCR/CAR/D-W/inspection/audit = Action types | SPEC-12 defines what; this spec defines how they're managed |
| Document Management | SPEC-13 | Spec changes = PR = Action (type=spec_change) | Git is the document system; Actions track the review cycle |
| Serialized Items | WC3 Item model | Inspections/NCRs/maintenance attach to items | Item accumulates lifecycle |
| Alice | WC3 | Weekly summary generation; recurring Action creation | Alice automates the paperwork |
| Andi | IT15 | Monitors compliance; flags overdue Actions | Andi is the night watch |
| Contacts | WC3 | Training records; Action ownership | Every Action has a human owner |

## 8. First Sprint — W30 (2026-07-20)

### RED Flag Resolution (13 items — all must be in this sprint)

| Action | Spec | RED Flag | Owner |
|--------|------|----------|-------|
| Resolve temperature range: chassis -40C vs bogie -10C | SPEC-01, SPEC-02 | Specs must agree on operating range | BJ |
| Verify HSS 18 vs HSS 20 with Marwan | SPEC-03 | Base plate references HSS 18x0.5, column spec says HSS 20x0.5 | BJ/Marwan |
| Confirm roundabout column section matches base plate | SPEC-03 | Related to HSS mismatch | BJ/Marwan |
| Confirm subsurface soil borings planned before construction | SPEC-03 | Footings designed on assumed 3.5 ksf — site-specific data required | BJ |
| Confirm footing design will be updated with boring results | SPEC-03 | Current calcs are preliminary — must be redone with actual soil data | BJ/Marwan |
| Spec battery fire protection system | SPEC-06 | Safety critical — no design exists | BJ |
| Define V2V collision avoidance protocol | SPEC-07 | No vehicle operation without collision avoidance | BJ |
| Define V2V collision avoidance comms architecture | SPEC-07 | Related — needs protocol + implementation | BJ |
| Perform SIL classification per IEC 61508 | SPEC-09 | Safety integrity level determines software rigor | BJ |
| Decide fail-safe vs fail-operational per function | SPEC-09 | Must decide before deployment | BJ |
| Classify all software functions by risk level per QM-04.1 | SPEC-09 | Risk classification drives testing requirements | BJ |
| Define safety interlock architecture | SPEC-09 | Which interlocks are hardware vs software | BJ |

### Infrastructure (also W30)

| Action | Owner |
|--------|-------|
| Run WC3 migration 0006 (Document FK on QuestionAnswer) | BJ |
| Load qa-documents.json into WC3 Document records | BJ |
| Create Project "JPods Quality Program" in WC3 | BJ |
| Deploy Andi on IT15 (hardware arrives Monday) | BJ |

## 9. Quality Records

| Record | Retention | Custodian | Per QM- |
|--------|-----------|-----------|---------|
| Sprint plans and reviews | 3 years | Alice | QM-01 |
| Action records (all types) | 5 years | Alice/WC3 | QM-16 |
| Inspection QA records | 5 years | Alice/WC3 | QM-10, QM-16 |
| NCR/CAR/D-W records | 5 years | Alice/WC3 | QM-13, QM-14, QM-16 |
| Training quiz results | 3 years | Alice/WC3 | QM-18 |
| Sprint retrospections | 3 years | Git (readmes/retrospections/) | QM-01 |
| Weekly metrics dashboard | 2 years | Alice | QM-01 |

## 10. Change History

| Rev | Date | Change | By |
|-----|------|--------|----|
| 0 | 2026-07-19 | Initial release | Bill James / Claude Code |
