---
stepsCompleted: [step-01-document-discovery, step-02-prd-analysis, step-03-epic-coverage-validation, step-04-ux-alignment, step-05-epic-quality-review, step-06-final-assessment]
filesIncluded:
  - _bmad-output/specs/spec-dev-env-config-repo/SPEC.md
  - _bmad-output/specs/spec-dev-env-config-repo/stack.md
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/architecture/architecture-config-v2-2026-08-05/ARCHITECTURE-SPINE.md
---

# Implementation Readiness Assessment Report

**Date:** 2026-08-05
**Project:** config-v2

---

## Step 1: Document Inventory

| Document Type | Status | File(s) |
|---|---|---|
| PRD | ❌ Not found | — SPEC.md used as requirements baseline |
| Architecture | ✅ Found (sharded) | `architecture/architecture-config-v2-2026-08-05/ARCHITECTURE-SPINE.md` |
| Epics & Stories | ✅ Found (whole) | `planning-artifacts/epics.md` |
| UX Design | ✅ N/A | CLI/shell project — no UI; confirmed in epics.md |

**No duplicates found.**

---

## PRD Analysis

> No traditional PRD exists. `SPEC.md` + `stack.md` serve as the requirements baseline. The epics document has already extracted and numbered all requirements from these sources.

### Functional Requirements

| # | Requirement |
|---|---|
| FR1 | System provides a curl one-liner that fetches and executes `setup.sh` to bootstrap a fresh Linux dev environment in a single command. |
| FR2 | `setup.sh` detects Linux distro exactly once via `/etc/os-release` and selects the correct manifest + package manager. |
| FR3 | `setup.sh` installs all packages from the selected distro manifest using the distro's package manager. |
| FR4 | `setup.sh` invokes `chezmoi init --apply $DOTFILES_REPO` after package installation. |
| FR5 | `config.sh` defines exhaustive canonical keys: `DOTFILES_REPO`, `GIT_USER_NAME`, `GIT_USER_EMAIL`, `GPG_FINGERPRINT`, `SSH_KEY_FILE`. |
| FR6 | `config.sh` is the sole source of all configurable runtime values; no script may prompt interactively or hardcode values. |
| FR7 | Before writing to any stateful user asset (SSH/GPG keys), `setup.sh` tests for presence; if present, skips with log message. |
| FR8 | Re-running `setup.sh` on an already-configured machine updates cleanly, exits without errors, leaves SSH/GPG keys untouched. |
| FR9 | `chezmoi apply` syncs dotfiles idempotently; `config-v2` enables this by ensuring chezmoi is installed and seeded. |
| FR10 | `setup.ps1` bootstraps a Windows companion environment via Scoop and winget without manual steps beyond script invocation. |
| FR11 | Package manifests list one package name per line, plaintext; no version pins unless required. |
| FR12 | Repo source tree matches defined structure: `setup.sh`, `setup.ps1`, `config.sh`, `packages/arch.txt`, `packages/ubuntu.txt`. |

**Total FRs: 12**

### Non-Functional Requirements

| # | Requirement |
|---|---|
| NFR1 | **Security/Public repo** — No secrets, credentials, or private keys committed; only safe references permitted. |
| NFR2 | **Platform coverage** — Bootstrap must support Arch Linux and Ubuntu (WSL and VM) as first-class targets. |
| NFR3 | **Non-interactive** — Once `config.sh` is in place, entire bootstrap is silent/non-interactive. |
| NFR4 | **Non-destructive** — Stateful user assets (SSH/GPG keys) never overwritten on any re-run. |
| NFR5 | **Two-repo boundary** — `config-v2` and dotfiles repo are independently deployable; no chezmoi-managed file in `config-v2`. |
| NFR6 | **Deterministic managed config** — chezmoi-managed files always overwritten on `chezmoi apply`; no soft-merge. |
| NFR7 | **Delegation principle** — `setup.sh` and `setup.ps1` are orchestrators only; no package install or dotfile state logic. |
| NFR8 | **Fixed execution order** — Immutable: (1) source config.sh, (2) install packages, (3) chezmoi init --apply. |

**Total NFRs: 8**

### Additional Requirements (from Architecture ADs)

- **AD-1** Two-repo boundary enforcement
- **AD-2** Orchestrator delegates, never owns
- **AD-3** `config.sh` as sole parameter source
- **AD-4** Detect-before-mutate for stateful assets
- **AD-5** Distro dispatch is isolated
- **AD-6** No secrets in repository
- **AD-7** Stateful-asset vs. chezmoi-managed boundary
- **AD-8** `config.sh.template` as exhaustive canonical key schema
- **AD-9** Bootstrap execution order

---

## Epic Coverage Validation

### FR Coverage Matrix

