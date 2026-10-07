---
type: sprint-change-proposal
date: 2026-10-07
project: config-v2
trigger: strategic pivot to in-repo dotfiles (2026-08-07)
scope: moderate
approach: direct adjustment
status: approved
approved_by: Jonas
---

# Sprint Change Proposal — Switch to In-Repo Dotfiles

## 1. Issue Summary

On 2026-08-07, following the "make bootstrap trustworthy" brainstorm, the project pivoted from a two-repo model (`config-v2` for bootstrap plus a separate chezmoi `dotfiles` repository) to a single repository with the chezmoi source tree under `config-v2/dotfiles/`. The goal is an end-to-end testable setup flow in which the dotfiles act as a reproducible test fixture.

The external `HaberkornJonas/dotfiles` repository is empty, so no content migration is required.

**Category:** strategic pivot.

The pivot was captured in a new architecture spine and rewritten epics, but was never committed or reconciled with the SPEC, the previous spine, sprint tracking, or the code.

**Evidence**

- Brainstorm memlog `brainstorm-dotfiles-setup-flow-2026-08-07` and spine `architecture-config-v2-dotfiles-integration-2026-08-07` (AD-1 to AD-6).
- `setup.sh` still runs `chezmoi init --apply "$DOTFILES_REPO"` against the remote repository.
- `README.md` describes "a strict two-repo model"; `tests/validate-readme.ps1` asserts the two-repo wording and `DOTFILES_REPO`.
- `setup.sh` reads `./packages/*.txt` relative to the caller's working directory, violating the new repo-root contract (AD-3).
- `sprint-status.yaml` listed delivered stories 1.2–1.5 as `review` while their story files say `done`.
- The rewritten epics reused story numbers 1.1–1.5 for different work, colliding with delivered story files.
- SPEC.md still carried a hard "Two-repo split" constraint.
- Two architecture spines were both marked `final` and contradicted each other; the new spine dropped still-valid rules (distro dispatch, key schema, execution order).

## 2. Impact Analysis

### Epic impact

- **Epic 1 (Linux Bootstrap, delivered):** its output (package manifests, distro dispatch, SSH/GPG guards, README) remains the base for the new work. Only the remote `DOTFILES_REPO` apply and the two-repo README wording are superseded. Closed as done.
- **New Linux integration epic:** renumbered to **Epic 2: Integrated Linux Bootstrap and Dotfiles Sync** (stories 2.1–2.5).
- **Windows epic:** renumbered to **Epic 3: Windows Companion Alignment** (stories 3.1–3.2). Sequenced after Epic 2 stories 2.1–2.2 because it depends on `dotfiles/` and the repo-root contract.
- No epic becomes obsolete; no new epic beyond the renumbering is needed.

### Artifact conflicts

| Artifact | Conflict | Resolution |
| --- | --- | --- |
| SPEC.md | Why paragraph, CAP-2, and "Two-repo split" constraint describe the old model | Updated (proposal 1) |
| 2026-08-07 spine | Missing distro dispatch, key schema, and execution-order rules | AD-7, AD-8, AD-9 added (proposal 2) |
| 2026-08-05 spine | Still `final`; AD-1 mandates two repos | Marked superseded (proposal 2) |
| epics.md | Number collision with delivered Epic 1; gaps found during this analysis | Renumbered, ACs added (proposal 3) |
| Windows story file | Old key `2-1-implement-setup-ps1-…` | Re-keyed to `3-1-…` (proposal 4) |
| sprint-status.yaml | Old epic structure; status mismatch | Rebuilt (proposal 5) |
| Implementation readiness report (2026-08-05) | Predates the pivot | Re-run as first handoff step |
| UX | None exist | N/A |

### Technical impact (deferred to Epic 2 stories, not changed here)

- `setup.sh`: apply from local `dotfiles/`, repo-root-relative paths, remove `DOTFILES_REPO` (Story 2.2).
- New `dotfiles/` tree (Story 2.1); stateful-asset classification (Story 2.3); smoke verification (Story 2.4).
- `README.md` and `tests/validate-readme.ps1` (Story 2.5).

### MVP impact

None. CAP-1 to CAP-4 still hold; only the delivery mechanism for dotfiles changes.

