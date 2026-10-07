---
stepsCompleted:
  - step-01-document-discovery
  - step-02-prd-analysis
  - step-03-epic-coverage-validation
  - step-04-ux-alignment
  - step-05-epic-quality-review
  - step-06-final-assessment
filesIncluded:
  prd: _bmad-output/specs/spec-dev-env-config-repo/SPEC.md (+ companion stack.md)
  architecture: _bmad-output/planning-artifacts/architecture/architecture-config-v2-dotfiles-integration-2026-08-07/ARCHITECTURE-SPINE.md
  epics: _bmad-output/planning-artifacts/epics.md
  stories: _bmad-output/implementation-artifacts/3-1-align-setup-ps1-with-shared-repository-contract.md
  ux: none
---

# Implementation Readiness Assessment Report

**Date:** 2026-10-07
**Project:** config-v2

## Document Inventory

| Type | Document | Notes |
| --- | --- | --- |
| PRD (equivalent) | `specs/spec-dev-env-config-repo/SPEC.md` + `stack.md` | No `*prd*.md` exists; SPEC is the canonical requirements contract and the declared input of `epics.md` |
| Architecture | `architecture-config-v2-dotfiles-integration-2026-08-07/ARCHITECTURE-SPINE.md` | Active spine (amended 2026-10-07 with AD-7/8/9) |
| Architecture (excluded) | `architecture-config-v2-2026-08-05/ARCHITECTURE-SPINE.md` + reviews | Superseded 2026-10-07; historical only |
| Epics & Stories | `epics.md` | Whole document; Epic 1 closed, Epics 2–3 active |
| Story files | `implementation-artifacts/3-1-align-setup-ps1-with-shared-repository-contract.md` | Only active story file (ready-for-dev) |
| UX | — | None; CLI bootstrap project |
| Prior report | `implementation-readiness-report-2026-08-05.md` | Pre-pivot; superseded by this report |

**Discovery issues:** no whole/sharded duplicates. Two spines resolved by supersession. No PRD file (SPEC used). No `docs/index.md`.

## PRD Analysis

Source: `SPEC.md` (capabilities CAP-1..CAP-4, constraints, non-goals, success signal) + `stack.md` (binding tool catalog). The SPEC expresses functional needs as capabilities; they are extracted here as FRs aligned with the FR numbering used in `epics.md`.

### Functional Requirements

FR1 (CAP-1): User can bootstrap a fresh Linux (Arch or Ubuntu) dev environment from zero by manually installing Git, cloning `config-v2`, and running the local `setup.sh`. Success: on a fresh machine, executing `./setup.sh` from the checkout produces a fully configured, usable dev environment (correct shell, plugins, editor, runtime, and dotfiles in place); the run exits cleanly.

FR2 (CAP-2): User can apply and sync dotfiles across machines via `chezmoi`, using the in-repo `dotfiles/` tree of the local `config-v2` checkout as the single source. Success: `chezmoi apply` on any registered machine reaches the same dotfile state as the source; idempotent across repeated runs.

FR3 (CAP-3): User can re-run setup to update or sync an existing environment without destroying stateful assets. Success: re-running setup reflects the latest config state, exits without errors, and leaves existing SSH keys and secrets untouched.

FR4 (CAP-4): User can bootstrap a Windows companion environment via `setup.ps1` using Scoop and winget. Success: running `setup.ps1` on a fresh Windows machine installs the defined Windows tool set without manual steps beyond the initial invocation.

Total FRs: 4

### Non-Functional Requirements

NFR1 (Security / public repo): No secrets stored; only safe references (e.g. GPG fingerprint) permitted.
NFR2 (Portability): Linux-first targets WSL/VM on Arch and Ubuntu; per-distro manifests `packages/arch.txt`, `packages/ubuntu.txt` required; distro differences (Docker, .NET repo setup) handled.
NFR3 (Consistency): Same single Git identity configured on every machine.
NFR4 (Usability / automation): Fully silent and non-interactive once the local checkout is ready; Linux bootstrap configuration lives at the top of `setup.sh`.
NFR5 (Reliability): Non-destructive for stateful assets; existing SSH keys preserved on every re-run (detect and skip).
NFR6 (Maintainability / ownership): Package managers own installs; chezmoi owns dotfiles, templating, conflict/state; `setup.sh`/`setup.ps1` orchestrate only. Host-only concerns (e.g. Nerd Fonts) live on a post-install checklist outside the repo.
NFR7 (Structure): Single repo, split ownership; all chezmoi-managed config under `dotfiles/`; tracked `dotfiles/` content safe as a repeatable bootstrap test fixture.
NFR8 (Determinism): Managed config always overwritten on apply; no soft merges.
NFR9 (Hygiene): No global npm packages; no project-specific tools in global machine config.
NFR10 (Verifiability): Setup ends with repo-local smoke verification confirming the environment is usable, not just exit 0.