| FR | Requirement Summary | Epic Coverage | Story | Status |
|---|---|---|---|---|
| FR1 | curl one-liner entry point | Epic 1 | Story 1.4 + 1.5 | ✅ Covered |
| FR2 | Distro detection once | Epic 1 | Story 1.4 | ✅ Covered |
| FR3 | Install packages from manifest | Epic 1 | Story 1.4 | ✅ Covered |
| FR4 | chezmoi init --apply after packages | Epic 1 | Story 1.4 | ✅ Covered |
| FR5 | config.sh with 5 canonical keys | Epic 1 | Story 1.1 | ✅ Covered |
| FR6 | config.sh sole param source | Epic 1 | Story 1.1 + 1.4 | ✅ Covered |
| FR7 | Detect-before-mutate SSH/GPG | Epic 1 | Story 1.4 | ✅ Covered |
| FR8 | Idempotent re-run | Epic 1 | Story 1.4 | ✅ Covered |
| FR9 | chezmoi apply sync enabled | Epic 1 | Story 1.4 | ✅ Covered |
| FR10 | setup.ps1 Windows bootstrap | Epic 2 | Story 2.1 | ✅ Covered |
| FR11 | Package manifest format | Epic 1 | Story 1.2 + 1.3 | ✅ Covered |
| FR12 | Repo source tree structure | Epic 1+2 | Story 1.4 + 2.1 | ✅ Covered |

**Coverage: 12/12 FRs = 100%**

### Missing Requirements

No FRs are formally uncovered in the coverage map. However, **critical gaps in story ACs** mean several FRs will likely fail at implementation — see Epic Quality Review below.

---

## UX Alignment Assessment

### UX Document Status

**Not applicable.** This is a CLI/shell scripting project with no user interface. The epics document explicitly states "N/A — This is a CLI/shell scripting project with no user interface." No UX alignment issues exist.

---

## Epic Quality Review

### Epic 1: Linux Bootstrap — Quality Assessment

**User Value:** ✅ Clearly user-centric — "developer can bootstrap or re-bootstrap a fully configured Linux dev environment in a single command."
**Independence:** ✅ Stands alone with no dependencies on Epic 2.

#### Story 1.1: Create config.sh Parameter File
- **User Value:** ✅ Acceptable prerequisite story
- **AC Format (Given/When/Then):** ✅ Correct
- **Testable:** ✅
- **🔴 CRITICAL CONFLICT — config.sh tracked vs gitignored:** Story 1.1 AC states `config.sh` must be **tracked in git** with real values. Architecture Spine (AD-3, AD-6, Structural Seed) states `config.sh` is **always gitignored** and `config.sh.template` is the tracked scaffold. These are irreconcilable without an explicit decision.
- **🔴 MISSING STORY — config.sh.template:** Architecture AD-8 and the Structural Seed both show `config.sh.template` as a required tracked file. No story creates it. If the architecture decision stands, Story 1.1 must be split into: (a) create `config.sh.template` (tracked), (b) document how users generate `config.sh` from it.

#### Story 1.2: Create Arch Linux Package Manifest
- **User Value:** ✅ Meaningful prerequisite
- **AC Format:** ✅ Correct
- **🟠 MAJOR — Missing `.NET` / git in Arch manifest AC:** The AC explicitly lists: `zsh, chezmoi, fnm, Docker + Docker Compose, Neovim, tmux, zoxide, starship, fzf`. The stack includes `C#/.NET` as the backend framework — `dotnet-sdk` is absent from the AC's required package list. `git` is also not listed, yet chezmoi requires it to clone the dotfiles repo.
- **🟠 MAJOR — fnm not in standard Arch repos:** `fnm` is not in the official Arch repositories; it is AUR-only. The story AC does not account for AUR installation, which requires `yay`/`paru` or a manual build step — this cannot be satisfied by `pacman` alone.

#### Story 1.3: Create Ubuntu Package Manifest
- **User Value:** ✅ Meaningful prerequisite
- **AC Format:** ✅ Correct
- **🔴 CRITICAL — Non-standard apt packages require repo setup before install:** The stack includes Docker CE (needs Docker's official apt repo + GPG key), .NET SDK (needs Microsoft's apt feed + GPG key), and Neovim (apt version on Ubuntu LTS is often severely outdated — a PPA or AppImage is required). Simply listing these in `ubuntu.txt` and running `apt install` will fail. Story 1.3 has no AC covering the addition of these apt sources. Story 1.4 also has no AC for this pre-step. This is a gap that will cause FR2/FR3 to fail on Ubuntu for these tools.
- **🟠 MAJOR — fnm not in standard Ubuntu apt repos:** Same problem as Arch — `fnm` requires a separate installation step (curl-based installer or cargo). No story covers this.
- **🟠 MAJOR — Missing `.NET` and git in Ubuntu manifest AC:** Same gap as Story 1.2 — `dotnet-sdk` and `git` are absent from the explicitly required package list in the AC.

