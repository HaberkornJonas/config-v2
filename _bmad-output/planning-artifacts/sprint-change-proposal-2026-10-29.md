---
type: sprint-change-proposal
date: 2026-10-29
project: config-v2
trigger: scope cut to Arch Linux only (drop Windows companion and Ubuntu)
scope: moderate
approach: hybrid (direct adjustment + targeted code removal + MVP narrowing)
mode: batch
status: approved
approved_by: Jonas
---

# Sprint Change Proposal — Arch Linux Only

## 1. Issue Summary

On 2026-10-29, Jonas decided to drop Windows support and focus solely on setting up Arch Linux for now. This removes both the Windows companion bootstrap (`setup.ps1` with Scoop and winget) and Ubuntu as a Linux target.

**Category:** strategic pivot (scope reduction).

**Context:** Epic 2 is in progress (Stories 2.1–2.2 done, 2.3–2.5 in backlog). Story 3.1 (Windows `setup.ps1`) is in `review` with an uncommitted status change. The change was decided before Story 3.1 was accepted, so no further effort has been invested in Windows or Ubuntu beyond what exists.

**Decisions (confirmed with Jonas):**

| Decision | Choice |
| --- | --- |
| Windows code (`setup.ps1`, `packages/scoop.txt`, `packages/winget.txt`, `tests/validate-setup-ps1.ps1`) | Remove from the repo; git history keeps it |
| Ubuntu code (`setup.sh` Ubuntu branch, `packages/ubuntu.txt`) | Remove; `setup.sh` fails fast on any non-Arch distro |
| How the dropped scope is recorded | Deferred, future evaluation only (like Mac), not a hard non-goal |
| Windows-hosted WSL test harness (`tests/lib/WslTestInstance.ps1`) | Keep: it is test tooling, not product support |

**Evidence of current Windows / Ubuntu footprint**

- `setup.ps1`, `packages/scoop.txt`, `packages/winget.txt`, `tests/validate-setup-ps1.ps1` (Story 3.1, commit `45598f9`).
- `setup.sh` lines 43 and 51–83: Ubuntu manifest check, Docker/Microsoft apt repositories, apt install, `Supported distros: arch, ubuntu`.
- `packages/ubuntu.txt` (Story 1.3).
- `README.md`: Windows Companion Bootstrap section and `packages/ubuntu.txt` reference.
- `tests/validate-readme.ps1`: Windows section, `setup.ps1` command, and Ubuntu apt assertions.
- `tests/validate-setup.ps1`: Ubuntu-branch `sudo` assertions (lines 73, 81–93).
- SPEC CAP-1, CAP-4, constraints, and success signal; `stack.md` Ubuntu row and Windows section; the architecture spine (AD-2, AD-7, AD-8, structural seed, capability map); epics FR1, FR4, NFR2, and Epic 3.

## 2. Impact Analysis

### Checklist status

| Item | Status | Finding |
| --- | --- | --- |
| 1.1 Trigger story | [x] | No failing story; owner decision during Story 3.1 review |
| 1.2 Problem | [x] | Strategic pivot: Arch-only scope |
| 1.3 Evidence | [x] | Footprint inventory above |
| 2.1 Current epic | [x] | Epic 2 stays viable; needs a cleanup story and Arch-only wording |
| 2.2 Epic-level changes | [!] | Epic 3 removed; Epic 2 gains Story 2.6 |
| 2.3 Remaining epics | [x] | Only Epic 2 remains open |
| 2.4 Obsolete or new epics | [!] | Epic 3 obsolete; no new epic |
| 2.5 Order | [!] | Story 2.6 runs next, before 2.3 |
| 3.1 PRD (SPEC) | [!] | CAP-4 removed; CAP-1, constraints, and success signal narrowed |
| 3.2 Architecture | [!] | AD-2, AD-7, AD-8, diagrams, seed, map, and deferred list updated |
| 3.3 UX | [N/A] | No UX artifacts |
| 3.4 Other artifacts | [!] | `stack.md`, README, validators, `deferred-work.md`, story 3.1 file, sprint-status |
| 4.1 Direct adjustment | Viable | Planning edits plus one cleanup story |
| 4.2 Rollback | Viable (partial) | Removing Story 3.1 output and the Ubuntu branch is required by the decision |
| 4.3 MVP review | Viable | MVP narrowed: CAP-4 deferred, CAP-1 Arch-only |
| 4.4 Selected path | [x] | Hybrid (see section 3) |

