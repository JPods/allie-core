# SPEC-12: Quality Program

**Status:** Draft
**Revision:** 0
**Date:** 2026-07-18
**Responsible:** Bill James
**Sunset:** 2027-07-18
**Standards:** ISO 9001, Gordy's QM-00 through QM-19, ASTM F2291

---

## 1. Intent

The quality program ensures that JPods products and services meet or exceed customer requirements, and that no injury to a JPods customer ever results from JPods negligence, ignorance, or lack of quality. This spec maps Gordon Israelson's 2014 Quality Manual (QM-00 through QM-19) to the digital system — Alice and WebClerk3 — so that quality processes are executed, tracked, and audited through the same platform that runs commerce. Paper forms become action records. Filing cabinets become Document records with retention dates. The quality program is not a separate bureaucracy — it is how the business operates.

**Quality Policy:** "JPods, Inc. will provide world class quality products and services that meet or exceed our customers' requirements. There shall never be an injury of a JPods customer due to JPods negligence, ignorance or lack of quality."

## 2. Requirements

### 2.1 Document Hierarchy

The quality system maintains a five-level document hierarchy. Each level is implemented in Alice/WC3.

| Level | Document Type | WC3 Implementation |
|-------|--------------|-------------------|
| 1 | Quality Manual (QM-00) | Document record, type=QUALITY_MANUAL |
| 2 | Program Procedures (QM-01 through QM-19) | Document records, type=PROCEDURE |
| 3 | Department Procedures | Document records, type=DEPT_PROCEDURE |
| 4 | Work Instructions | Document records, type=WORK_INSTRUCTION |
| 5 | Program/Project Plans + Quality Records | Document records + Action records |

### 2.2 Core Process Requirements

| ID | Requirement | Justification | RP | Date | Flag |
|----|-------------|---------------|----|------|------|
| R-12-001 | Nonconformance reports (NCR) shall be tracked as Action records (type=NCR) with lifecycle states: Open → Investigating → Corrective Action → Verified → Closed | QM-13; NCR form digitized; every nonconformance must be dispositioned — use-as-is, rework, scrap, or return to vendor | BJ | 2026-07-18 | ORANGE |
| R-12-002 | Corrective Action reports (CAR) shall be tracked as Action records (type=CAR) with root cause → corrective action → verification → effectiveness review | QM-14; CAR form digitized; every CAR traces back to the NCR that triggered it | BJ | 2026-07-18 | ORANGE |
| R-12-003 | Deviation/Waiver requests shall be tracked as Action records (type=DW) with approval chain | QM-13.1; D/W form digitized; deviations require engineering approval before use; waivers require customer approval | BJ | 2026-07-18 | ORANGE |
| R-12-004 | Document control shall use Git for version control and Document records in Alice for metadata, approval, and distribution | QM-05; DCR form replaced by pull request + Document record; every document has owner, revision, approval date, sunset date | BJ | 2026-07-18 | |
| R-12-005 | Purchasing shall use the PO model in WC3 with vendor qualification status checked before order release | QM-06; PO form digitized; no purchase from unqualified vendor; vendor qualification process TBD | BJ | 2026-07-18 | YELLOW |
| R-12-006 | Receiving inspection and in-process inspection shall be recorded as QA records on serialized items | QM-10, QM-12; inspection checklists define accept/reject criteria per item type; checklists not yet written | BJ | 2026-07-18 | ORANGE |
| R-12-007 | Traceability: every serialized item shall have a UUID, with cross-references to source material lots, inspection records, and assembly records | QM-08; serialized item model exists in WC3 but numbering not yet populated for production items | BJ | 2026-07-18 | ORANGE |
| R-12-008 | Configuration management: Git branches map to configuration baselines; Change Requests are pull requests; Configuration Management Officer approves merges | QM-04.3; who fills the CMO role is not yet decided | BJ | 2026-07-18 | YELLOW |
| R-12-009 | Training records shall be maintained as Contact qualifications in WC3; required training per role verified before work authorization | QM-18; quiz engine (28 questions currently) validates knowledge; additional quiz content needed for production roles | BJ | 2026-07-18 | ORANGE |
| R-12-010 | Quality records shall be stored as Document records with retention dates and sunset enforcement | QM-16; Alice enforces retention; warns before sunset; deletion requires approval | BJ | 2026-07-18 | |
| R-12-011 | Internal audits shall be scheduled as recurring Action records with audit checklists attached | QM-17; audit schedule not yet created; frequency and scope per process area TBD | BJ | 2026-07-18 | YELLOW |
| R-12-012 | Calibration of measuring and test equipment shall be tracked per QM-11 with calibration records linked to equipment serial numbers | QM-11; calibration tracking system not yet built; calibration intervals not defined for most sensors | BJ | 2026-07-18 | YELLOW |
| R-12-013 | Management review shall occur at defined intervals with documented inputs and outputs per QM-03 | QM-03; review frequency, agenda template, and participant list TBD | BJ | 2026-07-18 | |
| R-12-014 | Customer complaints and Small-Stings shall feed the NCR/CAR process | Customer-reported problems are nonconformances; Small-Stings (customer-assessed fines) are the financial signal that triggers investigation | BJ | 2026-07-18 | |
| R-12-015 | Vendor qualification: vendors shall be evaluated, approved, and maintained on an approved vendor list before procurement | QM-06; qualification criteria, evaluation form, and re-qualification interval not yet defined | BJ | 2026-07-18 | YELLOW |

