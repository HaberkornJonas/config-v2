---
type: architecture-review
subtype: adversarial
target: ARCHITECTURE-SPINE.md
reviewer: adversarial-architecture-agent
date: 2026-08-05
verdict: FAIL
---

# Adversarial Architecture Review — config-v2 Spine

## Verdict: FAIL

Two concrete unit pairs were constructed that each satisfy every AD in the spine yet build
incompatibly. Both pairs reveal structural holes that must be closed before implementation
begins.

---

## Pair 1 — SSH Config File: Dual Ownership Under AD-4

### The two units

**Unit A — `setup.sh` SSH-keygen epic (CAP-3, idempotent re-run)**

```bash
# Complies with AD-1: lives in config-v2
# Complies with AD-2: does not reimplement chezmoi; generates keys only
# Complies with AD-3: reads SSH_KEY_COMMENT and SSH_KEY_TYPE from config.sh
# Complies with AD-4: test -f before any write

if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
  ssh-keygen -t ed25519 -C "$SSH_KEY_COMMENT" -f "$HOME/.ssh/id_ed25519" -N ""
fi

if [ ! -f "$HOME/.ssh/config" ]; then
  cat > "$HOME/.ssh/config" <<EOF
Host github.com
  IdentityFile ~/.ssh/id_ed25519
  AddKeysToAgent yes
EOF
fi
```

This unit treats `~/.ssh/config` as a **stateful asset**: it writes it once, then skips on
re-run. AD-4 says "If present: skip + log." AD-4 compliant. AD-1 compliant (lives in
config-v2). AD-2 compliant (does not touch dotfiles state).

---

**Unit B — chezmoi dotfiles `~/.ssh/config` template (CAP-2, sync dotfiles)**

```
# dotfiles repo: dot_ssh/config.tmpl
# Complies with AD-1: lives in dotfiles repo, applied by chezmoi
# Complies with AD-2: setup.sh delegates to chezmoi; chezmoi owns this file
# Complies with AD-4 (Consistency Convention): "chezmoi-tracked files always overwritten on apply"

Host github.com
  IdentityFile ~/.ssh/id_rsa          # <-- different key filename
  AddKeysToAgent yes
  UseKeychain yes                     # <-- macOS-only flag, added by dotfiles author
```

This unit treats `~/.ssh/config` as a **chezmoi-managed file**: always overwritten. The
Consistency Conventions explicitly state "Repo-owned files applied by chezmoi are always
overwritten." AD-4 compliant. AD-1 compliant (lives in dotfiles repo). AD-2 compliant
(chezmoi owns dotfile state).

---

### Why they are incompatible

AD-4 defines two mutually exclusive write policies but assigns no file to either category:

| Policy | Trigger | Effect |
|---|---|---|
| Stateful-asset guard | `test -f` before write | Skip if present; preserve user state |
| Chezmoi-managed | chezmoi-tracked file | Always overwrite on `chezmoi apply` |

`~/.ssh/config` is never assigned to either policy in the spine. Unit A's author assigns it
to policy 1 (stateful); Unit B's author assigns it to policy 2 (chezmoi-managed). Both are
AD-compliant.

**Concrete failure modes:**

1. **Silent key-path mismatch.** Unit A generates `id_ed25519`; Unit B's template references
   `id_rsa`. After `chezmoi apply` the SSH config points to a key that does not exist.
   Authentication breaks silently with no log output because no script detects the mismatch.

2. **State-oscillation on re-run.** On the first run, setup.sh writes `~/.ssh/config` (Unit
   A), then chezmoi overwrites it (Unit B). On re-run, setup.sh skips the file (present),
   chezmoi overwrites it again. The machine converges, but only because chezmoi always wins —
   a dependency on execution order that the spine never mandates and that could be broken by
   any future re-ordering.

3. **Ownership ambiguity on conflict.** If a user edits `~/.ssh/config` manually (adds a
   corporate host block), Unit A skips it (AD-4: present → skip), Unit B destroys it (AD-4
   Consistency Convention: always overwrite). Both behaviours are spine-correct; the user
   loses their edit with no warning.

### Hole to close

> **Proposed AD-7 — Stateful-asset boundary is explicit and exhaustive**
>
> - **Binds:** AD-4, setup.sh, chezmoi-managed files list
> - **Prevents:** dual ownership of the same file path; silent key-path mismatches
> - **Rule:** The spine (or a companion boundary table tracked in config-v2) must enumerate
>   every file path that is a "stateful user asset" (policy: test-before-write, skip if
>   present) and every path that is "chezmoi-managed" (policy: always overwrite). No file
>   path may appear in both lists. Any file that setup.sh touches must be explicitly
>   classified. Specifically: SSH private-key files (`~/.ssh/id_*`, `~/.ssh/*.pem`) are
>   always stateful assets; `~/.ssh/config` must be assigned to exactly one policy at spine
>   level before implementation begins. The canonical SSH key filename (`id_ed25519`,
>   `id_rsa`, etc.) must be declared once in config.sh.template and referenced identically
>   in both setup.sh and any chezmoi dotfiles template.

---

## Pair 2 — config.sh Key Namespace: Two Scripts, Divergent Key Names

### The two units

**Unit A — `setup.sh` (Linux bootstrap, CAP-1)**

Implemented by Developer L. Sources config.sh at start (AD-3). Reads:

```bash
source ./config.sh          # AD-3 compliant: sole parameter source
chezmoi init --apply "$DOTFILES_REPO"
git config --global user.name  "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"
gpg --import-key "$GPG_KEY_ID"
```

Key names chosen: `DOTFILES_REPO`, `GIT_NAME`, `GIT_EMAIL`, `GPG_KEY_ID`.
All AD-3 compliant. All in config-v2. All `KEY=value` bash-sourceable format.

