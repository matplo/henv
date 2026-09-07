#!/usr/bin/env bash
# smoke.sh — dependency-free functional smoke test for henv.
#
# Runs against a fake $HOME so it never touches the real ~/.henvs. henv no
# longer installs anything beyond the venv itself, so this stays hermetic
# (no network calls) without any extra flags.
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
    bash "$HENV" --name citest --run echo hello
if [ -f "$HOME/.henvs/citest/bin/activate" ]; then
    ok "env created at expected path"
else
    bad "env created at expected path"
fi

assert_contains "existing env activates + runs (--run)" "hello2" \
    bash "$HENV" --name citest --run echo hello2
assert_contains "existing env activates + runs (-x alias)" "hello3" \
    bash "$HENV" --name citest -x echo hello3

assert_contains "--recreate rebuilds the env" "Recreating env" \
    bash "$HENV" --name citest --recreate --run true

assert_contains "--list shows the env" "citest" \
    bash "$HENV" --list
assert_contains "--list --json shows the env" '"citest"' \
    bash "$HENV" --list --json

assert_contains "--info reports the env" "name    : citest" \
    bash "$HENV" --name citest --info

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