**Flag key:**
- (blank) = requirement is defined, understood, and actionable
- YELLOW = do not yet understand the requirement well enough to specify it
- ORANGE = understand the problem but do not have a solution
- RED = stop everything until this is fixed (safety, compliance, or blocking)

### 2.3 QM-to-Alice/WC3 Implementation Map

| QM Process | QM Doc | Alice/WC3 Implementation | Status |
|------------|--------|--------------------------|--------|
| Quality Manual | QM-00 | Document record (type=QUALITY_MANUAL) | Exists |
| Organization | QM-01 | Contact records + org chart | Exists |
| Quality System | QM-02 | This spec (SPEC-12) | This document |
| Management Review | QM-03 | Scheduled Action (type=MGMT_REVIEW) | Needs creation |
| Design Control | QM-04 | Git + PR workflow + Document records | Exists |
| Configuration Mgmt | QM-04.3 | Git branches + Change Request = PR | Exists; CMO role YELLOW |
| Document Control | QM-05 | Git + Document records with retention | Exists |
| Purchasing | QM-06 | PO model in WC3 | Exists; vendor qual YELLOW |
| Customer Property | QM-07 | CarryOn-linked records | Exists (MyCarryOn) |
| Traceability | QM-08 | Serialized items with UUID | ORANGE — numbering not populated |
| Process Control | QM-09 | Work Instructions as Documents | Needs content |
| Receiving Inspection | QM-10 | QA record on serialized item at receiving | ORANGE — checklists not written |
| Calibration | QM-11 | Equipment serial + calibration records | YELLOW — system not built |
| Inspection Status | QM-12 | Status fields on serialized items | ORANGE — checklists not written |
| Nonconformance | QM-13 | Action record (type=NCR) | ORANGE — type not created |
| Deviation/Waiver | QM-13.1 | Action record (type=DW) | ORANGE — type not created |
| Corrective Action | QM-14 | Action record (type=CAR) | ORANGE — type not created |
| Handling/Storage | QM-15 | Warehouse locations in WC3 | Exists |
| Quality Records | QM-16 | Document records with retention/sunset | Exists |
| Internal Audits | QM-17 | Scheduled Actions with checklists | YELLOW — schedule not created |
| Training | QM-18 | Contact qualifications + quiz engine | Exists; content ORANGE |
| Servicing | QM-19 | Action records (type=SERVICE) + maintenance logs | Needs creation |

### 2.4 Retention Periods

