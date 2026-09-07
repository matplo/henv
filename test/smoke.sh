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

echo "=== $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