#### Story 1.4: Implement setup.sh Bootstrap Orchestrator
- **User Value:** ✅ Core value story
- **AC Format:** ✅ Correct
- **Independence:** ✅ Properly depends on Stories 1.1, 1.2, 1.3 (backward dependencies only)
- **Error Conditions:** Partial — only one error AC (missing config.sh). No AC for distro not recognized, package install failure, or network failure.
- **🟠 MAJOR — Ubuntu non-standard package repos not addressed:** As noted in Story 1.3, apt installation of Docker CE, .NET SDK, and others requires apt source setup first. Story 1.4's AC for the install step ("apt is invoked with packages/ubuntu.txt") implicitly assumes all packages are available in default repos — which they are not for several stack tools.
- **🟡 MINOR — config.sh conflict inheritance:** Story 1.4 ACs reference `config.sh` as the param source, which is correct per FR6. However the tracked/gitignored conflict from Story 1.1 propagates here — if the architecture decision (gitignored) is the right one, then Story 1.4's AC needs to clarify setup.sh's behavior when `config.sh` does not yet exist (user copies from template first).

#### Story 1.5: Create README
- **User Value:** ✅
- **AC Format:** ✅
- **🟡 MINOR — curl one-liner URL not validated in AC:** The AC documents the one-liner exists in the README but has no AC asserting the URL in the README resolves to the actual `setup.sh` in the repo. A broken raw URL is a silent failure for the entire project.

### Epic 2: Windows Companion Bootstrap — Quality Assessment

**User Value:** ✅ Clearly user-centric.
**Independence:** ✅ Does not depend on Epic 1 being complete.

#### Story 2.1: Implement setup.ps1
- **User Value:** ✅
- **AC Format:** ✅
- **🔴 CRITICAL — Windows config reading mechanism undefined:** The AC states setup.ps1 "sources them from `config.sh` (or reads the equivalent key-value pairs)". PowerShell cannot `source` a bash file. The "or equivalent" is vague and unresolved. There is no story defining how Windows users supply their configuration values. This makes FR6 and AD-3 unimplementable on Windows without additional design.
- **🟡 MINOR — Idempotency AC is weak:** The AC only states it "exits without errors" on second run. No assertion that the same tools/versions are in place or that no partial installs occurred.
- **🟡 MINOR — Tool list not explicit in ACs:** Unlike Stories 1.2/1.3, Story 2.1 has no AC listing which Windows tools are installed. If the stack changes, this story has no explicit acceptance gate.

### Dependency Analysis

**Within Epic 1:** Story ordering is logical — 1.1 (config) → 1.2/1.3 (manifests) → 1.4 (orchestrator) → 1.5 (README). No forward references detected.

**Between Epics:** Epic 2 is independent of Epic 1. ✅

**🟡 MINOR — Document ordering issue:** The epics file presents Epic 2's story (2.1) before Epic 1's stories (1.1–1.5). This is a presentation inconsistency that may cause confusion for the dev agent.

### Best Practices Checklist

| Epic / Story | User Value | Independent | No Forward Deps | Clear ACs | FR Traceability |
|---|---|---|---|---|---|
| Epic 1 | ✅ | ✅ | ✅ | ⚠️ gaps | ✅ |
| Epic 2 | ✅ | ✅ | ✅ | ⚠️ gaps | ✅ |
| Story 1.1 | ✅ | ✅ | ✅ | 🔴 conflict | ✅ |
| Story 1.2 | ✅ | ✅ | ✅ | 🟠 missing pkgs | ✅ |
| Story 1.3 | ✅ | ✅ | ✅ | 🔴 repo setup gap | ✅ |
| Story 1.4 | ✅ | ✅ | ✅ | 🟠 repo gap inherited | ✅ |
| Story 1.5 | ✅ | ✅ | ✅ | 🟡 URL validation | ✅ |
| Story 2.1 | ✅ | ✅ | ✅ | 🔴 config mechanism | ✅ |

---

## Summary and Recommendations

### Overall Readiness Status

## 🟠 NEEDS WORK

The epics cover all 12 FRs and the architecture is sound. However, **3 critical issues must be resolved before implementation begins** — proceeding now would cause stories to fail mid-implementation.

### Critical Issues Requiring Immediate Action

#### 🔴 CRITICAL-1: config.sh tracked vs gitignored — Architecture/Story Conflict

**Conflict:** Architecture Spine (AD-3, AD-6, source tree) says `config.sh` is **gitignored** and `config.sh.template` is the tracked scaffold. SPEC FR5 and Story 1.1 say `config.sh` is **tracked in git** with real values.

