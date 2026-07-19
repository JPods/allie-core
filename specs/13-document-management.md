# SPEC-13: Document Management

**Status:** Draft
**Revision:** 0
**Date:** 2026-07-18
**Responsible:** Bill James
**Sunset:** 2027-07-18
**Standards:** QM-05 (Document and Data Control), QM-16 (Quality Records), ISO 9001, ASTM F2974

---

## 1. Intent

All JPods documents — specifications, drawings, procedures, inspection records, training materials, contracts, and correspondence — shall be managed under version control served via web. This eliminates the failure modes of email attachments, local file copies, "which version is current?" confusion, and untraceable changes. Git provides immutable history, cryptographic integrity, branching for review, and web-accessible serving. Every document has a traceable author, timestamp, and diff. This is not optional — it is a contractual requirement for all parties.

## 2. Requirements

| ID | Requirement | Justification | RP | Date | Flag |
|----|-------------|---------------|----|------|------|
| R-13-001 | All project documents shall be stored in git repositories served via web (GitHub, GitLab, or self-hosted) | Single source of truth; immutable history; web-accessible to all authorized parties without special software | BJ | 2026-07-18 | |
| R-13-002 | Document format shall be Markdown (.md) for all text documents | Human-readable, diff-friendly, renders in any browser, no proprietary software required, enforces structure | BJ | 2026-07-18 | |
| R-13-003 | Binary documents (CAD, images, PDFs) shall be stored alongside .md files with cross-references | Complete project record in one place; binary files tracked by git LFS if large | BJ | 2026-07-18 | |
| R-13-004 | Every document change shall be a git commit with author, date, and description of change | QM-05 requires identified author and revision tracking; git provides this automatically and immutably | BJ | 2026-07-18 | |
| R-13-005 | No document shall be modified by email attachment, shared drive copy, or local edit without commit | Email attachments are the #1 cause of version confusion; shared drives have no change history; local edits are invisible | BJ | 2026-07-18 | |
| R-13-006 | Contracts shall include clause requiring all deliverable documents to be committed to the project git repository | Contractual enforcement; vendors/contractors cannot deliver documents outside the system | BJ | 2026-07-18 | |
| R-13-007 | Employees, contractors, and vendors shall receive git training as part of onboarding (QM-18) | Tool competency required before document creation; prevents bypass of the system | BJ | 2026-07-18 | |
| R-13-008 | Document review shall use pull requests (PRs) with required approvers before merge to main branch | QM-05 DCR process maps directly to PR workflow; approver signs off before document is released | BJ | 2026-07-18 | |
| R-13-009 | Main branch shall be protected — no direct pushes; all changes via PR | Prevents accidental or unauthorized changes to released documents | BJ | 2026-07-18 | |
| R-13-010 | Document retention periods per QM-16 shall be enforced by repository retention policy — no deletion of committed history | Git history is permanent by design; satisfies QM-16 retention (2-5 years depending on record type); regulatory audit trail | BJ | 2026-07-18 | |
| R-13-011 | Each project/contract shall have its own repository with access control per party | Need-to-know; vendors see only their project; employees see internal repos; customers see deliverable repos | BJ | 2026-07-18 | |
| R-13-012 | Repository shall be web-accessible without git client software for read-only access | Not everyone needs to commit; stakeholders, inspectors, and auditors need read access via browser (GitHub web UI, GitLab web UI, or Gitea) | BJ | 2026-07-18 | |
| R-13-013 | Automated indexing: all committed .md and .json files shall be indexed to vector store within 24 hours of commit | Allie/Andi/Alice can search across all documents semantically; git hooks or CI trigger indexing | BJ | 2026-07-18 | |
| R-13-014 | Document numbering shall follow the spec template (SPEC-XX) for specifications, and sequential integer for all other documents | Consistent with ItemNumberingSystem decision; no leading zeros; no category prefixes on non-spec documents | BJ | 2026-07-18 | |
| R-13-015 | Confidential documents (credentials, keys, personally identifiable information) shall never be committed to git | Use .gitignore, pre-commit hooks, and training to prevent; encrypted versions (.enc) are acceptable | BJ | 2026-07-18 | |
| R-13-016 | Every repository shall contain a README.md explaining purpose, structure, and how to contribute | Onboarding for any new participant; self-documenting project | BJ | 2026-07-18 | |
| R-13-017 | Inspection records, NCRs, CARs, and D/Ws shall be committed as .md files in a `quality/` directory within the project repository | Quality records are documents; they belong in the same version-controlled system; QM-16 retention enforced by git history | BJ | 2026-07-18 | |
| R-13-018 | Git commit signing (GPG or SSH) shall be required for all commits to production/contract repositories | Non-repudiation; proves who made the change; satisfies Athena's signing requirement for non-standing actions | BJ | 2026-07-18 | ORANGE |
| R-13-019 | CI/CD pipeline shall validate document format on PR (linting: valid markdown, required sections present, flag format correct) | Automated quality gate; prevents malformed documents from entering the system | BJ | 2026-07-18 | ORANGE |

**Flag key:**
- (blank) = requirement is defined, understood, and actionable
- YELLOW = do not yet understand the requirement well enough to specify it
- ORANGE = understand the problem but do not have a solution
- RED = stop everything until this is fixed (safety, compliance, or blocking)