### Epic impact

- **Epic 1 (done):** stays closed. Its summary notes that `packages/ubuntu.txt` and the Ubuntu branch are removed by Story 2.6.
- **Epic 2 (in progress):** retitled **Integrated Arch Linux Bootstrap and Dotfiles Sync**. New **Story 2.6: Narrow the Bootstrap to Arch Linux Only** removes Windows and Ubuntu code and tests, and runs next (before 2.3) so that 2.3–2.5 build and test against the Arch-only flow. Stories 2.4 and 2.5 get Arch-only wording; 2.1–2.3 are unaffected.
- **Epic 3 (Windows Companion Alignment):** removed. Story 3.1 is cancelled; Story 3.2 is dropped. The `WslTestInstance.ps1` fix made during Story 3.1 is kept.

### Artifact conflicts

| Artifact | Conflict | Resolution |
| --- | --- | --- |
| SPEC.md | Why, CAP-1, CAP-4, constraints, success signal, and open questions cover Ubuntu and Windows | 4.1 |
| stack.md | Ubuntu manifest row, Windows companion section, `setup.ps1` convention | 4.2 |
| Architecture spine (2026-08-07) | `setup.ps1`, apt/scoop/winget, Ubuntu manifest, CAP-4 binding, multi-distro AD-7 | 4.3 |
| epics.md | FR1, FR4, NFR2, FR map, Epic 3, Stories 2.4 and 2.5 | 4.4 |
| Story 3.1 file | In `review` for removed scope | 4.5 |
| sprint-status.yaml | Epic 3 entries; Story 2.6 missing | 4.6 |
| deferred-work.md | Items about `setup.ps1` and Ubuntu are now moot | 4.7 |
| Readiness report 2026-10-07 | Ubuntu/Windows findings now moot | Historical; not edited. Re-run readiness (section 5) |
| UX | None | N/A |

### Technical impact (delivered by Story 2.6)

- Delete `setup.ps1`, `packages/scoop.txt`, `packages/winget.txt`, `packages/ubuntu.txt`, and `tests/validate-setup-ps1.ps1`.
- `setup.sh`: remove the Ubuntu branch; move the distro check into preflight so a non-Arch host fails before any mutation.
- `tests/validate-setup.ps1` and `tests/validate-readme.ps1`: drop Ubuntu and Windows assertions; add Arch-only assertions.
- README: minimal edits to remove the Windows section and the Ubuntu reference. The full in-repo dotfiles rewrite stays in Story 2.5.
- The Windows-hosted WSL Arch test harness is unchanged.

### MVP impact

The MVP is narrowed rather than redefined. CAP-1 to CAP-3 still hold for Arch Linux on WSL or a VM. CAP-4 (Windows companion) and Ubuntu support are deferred to future evaluation.

## 3. Recommended Approach

**Hybrid: direct adjustment + targeted code removal + MVP narrowing.**

- **Direct adjustment:** planning artifacts are edited in place. The code cleanup becomes Story 2.6 inside Epic 2, so it goes through the normal dev and review loop with the WSL validators.
- **Targeted removal:** Story 3.1 output and the Epic 1 Ubuntu branch are removed. This is required by the decision and keeps dead code out of a public repo.
- **MVP narrowing:** CAP-4 and Ubuntu move to Open Questions as deferred, so they can return later without contradicting the SPEC.

**Rejected alternatives**

