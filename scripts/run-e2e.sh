#!/usr/bin/env bash
# End-to-end keymap tests for markdown-plus.
#
# Drives real keypresses through the plugin's real buffer-local keymaps in a Neovim that
# knows nothing about the developer's setup, and asserts exact buffer contents. Unlike the
# busted suite (`make test`) this exercises keymap registration and dispatch, so it catches
# breakage that unit-level specs cannot see.
#
# Isolation, in order of importance:
#   - `-u test/e2e/init.lua`  : the only config loaded; never ~/.config/nvim
#   - fresh XDG_* temp dirs   : no shada/state/cache from the real Neovim can leak in
#   - `--clean`               : skips user runtime directories entirely
# test/e2e/init.lua additionally aborts the run if a personal config appears on the
# runtimepath, so an isolation regression fails loudly instead of quietly tainting results.
#
# Usage:
#   scripts/run-e2e.sh              # run all cases, clean up temp dirs
#   scripts/run-e2e.sh --keep-tmp   # keep temp dirs for debugging (path is printed)
#
# Exit codes: 0 = all cases passed, 1 = at least one failed, 2 = isolation failure.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEEP_TMP=0
[ "${1:-}" = "--keep-tmp" ] && KEEP_TMP=1

command -v nvim >/dev/null 2>&1 || { echo "Error: 'nvim' not found in PATH"; exit 1; }

# Every piece of Neovim state points somewhere disposable.
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/markdown-plus-e2e.XXXXXX")"
export XDG_CONFIG_HOME="$TMP_ROOT/config"
export XDG_DATA_HOME="$TMP_ROOT/data"
export XDG_STATE_HOME="$TMP_ROOT/state"
export XDG_CACHE_HOME="$TMP_ROOT/cache"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME"

# The isolated init resolves the plugin from here rather than from the cwd, so the runner
# works no matter where it is invoked from.
export MARKDOWN_PLUS_ROOT="$REPO_ROOT"

LOG_DIR="$REPO_ROOT/test/e2e/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/run.log"

cleanup() {
  if [ "$KEEP_TMP" -eq 1 ]; then
    echo "Temp dirs kept at: $TMP_ROOT"
  else
    rm -rf "$TMP_ROOT"
  fi
}
trap cleanup EXIT

nvim --clean --headless -u "$REPO_ROOT/test/e2e/init.lua" \
  -l "$REPO_ROOT/test/e2e/runner.lua" 2>&1 | tee "$LOG_FILE"

STATUS=${PIPESTATUS[0]}

echo
case "$STATUS" in
  0) echo "All end-to-end cases passed. Log: $LOG_FILE" ;;
  2) echo "Isolation failure: a personal config reached the runtimepath. Log: $LOG_FILE" ;;
  *) echo "End-to-end failures above. Full log: $LOG_FILE" ;;
esac

exit "$STATUS"