---

**Unit B — `setup.ps1` (Windows bootstrap, CAP-4)**

Implemented by Developer W. Sources config.sh at start (AD-3). PowerShell parses the
bash-format file (valid AD-3 interpretation: "scripts source config.sh"). Reads:

```powershell
# AD-3 compliant: parses config.sh as sole parameter source
$cfg = Get-Content config.sh | Where-Object { $_ -match '^[A-Z_]+=.*' } |
       ForEach-Object { $k,$v = $_ -split '=',2; [PSCustomObject]@{Key=$k;Val=$v} }

$dotfilesUrl  = ($cfg | Where Key -eq 'DOTFILES_URL').Val     # <-- different key
$gitUserName  = ($cfg | Where Key -eq 'GIT_USER_NAME').Val    # <-- different key
$gitUserEmail = ($cfg | Where Key -eq 'GIT_USER_EMAIL').Val   # <-- different key
$gpgFingerprint = ($cfg | Where Key -eq 'GPG_FINGERPRINT').Val # <-- different key
```

Key names chosen: `DOTFILES_URL`, `GIT_USER_NAME`, `GIT_USER_EMAIL`, `GPG_FINGERPRINT`.
All AD-3 compliant. All in config-v2. All `KEY=value` format.

---

### Why they are incompatible

The spine mandates a single config.sh as the sole parameter source but specifies **no
canonical key schema**. AD-3 says "All configurable runtime values … are declared in
`config.sh`" but does not enumerate what those keys are or what they must be named.

**Concrete failure modes:**

1. **Silent empty-value substitution.** On Linux, `$DOTFILES_URL` is undefined (Unit A used
   `DOTFILES_REPO`). `chezmoi init --apply ""` exits with an error. On Windows,
   `$DOTFILES_REPO` is undefined; setup.ps1 invokes chezmoi with an empty URL. Both fail at
   runtime, not at lint/review time, because the key-name contract exists only implicitly
   inside each script.

2. **config.sh.template is incoherent.** The template must satisfy both scripts. Without a
   schema, it will either: (a) include both `DOTFILES_REPO` and `DOTFILES_URL` as duplicate
   keys with no indication of which is canonical; or (b) include only one, silently breaking
   the other platform's script. Both outcomes are undetectable by reading the spine.

3. **Cross-platform parameter drift.** Over time, any new parameter added for Linux (e.g.,
   `LOCALE`, `TIMEZONE`) will be named differently or omitted on Windows, because there is no
   schema contract to enforce parity. AD-3's "sole parameter source" guarantee is structurally
   undermined: there is one file but two incompatible vocabularies reading it.

4. **No AD prevents a future script from introducing a third naming convention.** A CI script
   or a `run_once_` hook in the dotfiles repo could introduce `DOTFILES_REPOSITORY`,
   `USER_GIT_EMAIL`, etc., and every instance would comply with AD-3.

### Hole to close

> **Proposed AD-8 — config.sh key schema is canonical and exhaustive**
>
> - **Binds:** AD-3, config.sh.template, setup.sh, setup.ps1
> - **Prevents:** divergent key names for the same runtime value; silent empty-variable
>   failures; template incoherence
> - **Rule:** `config.sh.template` is the single authoritative schema for all runtime
>   parameters. Every key that any script in config-v2 reads must be declared in
>   `config.sh.template` with: (1) the exact key name, (2) a comment stating which scripts
>   consume it and on which platforms, (3) an example value. No script may read a key that
>   is not in the template. A key may not be renamed between platforms; cross-platform
>   scripts must use identical key names for the same logical value. A linter or a pre-commit
>   hook must verify that every key referenced in setup.sh and setup.ps1 exists verbatim in
>   config.sh.template. Required initial canonical keys: `DOTFILES_REPO` (URL, all
>   platforms), `GIT_USER_NAME` (string, all platforms), `GIT_USER_EMAIL` (email, all
>   platforms), `GPG_FINGERPRINT` (string, all platforms).

---

## Summary Table

| # | Unit A | Unit B | Clash type | AD gap | Proposed fix |
|---|---|---|---|---|---|
| 1 | setup.sh SSH-keygen epic | chezmoi dotfiles `~/.ssh/config` template | Dual ownership of same file path; conflicting write policies | AD-4 assigns no file to either policy; SSH key filename is unspecified | AD-7: explicit stateful-asset boundary table; canonical SSH key name in template |
| 2 | setup.sh Linux bootstrap | setup.ps1 Windows bootstrap | Divergent config.sh key names for same runtime values | AD-3 mandates a single file but specifies no key schema | AD-8: canonical exhaustive key schema in config.sh.template with linter enforcement |

---

## Recommended Actions (Priority Order)

1. **Add AD-8 first.** It is a pure authoring constraint with zero implementation cost. Add a
   `config.sh.template` with the four canonical required keys before any script is written.
   This closes Pair 2 entirely.

2. **Add AD-7 as a companion to AD-4.** Produce a boundary table (a markdown table in the
   spine or a `ASSET-BOUNDARY.md` file tracked in config-v2) that assigns every file path
   touched by setup.sh to either "stateful asset" or "chezmoi-managed." Declare the canonical
   SSH key filename (`SSH_KEY_FILE=id_ed25519`) as a required key in config.sh.template.

3. **Resolve the bootstrap entry-point open question** before the first implementation sprint.
   The deferred question (curl-to-setup.sh vs. chezmoi-init-first) directly affects whether
   Pair 1's execution order can oscillate (if chezmoi runs before setup.sh on one path and
   after on another, the stateful-asset guard behaviour changes). This is not merely an
   implementation detail — it is an ordering invariant that must be pinned by an AD.