- *Keep the code but mark it unsupported:* rejected by Jonas; it leaves untested paths and validator noise.
- *Remove the code within this correct-course:* rejected so that code changes keep a story, review, and validation trail, as in the 2026-10-07 correct-course.

**Effort:** low (mostly deletions and wording). **Risk:** low. The only behavioral change is that `setup.sh` now refuses non-Arch hosts earlier. **Timeline:** shortens remaining work: Epic 3 (two stories) is replaced by one small cleanup story, and Stories 2.3–2.5 test one distro instead of two.

**Scope classification:** Moderate (backlog reorganization plus artifact alignment, no fundamental replan).

## 4. Detailed Change Proposals

### 4.1 SPEC.md (`_bmad-output/specs/spec-dev-env-config-repo/SPEC.md`)

**Why**

```
OLD: A developer working across multiple Linux machines (WSL/VM on Arch and Ubuntu) …
NEW: A developer working across multiple Arch Linux machines (WSL or VM) …
```

**CAP-1**

```
OLD intent:  User can bootstrap a fresh Linux (Arch or Ubuntu) dev environment from zero …
NEW intent:  User can bootstrap a fresh Arch Linux (WSL or VM) dev environment from zero …
```

**CAP-4:** removed. The entry moves to Open Questions as deferred. The ID is retired and not reused.

**Constraints**

```
OLD: - **Linux-first targets:** WSL/VM on Arch and Ubuntu are the primary targets. Per-distro package
       manifests (`packages/arch.txt`, `packages/ubuntu.txt`) are required; Arch and Ubuntu differ
       materially in package names and repo setup (e.g. Docker, .NET).
NEW: - **Arch-only target:** Arch Linux on WSL or a VM is the only supported target. Packages are
       declared in `packages/arch.txt`. `setup.sh` refuses any other distro before mutating the machine.
```

```
OLD: … `setup.sh` / `setup.ps1` orchestrate only. …
NEW: … `setup.sh` orchestrates only. …
```

**Success signal**

```
OLD: A developer on a fresh Arch or Ubuntu machine (WSL or VM) …
NEW: A developer on a fresh Arch Linux machine (WSL or VM) …
```

**Open Questions**

```
OLD: - CI coverage beyond Ubuntu: currently out of scope; scope and trigger conditions undefined.
NEW: - CI coverage: currently out of scope; scope and trigger conditions undefined.
ADD: - Windows companion bootstrap (`setup.ps1` via Scoop and winget, formerly CAP-4): deferred by
       correct-course 2026-10-29; future evaluation only.
ADD: - Additional Linux distros (e.g. Ubuntu): deferred by correct-course 2026-10-29; future evaluation only.
```

*Rationale:* the SPEC is the requirements contract; it must state Arch-only scope and record the deferral.

### 4.2 stack.md

- **Linux package management:** remove the `Ubuntu | packages/ubuntu.txt` row and rename the section heading to "Package management".
- **Windows companion:** remove the section.
- **Scripting convention:** replace "Each platform entry point keeps its bootstrap configuration alongside the script that uses it." with "Bootstrap configuration lives alongside `setup.sh`." Replace "`setup.sh` / `setup.ps1` orchestrate only; …" with "`setup.sh` orchestrates only; …".

### 4.3 Architecture spine (`architecture-config-v2-dotfiles-integration-2026-08-07/ARCHITECTURE-SPINE.md`)

- **Frontmatter:** set `binds: [CAP-1, CAP-2, CAP-3]` and `updated: '2026-10-29'`.
- **Paradigm diagram:** `setup.sh / setup.ps1` → `setup.sh`; `pacman / apt / scoop / winget` → `pacman`.
- **AD-2 Binds:** `setup.sh`, CAP-1, CAP-2 (remove `future setup.ps1` and CAP-4).
- **AD-7, rewritten:**

  ```
  ### AD-7 — Arch-only distro guard
  > Narrowed from multi-distro dispatch by correct-course 2026-10-29.
  - Binds: CAP-1, packages/, setup.sh
  - Prevents: pacman running on a non-Arch host; an unsupported host being partially mutated
  - Rule: setup.sh reads /etc/os-release once during preflight. `ID=arch` is the only supported value;
    any other value exits with an actionable error before any mutation. Packages come solely from
    packages/arch.txt via pacman. Adding a distro later requires a new architecture decision.
  ```

