# henv

HEP virtual environment manager — a single bash script that creates and activates
Python virtual environments for HEP analysis workflows.

```
henv .                          # create + activate local .venv
henv --name hep2026             # named global env
henv . --run python script.py   # run without interactive subshell
```

Designed for the [heppyyier](https://github.com/matplo/heppyyier) workflow: spin up a
venv, install heppyyier, build HEP packages, analyse.

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
--packages-dir PATH          set HEPPYYIER_PACKAGES_DIR in the activated shell
--system-packages-dir PATH   set HEPPYYIER_SYSTEM_PACKAGES_DIR (read-only shared base)
--run CMD ...                run CMD inside the env (no interactive subshell)
--update                     self-update henv from GitHub
--install                    install henv to ~/.local/bin
--print-activate             emit shell commands for eval (parent-shell activation)
--list                       list envs under $HOME/.henvs/
--delete                     delete the resolved env
--no-heppyyier               skip heppyyier install prompt on first creation
--yes / -y                   non-interactive; auto-answer yes to all prompts
--version                    print version
-h / --help                  usage
```

---

## Typical session

```bash
# Create a project-local env, install heppyyier, drop into it
cd ~/myanalysis
henv .
# → creates .venv, asks about heppyyier, activates subshell
# → PS1 shows: (henv:myanalysis) ...

heyy install fastjet hepmc3 pythia8   # inside the subshell
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

## heppyyier integration

On first creation, `henv` prompts:
```
[henv] Install heppyyier (provides 'heyy install fastjet ...')? [Y/n]
```

Answering yes installs `heppyyier` (tries PyPI first, falls back to GitHub) and runs
`heyy init` to set up the recipe cache and package store inside the new venv.
The cppyy backend is automatically patched if it has broken library paths.

Skip with `--no-heppyyier`:
```bash
henv . --no-heppyyier
```

Every time you enter the subshell or use `--run`, if `heyy` is present:
- TCL modulefiles are regenerated for all installed packages (`heyy generate-modules`)
- If a `module` command (Lmod / Environment Modules) is available, the modulefiles
  directory is registered with `module use` so `module load fastjet/3.5.1` works

Additionally in the interactive subshell:
- Tab completion for `heyy` / `her` / `heppyyier` is enabled

---

## Running commands

`--run` performs the same full initialization as the interactive subshell: sources
the shell rc (for `module` function availability), activates the venv, sets
`HEPPYYIER_PACKAGES_DIR` / `HEPPYYIER_SYSTEM_PACKAGES_DIR`, regenerates TCL modulefiles,
and registers the modulefiles directory with `module use`. Module commands therefore
work as expected inside `--run`:

```bash
# Run a script in the env without entering a subshell
henv . --run python analysis.py

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
henv --name old-env --delete   # delete an env (prompts for confirmation)
henv --name old-env --delete --yes   # skip prompt
```

---

## Self-update

```bash
henv --update
```

Downloads the latest script from GitHub and replaces the current installation.
Works for curl-installed copies. If you installed from a git clone, use
`git pull` in the repo directory instead.

---

## Package sharing on HPC / shared filesystems

`henv` can set `HEPPYYIER_PACKAGES_DIR` and `HEPPYYIER_SYSTEM_PACKAGES_DIR`
automatically so the activated shell knows where heppyyier's package store lives.

### Flags

```
--packages-dir PATH        set HEPPYYIER_PACKAGES_DIR (your writable package store)
--system-packages-dir PATH set HEPPYYIER_SYSTEM_PACKAGES_DIR (read-only shared base)
```

### Auto-detection from `.heppyyier.toml`

If a `.heppyyier.toml` file exists in the current directory, `henv` reads it:

```toml
# .heppyyier.toml
packages_dir        = "~/.heppyyier_packages"
system_packages_dir = "/shared/hep/packages"
```

Flags take precedence over the TOML file.

### Workflows

**Single user, custom packages dir:**
```bash
henv --packages-dir /scratch/$USER/hep_packages .
# → HEPPYYIER_PACKAGES_DIR=/scratch/$USER/hep_packages in the subshell
```

**Admin builds once, users share (read-only):**
```bash
# Admin (once):
export HEPPYYIER_PACKAGES_DIR=/shared/hep/packages
heyy install fastjet hepmc3 pythia8 cppyy --force

# Each user (no compilation):
henv --packages-dir ~/.heppyyier --system-packages-dir /shared/hep/packages .
# Inside subshell:
#   HEPPYYIER_PACKAGES_DIR        = ~/.heppyyier       (writable — your own packages)
#   HEPPYYIER_SYSTEM_PACKAGES_DIR = /shared/hep/packages (read-only — admin packages)
#
# heyy list         shows both shared and personal packages
# heyy install pkg  installs to ~/.heppyyier only
# import fastjet    resolves from the shared prefix automatically
```

**Parent-shell activation with shared packages:**
```bash
eval "$(henv --system-packages-dir /shared/hep/packages --print-activate .)"
```

See [WORKFLOW-EXAMPLE.md](https://github.com/matplo/heppyyier/blob/main/WORKFLOW-EXAMPLE.md)
in the heppyyier repository for full step-by-step examples.

---

## Requirements

- bash 3.2+ (works with macOS system bash)
- Python 3.8+
- `curl` (for `--update` and `--install`)
- One of: `uv`, `virtualenv`, or `python3 -m venv` (stdlib)
