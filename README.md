# henv

HEP virtual environment manager — a single bash script that creates and activates
Python virtual environments for HEP analysis workflows.

```
henv .                          # create + activate local .venv
henv --name hep2026             # named global env
henv -n hep2026                 # -n is a short alias for --name
henv . --run python script.py   # run without interactive subshell
```

Designed for the [hepyy](https://github.com/matplo/hepyy) workflow: spin up a
venv (with `cppyy` + `hepyy` installed by default), build HEP packages, analyse.

---

## Install

**One-liner:**
```bash
curl -fsSL https://raw.githubusercontent.com/matplo/henv/main/henv \
  -o ~/.local/bin/henv && chmod +x ~/.local/bin/henv
```

**Self-installing (also checks that `~/.local/bin` is in your PATH):**
```bash
curl -fsSL https://raw.githubusercontent.com/matplo/henv/main/henv | bash -s -- --install
```

**From a clone:**
```bash
git clone https://github.com/matplo/henv
ln -s "$PWD/henv/henv" ~/.local/bin/henv
```

---

## Usage

```
henv [OPTIONS] [LOCATION]
```

### Location

| Invocation | Env path | Registered as |
|------------|----------|---------------|
| `henv` | `$HOME/.henvs/default` | `default` |
| `henv .` | `$PWD/.venv` | basename of `$PWD` |
| `henv /abs/path` | `/abs/path/.venv` | basename of `/abs/path` |
| `henv rel/path` | `$PWD/rel/path/.venv` | basename of `rel/path` |
| `henv --name foo` | registered path for `foo`, or `$HOME/.henvs/foo` if new | `foo` |
| `henv --name foo .` | `$PWD/.venv` | `foo` (overrides the derived name) |

If the env already exists it is activated immediately — no reinstall, no prompts.
Every row above also registers the env under a name — see
[Name registry](#name-registry) below.

### Options

```
--name NAME / -n NAME        named env: the registered path for NAME, or $HOME/.henvs/NAME if new
--global                     explicit global default (same as no LOCATION)
--python PATH                explicit Python interpreter
--packages-dir PATH          set HEPYY_PACKAGES_DIR in the activated shell
--system-packages-dir PATH   set HEPYY_SYSTEM_PACKAGES_DIR (read-only shared base)
--run CMD ... / -x CMD ...   run CMD inside the env (no interactive subshell)
--update                     self-update henv from GitHub
--install                    install henv to ~/.local/bin
--print-activate             emit shell commands for eval (parent-shell activation)
--list                       list all known envs (registry + $HOME/.henvs/)
--list --json                list envs as a JSON array
--delete                     delete the resolved env (and its registry entry)
--info                       print diagnostics for the resolved env
--recreate                   delete and rebuild the resolved env before activating/running
--mv NEWPATH                 recreate the resolved env at NEWPATH and update the registry
--fix-cppyy                  remove the venv's binary cppyy wheel if a system build is found
--no-cppyy                   force --fix-cppyy's removal even without a detected system cppyy
--no-hepyy / --nh            skip installing cppyy + hepyy on env creation
--yes / -y                   non-interactive; auto-answer yes to all prompts
--quiet / -q                 suppress [henv] info banners (warnings/errors still shown)
--version                    print version
-h / --help                  usage
```

---

## Typical session

```bash
# Create a project-local env and drop into it
cd ~/myanalysis
henv .
# → creates .venv, installs cppyy + hepyy, activates subshell
# → PS1 shows: (henv:myanalysis) ...

heyy install fastjet hepmc3 pythia8
python my_analysis.py
exit                                   # back to parent shell

# Re-activate later (existing env — no prompts)
henv .
```

---

## Activation modes

### Subshell (default)

`henv` spawns an interactive bash subshell with the venv activated. Type `exit` or
press Ctrl-D to return to the parent shell. The parent shell's environment is
unchanged.

```bash
henv .
# (henv:myanalysis) ploskon@host $ ...
exit
# back to normal prompt
```

### Parent-shell activation (eval)

To activate in the current shell without a subshell:

```bash
eval "$(henv --print-activate .)"
```

Add this helper to `~/.bashrc` for convenience:
```bash
hactivate() { eval "$(henv --print-activate "$@")"; }
```

Then use:
```bash
hactivate .            # local .venv
hactivate --name hep2026
```

---

## Python tool detection

`henv` picks the creation tool in this order:

1. **uv** — fastest, used if `uv` is in PATH
2. **virtualenv** — used if `virtualenv` binary is in PATH
3. **python -m virtualenv** — used if virtualenv is installed as a module
4. **python -m venv** — stdlib fallback, always available with Python 3.3+

Override the interpreter with `--python /path/to/python3.11`.

---

## hepyy integration

`henv` is predominantly used with [hepyy](https://pypi.org/project/hepyy/), so
new envs get `cppyy` and `hepyy` installed by default (a plain `pip install`
now that hepyy is on PyPI — no prompt, no GitHub fallback) and `heyy init`
run automatically:

```bash
henv .                 # creates the env with cppyy + hepyy already installed
heyy install fastjet hepmc3 pythia8
```

Skip both with `--no-hepyy` (or `--nh`) for a bare venv:
```bash
henv . --no-hepyy
```

Whenever `heyy` (or its aliases `hepyy` / `her`) is present in the venv, `henv`
wires it up automatically — every time you enter the subshell or use `--run`:
- TCL modulefiles are regenerated for all installed packages (`heyy generate-modules`)
- If a `module` command (Lmod / Environment Modules) is available, the modulefiles
  directory is registered with `module use` so `module load fastjet/3.5.1` works

Additionally in the interactive subshell:
- Tab completion for `heyy` / `hepyy` / `her` is enabled

### Completion in your normal shell

The subshell/`--run` completion above only exists inside `henv`. Right after
`heyy` gets installed into a new env, `henv` also prints the one-liner to
enable `heyy` completion in your regular shell — so it works even outside
`henv`, as long as `heyy` is on `PATH` (e.g. once you've activated a venv
some other way):

```bash
# Bash — add to ~/.bashrc:
eval "$(heyy completion)"

# Zsh — add to ~/.zshrc:
eval "$(heyy completion)"

# Fish — add to ~/.config/fish/config.fish:
heyy completion --shell fish | source
```

### `EXTRA_CLING_ARGS` / `CC` / `CXX` on Linux

`cppyy-cling` embeds its own frozen Clang, which can fail to recognize a GCC
installation newer than anything it was built to know about — on Perlmutter
(GCC 14), `import cppyy` crashed with `fatal error: 'filesystem' file not
found`. The fix is exporting `EXTRA_CLING_ARGS` with `-isystem` flags for
GCC's real include search path (including plain `/usr/include` — GCC's C++
header wrappers like `<cfenv>` use `#include_next` to reach the real glibc
headers there, so leaving it out just trades one missing-header error for
another).

Whenever `heyy` is present in the venv, `henv` computes this automatically
**on Linux only**, fresh from *this machine's own* `g++ -E -Wp,-v` output —
never a hardcoded GCC version or distro triplet, so it's a genuine no-op on
a machine where cling already works fine. `CPATH`/`CPLUS_INCLUDE_PATH`/
`C_INCLUDE_PATH` are unset just for that one probe: whatever they inject
(e.g. a CUDA toolkit's include dirs, seen on Perlmutter via the NVIDIA HPC
SDK module) would otherwise end up in the `-isystem` list too — and their
mere presence there was enough to make `cppyy-cling` try, and fail, to
build a CUDA-aware precompiled header. `EXTRA_CLING_ARGS` only needs GCC's
own toolchain-native search path, not whatever else the ambient shell has
injected for unrelated purposes.

`henv` also points `CC`/`CXX` at `gcc`/`g++` specifically (same "unless
already set" rule). This matters separately from the `-isystem` fix above:
some setups don't keep the generic `cc`/`c++` names in sync with `gcc`/`g++`
— also seen on Perlmutter, where `c++` stayed pinned to SUSE's base GCC
7.5.0 even after `module load gcc-native/14` updated `gcc`/`g++` to 14.3.0.
Anything that respects `CC`/`CXX` then gets the modern compiler instead of
falling back to whatever `cc`/`c++` happen to resolve to.

All three (`EXTRA_CLING_ARGS`, `CC`, `CXX`) are computed **once**, at the
exact moment you run `henv` (or `--run`/`--print-activate`) — before that,
not continuously. Load whichever `gcc` module you want *before* running
`henv`, not after; loading a different one inside an already-activated
`henv` subshell won't retroactively update values already baked into that
shell. Any of the three you've already set yourself — including an explicit
`export EXTRA_CLING_ARGS=""` as a deliberate opt-out of all three — is
always left untouched.

---

## Running commands

`--run` (or its short alias `-x`) performs the same full initialization as the interactive subshell: sources
the shell rc (for `module` function availability), activates the venv, sets
`HEPYY_PACKAGES_DIR` / `HEPYY_SYSTEM_PACKAGES_DIR`, regenerates TCL modulefiles,
and registers the modulefiles directory with `module use`. Module commands therefore
work as expected inside `--run`:

```bash
# Run a script in the env without entering a subshell
henv . --run python analysis.py
henv . -x python analysis.py          # -x is a short alias for --run

# Run a one-liner
henv --name hep2026 --run python -c "import fastjet; print('ok')"

# Check what is installed
henv . --run pip list
henv . --run heyy list

# Module commands work — same as inside the interactive subshell
henv . --run module avail
henv . --run module list
```

---

## Managing envs

```bash
henv --list                    # list every known env: registry + $HOME/.henvs/
henv --list --json             # same, as a JSON array (for scripting/tooling)
henv --name old-env --info     # path, python version, size, heyy version/packages
henv --name old-env --delete   # delete an env (prompts for confirmation)
henv --name old-env --delete --yes   # skip prompt
henv --name old-env --recreate --yes # delete and rebuild in one step
```

`--quiet` (or `-q`) suppresses the `[henv]` info banners — useful when scripting
`--run`/`-x`:
```bash
henv . -q -x pip list
```

---

## Name registry

Every env — global (`--name`) or local (`henv .` / `henv path`) — is recorded
in `$HOME/.henvs/registry.json` under a name (this is henv's own registry
file, unrelated to the `registry.json` hepyy keeps inside a packages
directory). The name is whatever `--name` gives explicitly, or otherwise the
basename of the directory for a location, or `"default"` when neither is
given.

Once a name is registered, `--name`/`-n` resolves it from anywhere, not just
from inside that directory:

```bash
cd ~/proj/backend && henv .          # registers 'backend' -> ~/proj/backend/.venv
cd / && henv --name backend --info   # finds it from any directory
cd / && henv -n backend              # activates it from any directory
```

A name derived from a location that would collide with a *different* path
already registered under that name is refused — pass `--name` explicitly to
give the new env a distinct name instead. `--name` (explicit, or the bare
`henv`/`henv --name default` case) is always authoritative: it re-points the
registry if the name already pointed elsewhere, printing an info line when
it does so a typo doesn't silently orphan an env.

```bash
# Give a local env a name other than its directory's basename:
henv --name analysis-2026 ~/scratch/run-42
```

If you move an env's directory yourself with a plain `mv` (use
[`--mv`](#moving-an-env) instead — see why below), henv has no way to know:
the registry entry is left pointing at the now-gone old path, and there's no
"old" env left to run `--mv` against. Just hand-edit
`$HOME/.henvs/registry.json` to point the name at the new location — it's a
plain JSON file, `{"NAME": {"path": "..."}, ...}`, safe to edit directly as
long as it stays valid JSON:
```bash
python3 -c "
import json
p = '$HOME/.henvs/registry.json'
d = json.load(open(p))
d['NAME']['path'] = '/the/new/path'
json.dump(d, open(p, 'w'), indent=2)
"
```
Note this only fixes henv's bookkeeping — a hand-moved venv still has the
absolute-path problems described below, which is exactly why `--mv` doesn't
just move the directory either.

Concurrency: the registry is a plain JSON file, read-modify-written with no
locking. Fine for a personal/lab CLI used by one person at a time; two `henv`
invocations racing to register different names at the exact same instant
could in principle clobber each other's write.

## Moving an env

```bash
henv --name backend --mv /new/path/backend-env
```

This is **not** a byte-for-byte move. A venv bakes absolute paths into
`bin/activate*` and into the shebang line of every installed script (and
`cppyy`'s compiled libraries can embed absolute RPATHs too), so a plain `mv`
of the directory would leave all of that pointing at a path that no longer
exists. `--mv` instead deletes the old env and recreates a fresh one at the
new path — `cppyy`/`hepyy` come back the same way they would for any new env
— then updates the registry. **Packages installed beyond `cppyy`/`hepyy` are
not preserved** — reinstall them after. Pass `--yes` if the destination
already exists (it gets removed first) and `--no-hepyy` if you don't want
`cppyy`/`hepyy` reinstalled at the new location.

---

## Self-update

```bash
henv --update
```

Downloads the latest script from GitHub and replaces the current installation.
Works for curl-installed copies. If you installed from a git clone, use
`git pull` in the repo directory instead.

The previous version is backed up alongside it (e.g. `~/.local/bin/henv.bak`)
before the overwrite, so a bad update can be undone with `mv henv.bak henv`.

---

## Package sharing on HPC / shared filesystems

`henv` can set `HEPYY_PACKAGES_DIR` and `HEPYY_SYSTEM_PACKAGES_DIR`
automatically so the activated shell knows where hepyy's package store lives.

### Flags

```
--packages-dir PATH        set HEPYY_PACKAGES_DIR (your writable package store)
--system-packages-dir PATH set HEPYY_SYSTEM_PACKAGES_DIR (read-only shared base)
```

### Auto-detection from `.hepyy.toml`

If a `.hepyy.toml` file exists in the current directory, `henv` reads it:

```toml
# .hepyy.toml
packages_dir        = "~/.hepyy_packages"
system_packages_dir = "/shared/hep/packages"
```

Flags take precedence over the TOML file.

### Workflows

**Single user, custom packages dir:**
```bash
henv --packages-dir /scratch/$USER/hep_packages .
# → HEPYY_PACKAGES_DIR=/scratch/$USER/hep_packages in the subshell
```

**Admin builds once, users share (read-only):**
```bash
# Admin (once):
export HEPYY_PACKAGES_DIR=/shared/hep/packages
heyy install fastjet hepmc3 pythia8 cppyy --force

# Each user (no compilation):
henv --packages-dir ~/.hepyy --system-packages-dir /shared/hep/packages .
# Inside subshell:
#   HEPYY_PACKAGES_DIR        = ~/.hepyy       (writable — your own packages)
#   HEPYY_SYSTEM_PACKAGES_DIR = /shared/hep/packages (read-only — admin packages)
#
# heyy list         shows both shared and personal packages
# heyy install pkg  installs to ~/.hepyy only
# import fastjet    resolves from the shared prefix automatically
```

> **macOS + cppyy:** cppyy has to be built from source there (~10-30 min) to
> get a `cling` that can parse the current SDK's headers — see
> [Fixing a broken binary cppyy wheel](#fixing-a-broken-binary-cppyy-wheel)
> below. Building it once into a shared `--system-packages-dir` this way
> makes that a one-time cost instead of paying it on every `henv`-created
> env.

**Parent-shell activation with shared packages:**
```bash
eval "$(henv --system-packages-dir /shared/hep/packages --print-activate .)"
```

See [WORKFLOW-EXAMPLE.md](https://github.com/matplo/hepyy/blob/main/WORKFLOW-EXAMPLE.md)
in the hepyy repository for full step-by-step examples.

### Fixing a broken binary cppyy wheel

On some platforms, the binary `cppyy` wheel installed by default doesn't
work, while a shared build registered under `--system-packages-dir` does.
When `--system-packages-dir` is set on env creation, henv already checks for
this and swaps the venv-local wheel out automatically. `--fix-cppyy` re-runs
that same check against an existing env — e.g. when `--system-packages-dir`
was only registered after the env was created:

```bash
henv --name old-env --system-packages-dir /shared/hep/packages --fix-cppyy
```

It only acts when a `cppyy` entry is found in the system dir's
`registry.json` — pass `--no-cppyy` alongside it (at creation or with
`--fix-cppyy`) to force the removal regardless. This is unrelated to
`heyy`'s own `fix-cppyy` command, which repairs broken library paths in an
already-installed cppyy rather than swap it out for a different build.

**On macOS specifically**, the binary wheel's `cling` (LLVM 16) can't parse
the C++ headers in current macOS SDKs, so the very first `import cppyy`
crashes while building its precompiled-header cache — `heyy` warns about
this before it happens (pointing at the fix below) rather than leaving you
to decode the crash. Build a working one from source, once, into a shared
dir, then point every env at it:

```bash
export HEPYY_PACKAGES_DIR=/shared/hep/packages   # or e.g. ~/.hepyy_shared for a single machine
heyy install cppyy --force                        # ~10-30 min, one-time; builds cling
                                                    #   pinned to an older, compatible SDK

henv --system-packages-dir /shared/hep/packages --fix-cppyy   # existing env
henv --system-packages-dir /shared/hep/packages .             # new envs — instant, no rebuild
```

---

## Requirements

- bash 3.2+ (works with macOS system bash)
- Python 3.8+
- `curl` (for `--update` and `--install`)
- One of: `uv`, `virtualenv`, or `python3 -m venv` (stdlib)

---

## Development

```bash
bash -n henv          # syntax check
shellcheck henv       # lint
bash test/smoke.sh    # functional smoke test (runs against a temp $HOME)
```

CI (`.github/workflows/ci.yml`) runs all three on every push/PR to `main`.