- **AD-8 Binds:** `setup.sh`, `dotfiles/` templates, CAP-1, CAP-3 (remove `setup.ps1` and CAP-4).
- **AD-9:** unchanged. Step (2) "detect the distro" now also enforces the AD-7 guard.
- **Structural seed:** remove the `setup.ps1` and `ubuntu.txt` lines. In the sequence diagram, `pacman / apt` → `pacman`.
- **Capability map:** remove the CAP-4 row.
- **Deferred:** replace "Windows deep integration with integrated dotfiles …" with "**Windows companion bootstrap and non-Arch distros** — dropped from scope by correct-course 2026-10-29; future evaluation only. The removed `setup.ps1` and Ubuntu branch remain in git history (commit `45598f9`)."

### 4.4 epics.md

**FR1**

```
OLD: … bootstrap a fresh Linux development environment …
NEW: … bootstrap a fresh Arch Linux (WSL or VM) development environment …
```

**FR4**

```
OLD: FR4: A developer can bootstrap the Windows companion environment via `setup.ps1` …
NEW: FR4: (Removed by correct-course 2026-10-29 — Windows companion bootstrap deferred.)
```

**NFR2**

```
OLD: NFR2: Linux-first support targets Arch and Ubuntu, with distro-specific package manifests and
     guarded distro-specific commands.
NEW: NFR2: Arch Linux (WSL or VM) is the only supported target; packages come from `packages/arch.txt`,
     and `setup.sh` refuses other distros before any mutation.
```

**FR Coverage Map:** the FR4 row becomes `FR4 | — | removed (deferred) by correct-course 2026-10-29`.

**Epic List**

- Epic 1 summary: append "`packages/ubuntu.txt` and the Ubuntu branch are removed by Story 2.6 (Arch-only scope, correct-course 2026-10-29)."
- Epic 2: retitled **Integrated Arch Linux Bootstrap and Dotfiles Sync**. Goal: "… reach a reproducible Arch Linux environment …".
- Epic 3: replaced with "**Epic 3: Windows Companion Alignment (removed 2026-10-29)** — dropped by correct-course 2026-10-29; Story 3.1 cancelled, Story 3.2 dropped. See `sprint-change-proposal-2026-10-29.md`."
- The full Epic 3 section and its Stories 3.1 and 3.2 are deleted from the body.

**New story (added to Epic 2, implemented next, before 2.3)**

```
### Story 2.6: Narrow the Bootstrap to Arch Linux Only

As the maintainer of config-v2,
I want the repository to contain only the Arch Linux bootstrap path,
So that every tracked script and validator matches the supported scope and nothing untested ships.

Acceptance Criteria:

Given the repository,
When I list tracked files,
Then setup.ps1, packages/scoop.txt, packages/winget.txt, packages/ubuntu.txt and
tests/validate-setup-ps1.ps1 no longer exist
And tests/lib/WslTestInstance.ps1 (Windows-hosted WSL Arch test harness) is kept

Given setup.sh,
When I run it on a host whose /etc/os-release ID is not `arch`,
Then it exits non-zero during preflight with an actionable "only Arch Linux is supported" error
And no package, file, or key mutation happens before that exit (AD-7, AD-9)
And setup.sh contains no apt, dpkg, or Ubuntu repository logic

Given tests/validate-setup.ps1 and tests/validate-readme.ps1,
When the Ubuntu and Windows assertions are removed,
Then they assert the Arch-only guard and the absence of Ubuntu/Windows paths instead
And README.md no longer has a Windows Companion Bootstrap section or a packages/ubuntu.txt reference
  (the full in-repo dotfiles README rewrite stays in Story 2.5)

Given the Windows PowerShell validation commands,
When I run validate-setup.ps1, validate-dotfiles.ps1, validate-readme.ps1 and validate-wsl-test-ca.ps1,
Then all pass
```