Total NFRs: 10

### Additional Requirements

- **Binding tool catalog (`stack.md`):** zsh; chezmoi; fnm; Docker + Compose; Neovim; tmux; zinit with zsh-autosuggestions, fast-syntax-highlighting, fzf-tab, zoxide; starship prompt; Angular and C#/.NET listed as dev runtime; Windows: `setup.ps1`, Scoop, winget.
- **Assumptions:** zsh is the target shell on all Linux machines; single developer / single Git identity.
- **Non-goals:** full Windows/WSL2 auto-bootstrap through Linux user creation; Ansible; YubiKey SSH as required path; secrets in repo; Mac support.
- **Open questions (non-blocking):** YubiKey SSH bridge in WSL/VM; CI coverage beyond Ubuntu; Mac support.

### PRD Completeness Assessment

The SPEC is concise and internally consistent after the 2026-10-07 correction. Capabilities have clear success criteria. Observations for later steps:

- CAP-1 success requires "correct shell, plugins, editor, runtime, and dotfiles in place" — this implies concrete `dotfiles/` content (zsh/zinit/starship/Neovim/tmux/git config) and making zsh the login shell; traceability to stories must be checked.
- NFR3 (single Git identity) and the GPG fingerprint imply managed git config content; check coverage.
- `stack.md` lists `fast-syntax-highlighting`, while the superseded 2026-08-05 spine listed `zsh-syntax-highlighting` — the SPEC/stack is authoritative, but the discrepancy should be noted for dotfiles authoring.
- `stack.md` lists Angular and C#/.NET as "dev runtime", which can read as conflicting with NFR9 (no project-specific tools in global config); interpretation (runtimes/SDKs only, no project CLIs) should be explicit.
- The Windows tool set for CAP-4 ("the defined Windows tool set") is not enumerated in SPEC or stack.

## Epic Coverage Validation

### Coverage Matrix

| FR | PRD Requirement (short) | Epic Coverage | Status |
| --- | --- | --- | --- |
| FR1 | Fresh Linux bootstrap from local checkout → fully configured, usable environment | Epic 1 (delivered: manifests, distro dispatch, package install); Epic 2 Stories 2.1, 2.2, 2.4, 2.5 | ⚠️ Covered at orchestration level; **partial** for "correct shell, plugins, editor, runtime, and dotfiles in place" |
| FR2 | chezmoi apply/sync from in-repo `dotfiles/` | Epic 2 Stories 2.1, 2.2, 2.3 | ✓ Covered (mechanism) |
| FR3 | Idempotent rerun preserving stateful assets | Epic 1 (SSH/GPG guards); Epic 2 Stories 2.3, 2.4 | ✓ Covered |
| FR4 | Windows companion bootstrap via Scoop + winget | Epic 3 Stories 3.1, 3.2 | ⚠️ Covered; Windows tool set undefined |

No FRs exist in epics that are absent from the PRD.

### Missing Requirements

#### High Priority — partial coverage inside FR1

**FR1 sub-requirement: managed dotfiles content.** CAP-1 success ("correct shell, plugins, editor, runtime, and dotfiles in place") requires actual chezmoi-managed content: zsh config with zinit + autosuggestions, fast-syntax-highlighting, fzf-tab, zoxide; starship config; Neovim and tmux config; git config carrying the single identity (NFR3) and GPG signing key reference. Story 2.1 only establishes the `dotfiles/` tree and its safety rules; no story has ACs for the content itself.
- Impact: Epic 2 could complete with an empty or skeletal `dotfiles/` and still pass every AC, while CAP-1's success signal fails.
- Recommendation: extend Story 2.1 ACs (or add a Story 2.1b) defining the minimum managed-content baseline per `stack.md`.

**FR1 sub-requirement: zsh as the login shell.** SPEC assumes zsh is the target shell on all Linux machines. Neither delivered Epic 1 code (`setup.sh`) nor any Epic 2 story sets zsh as the user's login shell.
- Impact: environment boots into bash; the managed zsh config never loads by default.
- Recommendation: add to Story 2.2 or 2.3 (login shell is a stateful-asset-style host change: detect-before-mutate), and assert in Story 2.4 verification.

**FR1 sub-requirement: Node runtime via fnm.** `setup.sh` installs fnm but no story ensures a Node version is installed/activated; fnm shell integration belongs in managed zsh config.
- Impact: "runtime in place" is unverified.
- Recommendation: fold into the managed-content baseline (fnm env in zsh config) and smoke verification.

#### Medium Priority

