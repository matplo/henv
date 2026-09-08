#!/usr/bin/env bash
# smoke.sh — dependency-free functional smoke test for henv.
#
# Runs against a fake $HOME so it never touches the real ~/.henvs, and uses
# --no-hepyy throughout so it stays fast/hermetic (no network calls) — henv
# installs cppyy + hepyy by default otherwise.
#
# Usage: bash test/smoke.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HENV="$SCRIPT_DIR/../henv"

export HOME
HOME="$(mktemp -d)"
trap 'rm -rf "$HOME"' EXIT

PASS=0
FAIL=0

ok()   { PASS=$((PASS + 1)); echo "PASS: $1"; }
bad()  { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }

# assert_success DESC CMD...
assert_success() {
    local desc="$1"; shift
    if "$@" >/tmp/smoke_out.$$ 2>&1; then
        ok "$desc"
    else
        bad "$desc"
        # shellcheck disable=SC2001 # indenting multi-line output; ${//} can't do this per-line
        sed 's/^/    /' /tmp/smoke_out.$$
    fi
    rm -f /tmp/smoke_out.$$
}

# assert_failure DESC CMD...
assert_failure() {
    local desc="$1"; shift
    if "$@" >/tmp/smoke_out.$$ 2>&1; then
        bad "$desc (expected failure, got success)"
    else
        ok "$desc"
    fi
    rm -f /tmp/smoke_out.$$
}

# assert_contains DESC NEEDLE CMD...
assert_contains() {
    local desc="$1" needle="$2"; shift 2
    local out
    out="$("$@" 2>&1)"
    if echo "$out" | grep -qF -- "$needle"; then
        ok "$desc"
    else
        bad "$desc (expected to contain '$needle')"
        # shellcheck disable=SC2001 # indenting multi-line output; ${//} can't do this per-line
        echo "$out" | sed 's/^/    /'
    fi
}

echo "=== henv smoke test (HOME=$HOME) ==="

assert_success  "--version exits 0"              bash "$HENV" --version
assert_success  "--help exits 0"                 bash "$HENV" --help

assert_contains "-x/--run print expected output" "hello" \
    bash "$HENV" --name citest --no-hepyy --run echo hello
if [ -f "$HOME/.henvs/citest/bin/activate" ]; then
    ok "env created at expected path"
else
    bad "env created at expected path"
fi
if [ ! -e "$HOME/.henvs/citest/bin/heyy" ]; then
    ok "--no-hepyy skips installing cppyy/hepyy"
else
    bad "--no-hepyy skips installing cppyy/hepyy"
fi

assert_contains "--nh is a short alias for --no-hepyy" "hi" \
    bash "$HENV" --name citest2 --nh --run echo hi
if [ ! -e "$HOME/.henvs/citest2/bin/heyy" ]; then
    ok "--nh skips installing cppyy/hepyy"
else
    bad "--nh skips installing cppyy/hepyy"
fi
bash "$HENV" --name citest2 --delete --yes >/dev/null 2>&1

assert_contains "existing env activates + runs (--run)" "hello2" \
    bash "$HENV" --name citest --run echo hello2
assert_contains "existing env activates + runs (-x alias)" "hello3" \
    bash "$HENV" --name citest -x echo hello3

assert_contains "--recreate rebuilds the env" "Recreating env" \
    bash "$HENV" --name citest --recreate --no-hepyy --run true

assert_contains "--list shows the env" "citest" \
    bash "$HENV" --list
assert_contains "--list --json shows the env" '"citest"' \
    bash "$HENV" --list --json

assert_contains "--info reports the env" "name    : citest" \
    bash "$HENV" --name citest --info

assert_contains "--fix-cppyy no-ops without a detected system cppyy" "nothing to fix" \
    bash "$HENV" --name citest --fix-cppyy
assert_contains "--fix-cppyy --no-cppyy forces removal" "Removing binary cppyy wheel" \
    bash "$HENV" --name citest --fix-cppyy --no-cppyy

assert_contains "-n is a short alias for --name" "hi4" \
    bash "$HENV" -n citest --run echo hi4

# --- Name registry: henv . registers a name; --name resolves it from anywhere ---

mkdir -p "$HOME/proj/regtest" "$HOME/proj2/regtest" "$HOME/newloc"

(cd "$HOME/proj/regtest" && bash "$HENV" . --no-hepyy -y --run true) \
    >/tmp/smoke_out.$$ 2>&1
if [ -f "$HOME/proj/regtest/.venv/bin/activate" ]; then
    ok "henv . creates a local env and registers it"
else
    bad "henv . creates a local env and registers it"
    # shellcheck disable=SC2001 # indenting multi-line output; ${//} can't do this per-line
    sed 's/^/    /' /tmp/smoke_out.$$
fi
rm -f /tmp/smoke_out.$$

assert_contains "--name resolves a registered local env from elsewhere" \
    "$HOME/proj/regtest/.venv" \
    bash "$HENV" --name regtest --info

out="$(cd "$HOME/proj2/regtest" && bash "$HENV" . --no-hepyy -y --run true 2>&1)"
if echo "$out" | grep -qF "already registered"; then
    ok "a colliding derived name is refused"