## 3. Measures of Performance

| ID | Measure | Target | Method | Frequency |
|----|---------|--------|--------|-----------|
| M-13-001 | Document currency | 100% of released docs accessible via web within 1 hour of commit | Git push + web server check | Per commit |
| M-13-002 | Change traceability | 100% of changes have identified author and description | Git log audit | Monthly |
| M-13-003 | Review compliance | 100% of spec changes go through PR with approver sign-off | GitHub/GitLab PR audit | Monthly |
| M-13-004 | Vendor compliance | 100% of contract deliverables committed to project repo | Contract milestone review | Per deliverable |
| M-13-005 | Training completion | 100% of document creators pass git training quiz before first commit | Alice quiz records | Per onboarding |
| M-13-006 | Vector store currency | All committed docs indexed within 24 hours | Indexing log vs commit log | Weekly |
| M-13-007 | No secrets in repos | Zero credential/PII commits detected | Pre-commit hook + periodic scan | Per commit + monthly |

## 4. Interfaces

| Interface | Spec | Boundary | Notes |
|-----------|------|----------|-------|
| All specs (SPEC-01 through SPEC-12) | All | Specs are documents managed under this system | This is the meta-spec |
| Quality Program | SPEC-12 | NCR/CAR/D-W records committed as .md | QM-05 DCR → PR; QM-16 retention → git history |
| Alice | SPEC-12 | Document records in WC3 cross-reference git commits | Alice tracks document lifecycle; git stores content |
| Allie vector store | — | Git hooks trigger re-indexing on commit | Semantic search across all documents |
| Andi (IT15) | — | Andi monitors commit activity for compliance | Flags overdue reviews, unsigned commits |
| Contracts | — | Clause requiring git-managed deliverables | Legal enforcement of document management |

## 5. Risk Register

| ID | Risk | Severity | Mitigation | Status | RP | Date |
|----|------|----------|------------|--------|----|------|
| K-13-001 | Vendor refuses or cannot use git | Medium | Provide web-only upload path (Gitea has web file editor); include git training in vendor onboarding; make it contractual — no compliance, no contract | Active | BJ | 2026-07-18 |
| K-13-002 | Credentials accidentally committed | High | Pre-commit hook scanning for patterns (API keys, passwords); .gitignore for known credential paths; training | Active — need to implement hook | BJ | 2026-07-18 |
| K-13-003 | Large binary files bloat repository | Medium | Git LFS for files > 10MB; separate media repository if needed; .gitignore for build artifacts | Active | BJ | 2026-07-18 |
| K-13-004 | Team resistance — "too complicated" | Medium | Web UI for read-only; simple commit workflow for editors; Alice can accept docs via upload and commit on behalf | Active | BJ | 2026-07-18 |
| K-13-005 | Repository hosting goes down | Low | Mirror to second host; local clones are full copies (git is distributed by design) | Mitigated by architecture | BJ | 2026-07-18 |

## 6. Mapping: QM-05 (Document Control) → Git

| QM-05 Requirement | Git Implementation |
|---|---|
| Documents reviewed before release | Pull Request with required reviewers |
| Changes by originator only when authorized | Branch protection; only PR authors and maintainers can merge |
| Identified by unique numbers/titles/revision levels | File path + git commit hash = unique identification; revision = commit history |
| Readily available | Web-served repository; browser access |
| Master List maintained | Repository file listing IS the master list; always current |
| DCR process: Originator → Manager → Author → Manager → DCA → Master List | PR process: Author → Reviewer(s) → Approve → Merge → Main branch |

## 7. Mapping: QM-16 (Quality Records) → Git

| QM-16 Requirement | Git Implementation |
|---|---|
| Identification | File path + commit SHA |
| Collection | `git add` + `git commit` |
| Indexing | Repository directory structure + vector store |
| Accessing | Web browser (GitHub/GitLab/Gitea UI) |
| Filing | Directory structure within repository |
| Retention | Git history is immutable; commits cannot be deleted without force (prohibited by R-13-010) |
| Maintenance | Repository maintenance automated (GC, LFS) |
| Disposition/Storage | Archive branches for closed projects; retention period tracked in document metadata |

## 8. Contract Clause (Template)

> **Document Management.** All deliverable documents, specifications, drawings, inspection records, test reports, and correspondence related to this Agreement shall be committed to the Project Repository designated by JPods. Documents delivered by any other means (email attachment, shared drive, USB, paper) shall not be considered officially delivered until committed to the Repository. Contractor shall ensure all personnel contributing documents are trained in the Repository system prior to their first contribution. JPods shall provide Repository access and training materials. All committed documents become part of the permanent project record with immutable change history.

## 9. Quality Records

| Record | Retention | Custodian | Per QM- |
|--------|-----------|-----------|---------|
| Git commit history | Permanent (repository lifetime) | Repository admin | QM-16 |
| Pull request reviews | Permanent | Repository admin | QM-05 |
| Access control changes | 5 years | Repository admin | QM-16 |
| Training completion (git quiz) | 3 years | Alice | QM-18 |

## 10. Change History

| Rev | Date | Change | By |
|-----|------|--------|----|
| 0 | 2026-07-18 | Initial release | Bill James / Claude Code |