**Impact:** Story 1.1 implements the wrong design if the architecture is the authoritative source. A developer could inadvertently commit sensitive values. `config.sh.template` has no story to create it.

**Required Action:** Resolve the design decision explicitly:
- **Option A (Architecture wins):** Update FR5 and Story 1.1 to use `config.sh.template` (tracked scaffold, gitignored `config.sh`). Add a new story to create `config.sh.template`.
- **Option B (SPEC wins):** Update Architecture AD-3, AD-6, and the source tree to reflect that `config.sh` is tracked. Confirm all stored values are truly non-sensitive and document the rationale.

#### 🔴 CRITICAL-2: Ubuntu Non-Standard Package Repositories Not Covered

**Gap:** Docker CE, .NET SDK, and latest Neovim cannot be installed on Ubuntu via plain `apt install` from default repos. They require: adding GPG keys, adding apt sources, and then installing. `fnm` is not in any Ubuntu apt repo at all. No story or AC covers these pre-steps.

**Impact:** FR2 and FR3 will fail on Ubuntu for these tools. The Ubuntu bootstrap is broken as specified.

**Required Action:** Either:
- Add ACs to Story 1.3 and/or Story 1.4 requiring the apt repo setup steps for Docker CE, .NET SDK, Neovim, and a separate install path for fnm; OR
- Add a new Story 1.3b: "Configure Ubuntu non-standard apt sources and install non-apt tools" that runs before the main package install step.

The same analysis applies to Arch (fnm is AUR-only). Story 1.2 should acknowledge an AUR helper requirement or an alternative fnm install path.

#### 🔴 CRITICAL-3: Windows Config Reading Mechanism Undefined

**Gap:** Story 2.1 says setup.ps1 "sources config.sh (or reads the equivalent key-value pairs)." PowerShell cannot source bash files. No mechanism is defined for Windows users to supply their config values.

**Impact:** FR6 (config.sh as sole param source) and AD-3 are unimplementable on Windows without additional design. A developer implementing Story 2.1 will hit this immediately.

**Required Action:** Add an explicit mechanism. Options:
- Define that `setup.ps1` reads `config.sh` by parsing it line-by-line as `KEY=value` pairs in PowerShell (simple and consistent with the two-repo model).
- Or define a separate `config.ps1` or `config.env` for Windows.
Update Story 2.1 AC to test this mechanism explicitly.

### Major Issues (Should Fix Before Implementation)

#### 🟠 MAJOR-4: Missing .NET SDK and git in Package Manifest ACs (Stories 1.2 and 1.3)

The explicit package lists in Stories 1.2 and 1.3 ACs omit `dotnet-sdk` (in stack) and `git` (required by chezmoi). Add both to the explicit required-package list in both stories.

#### 🟠 MAJOR-5: No story for config.sh.template

If the architecture decision holds (Critical-1 Option A), `config.sh.template` is a required tracked file with no story to create it. Add a story or expand Story 1.1 to create this file with all canonical keys and platform-usage comments per AD-8.

### Minor Issues (Can Fix During Implementation)

#### 🟡 MINOR-6: fast-syntax-highlighting Decision Unresolved

Both the Architecture Spine and epics.md flag this: `fast-syntax-highlighting` (last commit 2025-07-16) has staleness risk; `zsh-users/zsh-syntax-highlighting` must be evaluated as an alternative before writing the dotfiles repo's zinit plugin list. This is a pre-implementation decision with no owner or action item. Assign this as a research spike or note it as a blocker for the dotfiles repo work.

#### 🟡 MINOR-7: curl One-Liner URL Not Validated in Story 1.5

Story 1.5 AC has no gate that verifies the URL in the README actually resolves to the `setup.sh` in the repo. A simple AC like "When I curl the URL, the response body matches the contents of `setup.sh`" would close this.

#### 🟡 MINOR-8: Epic/Story Presentation Order in epics.md

Epic 2 story (2.1) is presented before Epic 1 stories (1.1–1.5) in the document body. Reorder to match the Epic List at the top.

#### 🟡 MINOR-9: Error Handling Scope Not Acknowledged in Stories

Story 1.4 has one error AC (missing config.sh). The architecture defers broader error handling. The stories should at minimum note which error cases are in scope and which are explicitly deferred, so the developer implementing them knows what "done" means.

### Final Note

This assessment identified **9 issues** across **3 severity levels** (3 critical, 2 major, 4 minor). The critical issues must be resolved before implementation starts — they represent genuine ambiguities or gaps that would cause a developer to make contradictory choices or produce broken functionality. The major issues are high-probability implementation failures. Address the 3 critical and 2 major items (items 1–5) before proceeding.

---

*Assessment performed: 2026-08-05 | Assessor: Implementation Readiness Skill*
