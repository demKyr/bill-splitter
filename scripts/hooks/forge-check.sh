#!/usr/bin/env bash
# Agent hook: after the agent edits a Solidity file, format and build the contracts.
# Exit code 2 sends the build errors back to the agent, so it fixes them before it continues.
# docs/AGENT_SETUP.md says how to register it with your agent.
#
# The agent passes a JSON description of the edit on standard input.
# Skip the check when that description names no .sol file (for example a web app edit).
input="$(cat)"
if [ -n "$input" ] && ! printf '%s' "$input" | grep -q '\.sol'; then
  exit 0
fi

cd "$(dirname "$0")/../../contracts" || exit 0
# Evidence that the agent's program ran this hook: one line per run in .hooks.log.
log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) forge-check $1" >>../.hooks.log 2>/dev/null || true; }
if ! output=$({ forge fmt && forge build; } 2>&1); then
  log "FAILED the contracts do not build"
  echo "forge-check hook: the contracts do not build. Fix this before you continue." >&2
  echo "$output" | tail -40 >&2
  exit 2
fi
log "ok formatted and built"
