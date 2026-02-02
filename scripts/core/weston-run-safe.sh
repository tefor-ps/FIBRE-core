#!/usr/bin/env bash
#
# weston-run-safe.sh
#
# Safe, headless Weston launcher intended as a replacement for xvfb-run-safe.sh
#
# Supports:
#   - Wayland-native apps
#   - X11 apps via Xwayland
#   - Java / Fiji / ImageJ (AWT/Swing)
#
# Requirements:
#   - weston >= 10
#   - xwayland
#   - xdpyinfo (x11-utils)
#
# Usage:
#   ./weston-run-safe.sh <command> [args...]
#

set -euo pipefail

# --------------------------------------------------------------------
# Configuration (override via environment if needed)
# --------------------------------------------------------------------

WESTON_BIN="${WESTON_BIN:-weston}"
WESTON_BACKEND="headless-backend.so"
RUNTIME_BASE=$(mktemp -d)
SESSION_ID="weston-$$"
XDG_RUNTIME_DIR="$RUNTIME_BASE/$SESSION_ID"
WAYLAND_DISPLAY="wayland-0"

LOG_FILE="$RUNTIME_BASE/weston-$SESSION_ID.log"
STARTUP_TIMEOUT=5   # seconds

# --------------------------------------------------------------------
# Cleanup handler
# --------------------------------------------------------------------

cleanup() {
  if [[ -n "${WESTON_PID:-}" ]] && kill -0 "$WESTON_PID" 2>/dev/null; then
    kill "$WESTON_PID" 2>/dev/null || true
    wait "$WESTON_PID" 2>/dev/null || true
  fi
  rm -rf "$XDG_RUNTIME_DIR"
}
trap cleanup EXIT INT TERM

# --------------------------------------------------------------------
# Sanity checks
# --------------------------------------------------------------------

command -v "$WESTON_BIN" >/dev/null \
  || { echo "weston not found"; exit 1; }

command -v xdpyinfo >/dev/null \
  || { echo "xdpyinfo not found (install x11-utils)"; exit 1; }

  # --------------------------------------------------------------------
# Prepare isolated runtime directory
# --------------------------------------------------------------------

mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

export XDG_RUNTIME_DIR
export WAYLAND_DISPLAY

# Prevent fallback to the real desktop
unset DISPLAY
unset WAYLAND_SOCKET 2>/dev/null || true

# --------------------------------------------------------------------
# Start Weston (headless + Xwayland)
# --------------------------------------------------------------------

"$WESTON_BIN" \
  --backend="$WESTON_BACKEND" \
  --socket="$WAYLAND_DISPLAY" \
  --xwayland \
  --idle-time=0 \
  >"$LOG_FILE" 2>&1 &

WESTON_PID=$!

# --------------------------------------------------------------------
# Wait for Wayland socket
# --------------------------------------------------------------------

deadline=$((SECONDS + STARTUP_TIMEOUT))
while [[ ! -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]]; do
  [[ $SECONDS -ge $deadline ]] && break
  sleep 0.05
done

if [[ ! -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]]; then
  echo "Weston failed to create Wayland socket"
  cat "$LOG_FILE" >&2
  exit 1
fi

# --------------------------------------------------------------------
# Detect Xwayland DISPLAY (dynamic!)
# --------------------------------------------------------------------

DISPLAY=""
deadline=$((SECONDS + STARTUP_TIMEOUT))

while [[ -z "$DISPLAY" ]]; do
  DISPLAY_NUM=$(grep -oE 'xserver listening on display :[0-9]+' \
    "$LOG_FILE" | tail -1 | sed 's/.*://')

  if [[ -n "$DISPLAY_NUM" ]] && xdpyinfo -display ":$DISPLAY_NUM" >/dev/null 2>&1; then
    DISPLAY=":$DISPLAY_NUM"
    export DISPLAY
    break
  fi

  [[ $SECONDS -ge $deadline ]] && break
  sleep 0.05
done

if [[ -z "$DISPLAY" ]]; then
  echo "Xwayland failed to start"
  cat "$LOG_FILE" >&2
  exit 1
fi

# --------------------------------------------------------------------
# Environment hardening for problematic toolkits (Fiji-safe)
# --------------------------------------------------------------------

# Java / AWT / Swing
export _JAVA_AWT_WM_NONREPARENTING=1
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} -Dsun.java2d.opengl=false"

# GTK / Qt safety
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb

# Prevent accidental Wayland use
unset MOZ_ENABLE_WAYLAND 2>/dev/null || true

# --------------------------------------------------------------------
# Execute target command
# --------------------------------------------------------------------

echo "$@"
$@