**Story 2.4:** first AC "Given the supported Linux setup flow" → "Given the supported Arch Linux setup flow".

**Story 2.5:** retitled "Refresh Arch Linux Documentation and README Validation". First AC gains "**And** it states Arch Linux (WSL or VM) as the only supported target and lists Windows and other distros as deferred (FR1, NFR2)".

### 4.5 Story 3.1 file (`3-1-align-setup-ps1-with-shared-repository-contract.md`)

- `Status: review` → `Status: cancelled`.
- Add a note under the title: "Cancelled by correct-course 2026-10-29 (Arch Linux only). Code is removed by Story 2.6. The `tests/lib/WslTestInstance.ps1` stderr fix from this story is kept as shared test infrastructure."
- The file stays as history.

### 4.6 sprint-status.yaml

```yaml
  # Epic 2: Integrated Arch Linux Bootstrap and Dotfiles Sync
  epic-2: in-progress
  2-1-create-an-in-repo-dotfiles-source-tree: done
  2-2-apply-local-dotfiles-from-setup-sh: done
  2-6-narrow-the-bootstrap-to-arch-linux-only: backlog  # implement next, before 2-3
  2-3-preserve-stateful-asset-safety-in-the-integrated-flow: backlog
  2-4-add-smoke-verification-for-integrated-bootstrap: backlog
  2-5-refresh-arch-linux-documentation-and-readme-validation: backlog
  epic-2-retrospective: optional

  # Epic 3 removed by correct-course 2026-10-29 (Windows companion dropped; Arch Linux only)
```

The Story 2.5 key follows its new title; it is still `backlog` and has no story file, so the rename is safe. `last_updated` is set to 2026-10-29.

### 4.7 deferred-work.md

Mark items moot because of the scope cut as `(moot: Arch-only scope, correct-course 2026-10-29)`:

- the `tests/validate-setup-ps1.ps1` regex-only item;
- the `setup.ps1` inline-comment parsing half of the manifest item (the Arch manifest comment/blank filtering half stays open);
- the `gpg --dearmor` Ubuntu rerun item (the `sudo -v` and legacy chezmoi config items stay open);
- the "Ubuntu sudo check is a substring heuristic" item (other `validate-setup.ps1` items stay open).

### 4.8 Commits

1. `test: capture expected setup.sh stderr in WSL helper` — the uncommitted `tests/lib/WslTestInstance.ps1` fix. It is independent of the scope cut and needed by every validator.
2. `docs(planning): correct course to Arch Linux only (Epic 3 removed, Story 2.6 added)` — this proposal and edits 4.1–4.7.

## 5. Implementation Handoff

**Scope:** Moderate.

| Role | Responsibility |
| --- | --- |
| Developer (this session, after approval) | Apply proposals 4.1–4.7 and make the two commits (4.8) |
| PM / Architect | Optional: re-run `bmad-check-implementation-readiness`; the 2026-10-07 report's Ubuntu and Windows findings are now moot |
| Developer | `bmad-create-story` 2.6 → `bmad-dev-story` → code review; then Stories 2.3 → 2.4 → 2.5 |

**Success criteria**

- No tracked artifact (SPEC, stack, spine, epics, README, scripts, validators) describes Windows or Ubuntu as supported. They appear only as deferred.
- `sprint-status.yaml` has no Epic 3 entries, includes Story 2.6, and matches `epics.md`.
- After Story 2.6, `setup.sh` refuses non-Arch hosts before any mutation, and all four remaining validators pass under Windows PowerShell.