| Record Type | Retention | Per QM- |
|-------------|-----------|---------|
| Management review | 5 years | QM-03 |
| Contract review | 3 years after completion | QM-02 |
| Design review | 2 years after project close-out | QM-04 |
| Design verification | 5 years after close-out | QM-04 |
| Nonconformance (NCR) | 5 years | QM-13 |
| Corrective Action (CAR) | 5 years | QM-14 |
| Deviation/Waiver | 5 years | QM-13.1 |
| Training records | 3 years | QM-18 |
| Internal audit reports | 3 years | QM-17 |
| Calibration records | 2-3 years (per equipment type) | QM-11 |
| Receiving inspection | 5 years | QM-10 |
| Serialized item history | Life of item + 5 years | QM-08 |

## 3. Measures of Performance

| ID | Measure | Target | Method | Frequency |
|----|---------|--------|--------|-----------|
| M-12-001 | NCR closure time | <= 30 days from open to closed | Alice Action record timestamps | Monthly review |
| M-12-002 | CAR effectiveness | >= 90% of CARs prevent recurrence (no repeat NCR within 12 months) | Alice query: CAR → related NCR type → recurrence check | Quarterly |
| M-12-003 | Internal audit completion | 100% of scheduled audits completed on time | Alice Action record schedule vs. actual | Quarterly |
| M-12-004 | Training currency | 100% of personnel current on required training for their role | Alice Contact qualification expiry check | Monthly |
| M-12-005 | Calibration currency | 100% of measuring equipment within calibration interval | Calibration tracking system | Monthly |
| M-12-006 | Document sunset compliance | 0 expired documents in active use | Alice Document sunset date check | Monthly |
| M-12-007 | Vendor qualification currency | 100% of active vendors on approved list and within re-qualification period | Alice vendor qualification records | Quarterly |
| M-12-008 | Customer complaint resolution | <= 14 days from complaint to disposition | Small-Stings → NCR → resolution timestamps | Monthly |
| M-12-009 | Quality policy adherence | Zero injuries due to JPods negligence, ignorance, or lack of quality | Incident reports | Continuous |

## 4. Interfaces

| Interface | Spec | Boundary | Notes |
|-----------|------|----------|-------|
| All hardware specs | SPEC-01 through SPEC-11 | Quality records, inspection checklists, calibration requirements flow from hardware specs to quality program | Every spec has a Section 9 (Quality Records) that references QM processes |
| Alice / WebClerk3 | Software | Action records, Document records, Contact qualifications, PO model, serialized items | Alice is the execution platform for the quality program |
| Small-Stings | SPEC-07 (Operations) | Customer-assessed fines trigger NCR/CAR process | Alice accounts for Small-Stings payments and links to NCRs |
| Vendor management | External | Vendor qualification, PO release, receiving inspection | Quality program gates procurement |
| Regulatory (ASTM F24) | External | Compliance evidence, audit trail | Quality records provide evidence for regulatory compliance |

## 5. Risk Register

| ID | Risk | Severity | Mitigation | Status | RP | Date |
|----|------|----------|------------|--------|----|------|
| K-12-001 | NCR/CAR/DW action types not yet created in WC3 | High | Create action types with lifecycle states; priority item for Alice development | ORANGE — needs implementation | BJ | 2026-07-18 |
| K-12-002 | Serialized item numbering not populated for production items | High | Define numbering scheme; seed WC3 with item types; link to BOM from hardware specs | ORANGE — needs implementation | BJ | 2026-07-18 |
| K-12-003 | QA inspection checklists not written for any item type | High | Write checklists as Work Instruction documents; derive from hardware spec requirements and measures | ORANGE — needs content | BJ | 2026-07-18 |
| K-12-004 | Training quiz content limited to 28 questions — insufficient for production roles | Medium | Develop role-specific quiz banks; safety-critical roles require higher pass threshold | ORANGE — needs content | BJ | 2026-07-18 |
| K-12-005 | Internal audit schedule not established | Medium | Define frequency per process area; ISO 9001 requires all processes audited within audit cycle | YELLOW — needs schedule | BJ | 2026-07-18 |
| K-12-006 | Calibration tracking system not built | Medium | Add calibration fields to equipment serialized items; Alice generates calibration-due alerts | YELLOW — needs design | BJ | 2026-07-18 |
| K-12-007 | Vendor qualification process undefined | Medium | Define evaluation criteria, approval authority, re-qualification interval; critical for purchasing gate | YELLOW — needs definition | BJ | 2026-07-18 |
| K-12-008 | Configuration Management Officer role unfilled | Low | Assign CMO responsibility; may be shared role initially; must have authority to approve/reject configuration changes | YELLOW — needs assignment | BJ | 2026-07-18 |
| K-12-009 | Quality program exists only on paper (QM manual) — digital implementation incomplete | High | This spec is the bridge; implement ORANGE items to make quality program executable in Alice | Open | BJ | 2026-07-18 |