## 3. Recommended Approach

**Direct adjustment.** Effort: low–medium. Risk: low.

- **Rollback** rejected: delivered Epic 1 code is the base the new work extends.
- **MVP review** not needed: capabilities and success signal are unchanged apart from making verification explicit.
- **Scope classification:** Moderate — backlog reorganization and artifact alignment, no fundamental replan.

## 4. Detailed Change Proposals (all approved)

### 4.1 SPEC.md

- **Why:** "two-repo setup — `config-v2` for bootstrap orchestration and a `dotfiles` repo managed by `chezmoi`" → "single-repo setup — `config-v2` holds bootstrap orchestration, package manifests, and the `chezmoi` source tree under `dotfiles/`".
- **CAP-2 intent:** appended "using the in-repo `dotfiles/` tree of the local `config-v2` checkout as the single source".
- **Constraints:** "Two-repo split" replaced by "Single-repo, split ownership", including the requirement that tracked `dotfiles/` content is safe to use as a repeatable bootstrap test fixture.
- **Success signal:** added "Setup ends with a repo-local smoke verification that confirms the environment is usable, not just that the script exited 0."

### 4.2 Architecture

- **2026-08-07 spine:** added AD-7 (distro dispatch is isolated), AD-8 (bootstrap configuration is the canonical key schema; canonical Linux keys `GIT_USER_NAME`, `GIT_USER_EMAIL`, `GPG_FINGERPRINT`, `SSH_KEY_FILE`; `DOTFILES_REPO` removed), and AD-9 (execution order: config + repo root → distro → packages → stateful assets → local `chezmoi apply` → smoke verification; no orchestrating `run_once_` scripts). Capability map updated; "Migration choreography" deferral marked not needed.
- **2026-08-05 spine:** `status: superseded`, `superseded_by` link, and a banner. Its review files remain as history.

### 4.3 epics.md

- Added a closed **Epic 1: Linux Bootstrap (delivered)** summary.
- Renumbered: Integrated Linux epic → Epic 2 (stories 2.1–2.5); Windows epic → Epic 3 (stories 3.1–3.2). FR map updated (FR1–FR3 → Epic 2, FR4 → Epic 3).
- Story 2.1: new AC — `dotfiles/` contains no `run_once_` script that installs packages or orchestrates setup (AD-9).
- Story 2.2: new ACs — `./packages/*.txt` reads become repo-root-relative; `DOTFILES_REPO` removed from the configuration block (AD-8).
- Story 2.5: retitled "Refresh Linux-Facing Documentation and README Validation"; new AC requiring `tests/validate-readme.ps1` to assert the in-repo model and pass; planning-artifact refresh removed from scope (done by this proposal).

### 4.4 Story file

- `2-1-implement-setup-ps1-windows-bootstrap-orchestrator.md` → `3-1-align-setup-ps1-with-shared-repository-contract.md`, retitled Story 3.1, kept `ready-for-dev` with a sequencing note (after Stories 2.1–2.2) and an AD-8 guardrail row.

### 4.5 sprint-status.yaml

- `epic-1` and stories 1-2 to 1-5 → `done`.
- `epic-2` → `backlog` with five backlog story keys.
- `epic-3` → `in-progress`; `3-1-…` `ready-for-dev`; `3-2-…` `backlog`.

### 4.6 Commit and readiness

- Commit the planning reset, including the previously uncommitted 2026-08-07 artifacts, as a single commit.
- Re-run the implementation readiness check against SPEC, the 2026-08-07 spine, and epics.

## 5. Implementation Handoff

| Role | Responsibility |
| --- | --- |
| PM (John) | Apply proposals 4.1–4.5, write this document, commit (done in the correct-course session) |
| PM / Architect | Run `bmad-check-implementation-readiness` on the updated artifacts |
| Developer | `bmad-create-story` → `bmad-dev-story` → code review for Epic 2 stories in order 2.1 → 2.5, then Story 3.1 |

**Success criteria**

- One authoritative architecture spine.
- SPEC, epics, sprint-status, and story files are mutually consistent, with no story-key collisions.
- The readiness check passes before Epic 2 implementation starts.