else
    bad "a colliding derived name is refused"
    # shellcheck disable=SC2001 # indenting multi-line output; ${//} can't do this per-line
    echo "$out" | sed 's/^/    /'
fi
if [ ! -e "$HOME/proj2/regtest/.venv" ]; then
    ok "the refused collision created nothing"
else
    bad "the refused collision created nothing"
fi

# --- --mv: recreate-in-place + registry update ---

assert_success "--mv recreates the env at the new path" \
    bash "$HENV" --name regtest --mv "$HOME/newloc/regtest-env" --yes --no-hepyy
if [ -f "$HOME/newloc/regtest-env/bin/activate" ] && [ ! -d "$HOME/proj/regtest/.venv" ]; then
    ok "--mv relocates the env and removes the old path"
else
    bad "--mv relocates the env and removes the old path"
fi
assert_contains "--name resolves through the registry after --mv" \
    "$HOME/newloc/regtest-env" \
    bash "$HENV" --name regtest --info
bash "$HENV" --name regtest --delete --yes >/dev/null 2>&1

# Bare 'henv' (no --name, no location) must also resolve through the
# registry for "default" — regression test for a bug where it always
# hardcoded $HOME/.henvs/default and ignored a --mv'd (or hand-edited)
# registry entry pointing elsewhere.
bash "$HENV" --no-hepyy -y --run true >/dev/null 2>&1
assert_success "bare henv --mv relocates the default env" \
    bash "$HENV" --mv "$HOME/newloc/default-env" --yes --no-hepyy
assert_contains "bare henv resolves the moved default env" \
    "$HOME/newloc/default-env" \
    bash "$HENV" --info

# --quiet suppresses [henv] info banners
out="$(bash "$HENV" --name citest -q --run true 2>&1)"
if [ -z "$out" ]; then
    ok "--quiet suppresses info banners"
else
    bad "--quiet suppresses info banners"
    # shellcheck disable=SC2001 # indenting multi-line output; ${//} can't do this per-line
    echo "$out" | sed 's/^/    /'
fi

# --name path traversal must be rejected before any path is ever built, so
# nothing gets created at the resolved (escaping) location.
assert_failure "--name rejects path traversal" \
    bash "$HENV" --name ../evil --run true
if [ -e "$HOME/evil" ] || [ -e "$HOME/.henvs/../evil" ]; then
    bad "path traversal did not create anything"
else
    ok "path traversal did not create anything"
fi

assert_success "--delete removes the env" \
    bash "$HENV" --name citest --delete --yes
if [ ! -d "$HOME/.henvs/citest" ]; then
    ok "env directory gone after --delete"
else
    bad "env directory gone after --delete"
fi
if ! grep -qF '"citest"' "$HOME/.henvs/registry.json" 2>/dev/null; then
    ok "registry entry removed after --delete"
else
    bad "registry entry removed after --delete"
fi

# --- EXTRA_CLING_ARGS / CC / CXX auto-detection ---
# The one non-hermetic test in this suite: it needs a real cppyy+hepyy
# install (no --no-hepyy) so heyy is present and the auto-detect gate
# fires. Verifies the opposite behavior on each OS: non-empty (and, for
# CC/CXX, pointed at gcc/g++ specifically) on Linux, left completely unset
# everywhere else.
assert_success "create an env with cppyy+hepyy for the EXTRA_CLING_ARGS check" \
    bash "$HENV" --name clingtest -y --run true

cling_env_out="$(bash "$HENV" --name clingtest --run env 2>&1)"
if [ "$(uname -s)" = "Linux" ]; then
    if echo "$cling_env_out" | grep -q '^EXTRA_CLING_ARGS=.*-isystem'; then
        ok "EXTRA_CLING_ARGS is auto-detected on Linux when heyy is present"
    else
        bad "EXTRA_CLING_ARGS is auto-detected on Linux when heyy is present"
        # shellcheck disable=SC2001 # indenting multi-line output; ${//} can't do this per-line
        echo "$cling_env_out" | sed 's/^/    /'
    fi
    if echo "$cling_env_out" | grep -q '^CC=.*gcc' && echo "$cling_env_out" | grep -q '^CXX=.*g++'; then
        ok "CC/CXX are auto-detected on Linux, pointed at gcc/g++"
    else
        bad "CC/CXX are auto-detected on Linux, pointed at gcc/g++"
        # shellcheck disable=SC2001 # indenting multi-line output; ${//} can't do this per-line
        echo "$cling_env_out" | sed 's/^/    /'
    fi
else
    if ! echo "$cling_env_out" | grep -qE '^(EXTRA_CLING_ARGS|CC|CXX)='; then
        ok "EXTRA_CLING_ARGS/CC/CXX stay unset on non-Linux"
    else
        bad "EXTRA_CLING_ARGS/CC/CXX stay unset on non-Linux"
        # shellcheck disable=SC2001 # indenting multi-line output; ${//} can't do this per-line
        echo "$cling_env_out" | sed 's/^/    /'
    fi
fi
bash "$HENV" --name clingtest --delete --yes >/dev/null 2>&1

echo "=== $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