## 6. Bill of Materials

The quality program does not have a physical BOM. Its infrastructure is:

| Item | Description | Platform | Status |
|------|-------------|----------|--------|
| Alice / WebClerk3 | Quality execution platform | Mac + cloud | Operational |
| Action record types (NCR, CAR, DW, MGMT_REVIEW, AUDIT, SERVICE) | Quality action tracking | WC3 | ORANGE — types not created |
| Document records with retention | Quality document management | WC3 | Operational |
| Contact qualifications | Training and authorization tracking | WC3 | Operational |
| Quiz engine | Training validation | WC3 | Operational (28 questions) |
| Serialized item model | Traceability | WC3 | ORANGE — not populated |
| PO model | Purchasing control | WC3 | Operational |
| Git repository | Configuration management and document control | GitHub | Operational |
| Vector store (Alice) | Quality knowledge base | ChromaDB | Operational (4521 chunks) |

## 7. Maintenance

- **Quality Manual review:** Annual review by management; update per QM-03.
- **Procedure review:** Each QM procedure reviewed annually; sunset date enforced by Alice.
- **Audit schedule:** Maintained by quality manager; updated quarterly; all process areas covered within audit cycle.
- **Training content:** Quiz banks reviewed semi-annually; add questions as new processes, equipment, or requirements are introduced.
- **Calibration schedule:** Maintained per equipment type; Alice generates due-date alerts.
- **Vendor list:** Reviewed quarterly; re-qualification per defined interval.
- **Retention enforcement:** Alice checks Document sunset dates monthly; warns 30 days before expiry; deletion requires approval.

## 8. Serialization

The quality program defines the serialization framework that all other specs use:

- **Serialized items:** Every safety-critical component receives a unique UUID at point of manufacture or receipt.
- **QR code:** Each serialized item has a QR code linking to its full history (inspection, calibration, maintenance, NCRs, installation location).
- **Geolocation:** Items installed in the field are linked to their physical location (guideway segment, station ID, vehicle serial).
- **Cross-reference:** Serialized items link to source material lots (traceability per QM-08), assembly records, and test reports.
- **Alice manages the registry:** All serialized item records are in WC3; Alice provides search, audit trail, and lifecycle management.

## 9. Quality Records

| Record | Retention | Custodian | Per QM- |
|--------|-----------|-----------|---------|
| Quality Manual | Permanent | Quality Manager | QM-00 |
| Management review minutes | 5 years | Quality Manager | QM-03 |
| NCR records | 5 years | Quality Manager | QM-13 |
| CAR records | 5 years | Quality Manager | QM-14 |
| Deviation/Waiver records | 5 years | Quality Manager | QM-13.1 |
| Internal audit reports | 3 years | Quality Manager | QM-17 |
| Training records | 3 years | HR / Quality Manager | QM-18 |
| Calibration records | 2-3 years per equipment type | Engineering | QM-11 |
| Vendor qualification records | Life of vendor relationship + 3 years | Purchasing | QM-06 |
| Document change records (PRs) | 3 years | Configuration Manager | QM-05 |
| Receiving inspection records | 5 years | Quality / Receiving | QM-10 |
| Customer complaint records (Small-Stings) | 5 years | Alice | QM-14 |

## 10. Change History

| Rev | Date | Change | By |
|-----|------|--------|----|
| 0 | 2026-07-18 | Initial release — Draft. Maps Gordy's QM-00 through QM-19 to Alice/WebClerk3 digital implementation. | Bill James |
