# henv

HEP virtual environment manager — a single bash script that creates and activates
Python virtual environments for HEP analysis workflows.

```
henv .                          # create + activate local .venv
henv --name hep2026             # named global env
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

| Invocation | Env path |
|------------|----------|
| `henv` | `$HOME/.henvs/default` |
| `henv .` | `$PWD/.venv` |
| `henv /abs/path` | `/abs/path/.venv` |
| `henv rel/path` | `$PWD/rel/path/.venv` |
| `henv --name foo` | `$HOME/.henvs/foo` |

If the env already exists it is activated immediately — no reinstall, no prompts.

### Options

```
--name NAME                  named global env: $HOME/.henvs/NAME
--global                     explicit global default (same as no LOCATION)
--python PATH                explicit Python interpreter
--packages-dir PATH          set HEPYY_PACKAGES_DIR in the activated shell
--system-packages-dir PATH   set HEPYY_SYSTEM_PACKAGES_DIR (read-only shared base)
--run CMD ... / -x CMD ...   run CMD inside the env (no interactive subshell)
--update                     self-update henv from GitHub
--install                    install henv to ~/.local/bin
--print-activate             emit shell commands for eval (parent-shell activation)
--list                       list envs under $HOME/.henvs/
--list --json                list envs as a JSON array
--delete                     delete the resolved env
--info                       print diagnostics for the resolved env
--recreate                   delete and rebuild the resolved env before activating/running
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
henv --list                    # list all global envs
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
