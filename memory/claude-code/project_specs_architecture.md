---
name: JPods specs architecture
description: 12 unified specs at ~/Allie/specs/; 304 requirements; Yellow/Orange/Red flags; QA moved from Setting to Document; Gordy QM mapped to Alice
type: project
---

Built 2026-07-18: complete JPods spec library at ~/Allie/specs/.

**12 specs, uniform format:**
SPEC-01 Chassis, SPEC-02 Bogie, SPEC-03 Structures, SPEC-04 Guideway,
SPEC-05 Station, SPEC-06 Power, SPEC-07 Communications, SPEC-08 Interior,
SPEC-09 Software, SPEC-10 Solar Canopy, SPEC-11 Sensors, SPEC-12 Quality Program

**Flag system:** YELLOW (don't understand), ORANGE (understand problem, no solution), RED (stop everything)
- 13 RED flags: temp range conflict, HSS mismatch, battery fire protection, V2V collision avoidance, SIL classification, fail-safe decision
- 105 ORANGE, 80 YELLOW

**Compliance frameworks:**
- ASTM F24: F2291 (design), F770 (ops/maintenance/inspection), F1193 (quality/mfg), F2974 (auditing), F3598 (risk assessment)
- FTA 49 CFR 673: Safety Management System (4 pillars: policy, risk mgmt, assurance, promotion)

**QA architecture change:** Moved from Setting-based templates to Document-based.
Document has body (WHY narrative), refs (standards cross-refs), config (questions).
Code: QuestionAnswer.document FK added, QAService methods added, migration 0006.
5 inspection checklists + 3 training quizzes at ~/Allie/specs/qa-documents.json.

**Why:** Document is a better container — captures WHY we inspect, cross-references
standards and specs, has retention periods for compliance. Settings are configuration;
Documents are knowledge.

**Mind-the-Gap spec:** 17mm H / ±8mm V target (ASCE 21.2-2008 max: 25mm/±12mm).
Sensors at every door position, both sides. Measure unloaded AND loaded. Door locked
until loaded gap verified. All logged per boarding event for Andi drift analysis.