**FR4: Windows tool set not enumerated.** CAP-4 says "installs the defined Windows tool set", but neither SPEC, `stack.md`, nor Story 3.1 defines the list.
- Recommendation: define the Windows tool list (e.g. `packages/windows-*.txt`) as a pre-condition or AC of Story 3.1.

### Coverage Statistics

- Total PRD FRs: 4
- FRs with a traceable epic path: 4 (100%)
- FRs fully covered at acceptance-criteria level: 2 (FR2, FR3) — 50%
- FRs partially covered: 2 (FR1 managed content / login shell / runtime; FR4 tool set)

## UX Alignment Assessment

### UX Document Status

Not found.

### Alignment Issues

None — no graphical UI is implied. The product is a CLI bootstrap (`setup.sh`, `setup.ps1`) for a single developer. The user-facing surface is console output and the README.

### Warnings

- ℹ️ Low: the only "UX" surface is console messaging. AD-6 / Story 2.4 require verification failures to be actionable ("the user can tell which part of the integrated setup flow is broken"); no message convention exists beyond the `INFO:`/`ERROR:` prefixes already used in `setup.sh`. Recommend keeping that convention explicit in Story 2.4. Not blocking.

## Epic Quality Review

Scope: active Epics 2 and 3 (Epic 1 is closed/delivered and reviewed only where its code creates risk for Epic 2). Brownfield context: `setup.sh`, `packages/*.txt`, `README.md`, `tests/validate-readme.ps1` exist.

### Epic Structure

| Epic | User value | Independence | Verdict |
| --- | --- | --- | --- |
| Epic 2: Integrated Linux Bootstrap and Dotfiles Sync | ✓ Clear outcome: clone, run, reproducible environment | ✓ Uses only Epic 1 output | Pass |
| Epic 3: Windows Companion Alignment | ✓ Outcome for Windows user | ✓ Uses Epic 2 output (backward dependency only); Story 3.1 sequenced after 2.1–2.2 | Pass |

### Dependency Analysis

- Epic 2 chain 2.1 → 2.2 → 2.3 → 2.4 → 2.5: all backward references. No forward dependencies.
- Story 3.1 → Stories 2.1, 2.2: backward (cross-epic), explicitly recorded in the story file. OK.
- No circular dependencies. No database/entity concerns (N/A).
- Starter template: N/A (no starter specified).

### Findings

#### 🔴 Critical Violations

None.

#### 🟠 Major Issues

1. **No managed-content baseline (Story 2.1).** Story 2.1 delivers a directory and safety rules but no ACs for the actual configuration the SPEC promises (zsh + zinit plugins, starship, Neovim, tmux, git identity/GPG signing). As written, an empty `dotfiles/` passes. → Add ACs listing the minimum managed files derived from `stack.md`, plus "manual `chezmoi apply --source ./dotfiles` produces them" so the story has standalone value.
2. **zsh login shell not owned by any story.** SPEC assumes zsh everywhere; nothing sets it. → Add to Story 2.3 (detect-before-mutate host change) with a Story 2.4 check.
3. **Ongoing sync path undefined (FR2).** No AC states how an existing machine pulls changes (e.g. `git pull` in `config-v2` then `chezmoi apply`, with chezmoi's `sourceDir` persisted to the repo's `dotfiles/`). → Add an AC to Story 2.2 that chezmoi is configured so plain `chezmoi apply` uses the checkout's `dotfiles/`, and document the update flow in Story 2.5.
4. **Privilege model of `setup.sh` undefined (brownfield defect).** Delivered `setup.sh` calls `pacman`/`apt-get` without `sudo`, so it must run as root — but then SSH key generation and `chezmoi apply` target root's home (or an inconsistent `$HOME` under `sudo`). → Add an AC to Story 2.2: run as the target user; elevate only package-manager/system commands via `sudo`; refuse to run as root.
5. **fnm installer writes shell rc files (AD-5 conflict).** `curl … fnm.vercel.app/install | bash` appends to the user's shell rc, which will be chezmoi-managed. A path written by both violates AD-5. → Add to Story 2.3: install fnm with `--skip-shell`; fnm shell integration lives in managed zsh config.
6. **The pivot's core motivation — reproducible end-to-end testing — has no execution vehicle.** The brainstorm/spine aim was "dotfiles as a test fixture" with a fresh-user test persona, yet no story provides a repeatable way to run `setup.sh` from scratch (e.g. disposable Arch/Ubuntu containers). Story 2.4 adds post-apply checks but not a clean environment to run them in. → Add a Story 2.6 (or extend 2.4): repo-local script that runs `setup.sh` + verification in a fresh Arch and Ubuntu container. CI remains deferred per SPEC.
7. **Story 2.4 verification trigger is ambiguous.** "Runs automatically or via a documented repo-local command" conflicts with AD-9, which fixes verification as step (6) of `setup.sh`. → Make it automatic at the end of `setup.sh`, also runnable standalone.

