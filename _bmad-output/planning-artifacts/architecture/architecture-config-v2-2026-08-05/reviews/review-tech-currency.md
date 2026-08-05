---
type: review
subject: ARCHITECTURE-SPINE.md — Technology Currency
reviewer: architecture-reviewer-agent
date: 2026-08-05
verdict: WARN
---

# Review: Technology Currency — Architecture Spine (config-v2)

## Verdict: WARN

All tools are real, exist, and fit the stated purpose. One tool carries a meaningful staleness risk; one minor flag on low recent activity. No tools are deprecated or fundamentally mis-fitted. No false version claims are asserted (the spine correctly defers version pinning to implementation).

---

## Findings

### WARN-1 — `fast-syntax-highlighting` is 13+ months stale [HIGH CONFIDENCE]
- **Repo:** `zdharma-continuum/fast-syntax-highlighting`
- **Last commit:** 2025-07-16 — **over 13 months ago** as of this review (2026-08-05)
- **Status:** Not archived, but no commits in 2026. Stars: 1,740.
- **Risk:** The repo has a history of abandonment (original `zdharma` account deleted all repos in 2021; community forked under `zdharma-continuum`). The low commit cadence in 2025–2026 repeats that pattern. Several community dotfile setups have migrated away from it.
- **Alternative confirmed active:** `zsh-users/zsh-syntax-highlighting` (last push 2026-02-08) — the canonical upstream maintained by the zsh-users organization.
- **Action:** Confirm this plugin is still the intended choice before implementation. If yes, add a note acknowledging the maintenance risk. If uncertain, `zsh-users/zsh-syntax-highlighting` is the lower-risk default.

### WARN-2 — `zsh-autosuggestions` is ~14 months without a commit [LOW CONCERN]
- **Repo:** `zsh-users/zsh-autosuggestions`
- **Last push:** 2025-06-24 — ~14 months ago.
- **Status:** Not archived. 32 k+ stars. This plugin is functionally complete and considered stable/mature by the community. No successor or replacement has emerged.
- **Risk:** Very low — the feature set is complete and the plugin has no known active bugs that would affect a typical dev env setup. Flagging for completeness only.
- **Action:** No change required. Acceptable to keep as-is; revisit only if installation issues arise.

---

## Confirmed Current — No Action Required

| Tool | Confirmed Status | Evidence |
|------|-----------------|----------|
| **chezmoi** | ✅ Active — v2.72.0 released 2026-08-02 | GitHub releases API |
| **zinit** | ✅ Active — last commit 2026-07-28, ~4,800 stars | GitHub commits API |
| **fnm** | ✅ Active — v1.39.0 released 2026-03-06 | GitHub releases API |
| **starship** | ✅ Active — v1.26.0 released 2026-06-28 | GitHub releases API |
| **zoxide** | ✅ Active — v0.10.0 released 2026-07-04 | GitHub releases API |
| **fzf-tab** | ✅ Active — last push 2026-06-04 | GitHub API |
| **Scoop (Windows)** | ✅ Active and maintained community package manager | Public knowledge |
| **winget "inbox (Windows 11)"** | ✅ Accurate — ships with Windows 11 by default | Public knowledge |

**chezmoi** is confirmed the leading dotfile manager in 2026. No alternative has meaningfully superseded it. The spine's choice is well-fitted.

**zinit** is confirmed actively maintained under `zdharma-continuum`. The concerns from 2021 (original author deleting repos) do not apply to the current fork — recent commits as recently as July 28, 2026 confirm ongoing maintenance.

---

## Not Checked (Out of Scope / Deferred in Spine)
- Specific distro package versions for `zsh`, `docker`, `neovim`, `tmux` — spine correctly states "distro package / latest stable" and defers version pinning to implementation.
- `curl | bash` bootstrap security tradeoffs — architectural design decision, not a currency issue.
- chezmoi template syntax compatibility — deferred in spine to dotfiles repo scope.