#### 🟡 Minor Concerns

1. **Ubuntu package availability unverified.** `packages/ubuntu.txt` lists `chezmoi` and `starship`, which are not reliably available from default Ubuntu apt repositories (version-dependent). Story 2.4 verification would surface this; consider explicitly checking during Story 2.2 or 2.6.
2. **Story 2.3 classification artifact unspecified.** "Every path is assigned to exactly one category" — where is the classification recorded? → Name the artifact (e.g. a table in README or `dotfiles/` docs).
3. **Story 2.1 AC wording vague.** "Placement matches the architecture contract" — replace with concrete checks (path is `dotfiles/` at repo root; chezmoi can read it as a source directory).
4. **Windows tool set undefined (Story 3.1).** Define the Windows package list (e.g. `packages/windows-scoop.txt`, `packages/windows-winget.txt`) as an AC or pre-condition.
5. **Pre-existing chezmoi state on previously bootstrapped machines.** Old `setup.sh` ran `chezmoi init` against the remote; machines may have `~/.local/share/chezmoi` or a chezmoi config pointing there. Story 2.2 should handle or explicitly ignore it.
6. **`stack.md` discrepancies.** Angular / C#/.NET listed as "dev runtime" vs NFR9 (no project-specific tools globally); the SDK is installed (`dotnet-sdk`) but Angular CLI would be a global npm package — clarify that Angular is not installed globally.
7. **Documentation stories (2.5, 3.2)** are acceptable as maintenance stories but carry little standalone user value; fine for a single-developer repo.

### Best Practices Compliance

| Check | Epic 2 | Epic 3 |
| --- | --- | --- |
| Delivers user value | ✓ | ✓ |
| Functions independently (given prior epics) | ✓ | ✓ |
| Stories appropriately sized | ✓ (2.1 under-specified) | ✓ |
| No forward dependencies | ✓ | ✓ |
| Data/entity timing | N/A | N/A |
| Clear acceptance criteria | ⚠️ (2.1, 2.3, 2.4) | ⚠️ (3.1 tool set) |
| Traceability to FRs | ✓ | ✓ |

## Summary and Recommendations

### Overall Readiness Status

**NEEDS WORK** — structure, sequencing, and traceability are sound after the 2026-10-07 course correction (no critical violations, no forward dependencies, 100% FR traceability), but Epic 2 acceptance criteria under-specify what "fully configured, usable environment" means and leave several brownfield defects unowned. Implementing as-is risks a green Epic 2 that does not meet CAP-1's success signal.

### Issues Requiring Action Before Story 2.1 Is Created

1. **Define the managed-content baseline** (Story 2.1): zsh + zinit plugins, starship, Neovim, tmux, git identity/GPG signing, fnm shell integration — per `stack.md`.
2. **Own the zsh login shell** (Story 2.3, verified in 2.4).
3. **Define the ongoing sync path** (Story 2.2: persisted chezmoi `sourceDir` → repo `dotfiles/`; Story 2.5 documents `git pull` + `chezmoi apply`).
4. **Fix the privilege model** (Story 2.2: run as target user, `sudo` only for system commands, refuse root).
5. **Stop fnm from writing shell rc files** (Story 2.3: `--skip-shell`).
6. **Add an end-to-end fresh-environment test vehicle** (new Story 2.6 or extend 2.4: disposable Arch/Ubuntu container runs `setup.sh` + verification) — this is the reason for the pivot.
7. **Make verification automatic** at the end of `setup.sh` (Story 2.4, aligns with AD-9).

### Recommended Next Steps

1. Apply the seven AC changes above to `epics.md` (direct edit by PM — scope is AC refinement, not replanning; add Story 2.6 and its `sprint-status.yaml` key).
2. Optionally resolve minor items in the same pass: Story 2.3 classification artifact, Story 2.1 concrete wording, Windows package list for Story 3.1, `stack.md` Angular/.NET clarification, Ubuntu `chezmoi`/`starship` availability.
3. Then run `bmad-create-story` for Story 2.1 and proceed with `bmad-dev-story`.

### Final Note

This assessment identified **15 issues across 4 categories** (FR coverage, UX, epic/story quality, brownfield code risk): 0 critical, 7 major, 8 minor/low. Address the major issues before implementation starts; they are all acceptance-criteria refinements within the existing epic structure and do not require another course correction.

---

**Assessed by:** John (PM), BMad implementation-readiness workflow — 2026-10-07
**Supersedes:** `implementation-readiness-report-2026-08-05.md`
