#!/usr/bin/env bash
set -Eeuo pipefail

readonly ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly CHROME_BIN="/usr/bin/google-chrome-stable"
readonly DISPLAY_NUMBER="${BELHAVEN_DISPLAY_NUMBER:-99}"
readonly DISPLAY=":${DISPLAY_NUMBER}"
readonly VNC_PORT=5900
readonly WEB_PORT=6080
readonly CLIENT_ROOT="/usr/local/share/belhaven-project/client"
readonly CLIENT_LICENSE="/usr/local/share/belhaven-project/LICENSE.txt"
readonly PROFILE_DIR="$HOME/.local/share/belhaven-project/chrome-profile"
readonly DOWNLOADS_DIR="$HOME/BelhavenProject/Downloads"

RUNTIME_DIR=""
LOG_DIR=""
PUBLIC_ROOT=""
CHILD_PIDS=()
LAST_CHILD_PID=""

fail() {
  printf 'Belhaven Project: %s\n' "$*" >&2
  exit 1
}

show_log() {
  local name="$1"
  if [[ -f "$LOG_DIR/$name.log" ]]; then
    printf '\n--- %s log ---\n' "$name" >&2
    tail -n 25 "$LOG_DIR/$name.log" >&2 || true
  fi
}

cleanup() {
  local status=$?
  trap - EXIT INT TERM

  for pid in "${CHILD_PIDS[@]}"; do
    kill -TERM "$pid" 2>/dev/null || true
  done
  for pid in "${CHILD_PIDS[@]}"; do
    wait "$pid" 2>/dev/null || true
  done

  if [[ -n "$RUNTIME_DIR" ]]; then
    case "$RUNTIME_DIR" in
      "${TMPDIR:-/tmp}"/belhaven-project.*)
        rm -rf -- "$RUNTIME_DIR"
        ;;
      *)
        printf 'Belhaven Project: refusing to remove unexpected runtime path: %s\n' "$RUNTIME_DIR" >&2
        ;;
    esac
  fi

  return "$status"
}

start_child() {
  local name="$1"
  shift
  "$@" >"$LOG_DIR/$name.log" 2>&1 &
  LAST_CHILD_PID=$!
  CHILD_PIDS+=("$LAST_CHILD_PID")
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command '$1' is missing from the Codespaces image."
}

wait_for_display() {
  local attempt
  for ((attempt = 0; attempt < 50; attempt++)); do
    if ! kill -0 "$XVFB_PID" 2>/dev/null; then
      show_log xvfb
      fail "The virtual display stopped during startup."
    fi
    if xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
  done

  show_log xvfb
  fail "The virtual display did not become ready within 10 seconds."
}

wait_for_tcp() {
  local port="$1"
  python3 - "$port" <<'PY'
import socket
import sys
import time

port = int(sys.argv[1])
for _ in range(50):
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=0.2):
            raise SystemExit(0)
    except OSError:
        time.sleep(0.2)
raise SystemExit(1)
PY
}

require_command python3
require_command Xvfb
require_command fluxbox
require_command x11vnc
require_command websockify
require_command xdpyinfo
require_command curl
require_command tail

if [[ ! -x "$CHROME_BIN" ]]; then
  fail "Google Chrome Stable is missing at $CHROME_BIN. Rebuild the Codespaces image."
fi
if ! CHROME_VERSION="$("$CHROME_BIN" --version 2>&1)" || [[ ! "$CHROME_VERSION" =~ ^Google\ Chrome\  ]]; then
  fail "The installed executable is not Google Chrome Stable: $CHROME_VERSION"
fi
for required_path in "$ROOT_DIR/web/index.html" "$ROOT_DIR/web/desktop.js" "$ROOT_DIR/web/style.css" "$CLIENT_ROOT/core/rfb.js" "$CLIENT_LICENSE"; do
  [[ -f "$required_path" ]] || fail "A required project file is missing: $required_path"
done
for required_dir in "$CLIENT_ROOT/core" "$CLIENT_ROOT/vendor"; do
  [[ -d "$required_dir" ]] || fail "A required client asset directory is missing: $required_dir"
done
if [[ ! "$DISPLAY_NUMBER" =~ ^[0-9]+$ ]]; then
  fail "BELHAVEN_DISPLAY_NUMBER must contain only digits."
fi
if [[ -S "/tmp/.X11-unix/X$DISPLAY_NUMBER" ]]; then
  fail "Display $DISPLAY is already in use. Stop its owner or set BELHAVEN_DISPLAY_NUMBER."
fi
if ! python3 - "$VNC_PORT" "$WEB_PORT" <<'PY'
import socket
import sys

for value in sys.argv[1:]:
    port = int(value)
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server:
        try:
            server.bind(("0.0.0.0", port))
        except OSError:
            raise SystemExit(f"Port {port} is already in use")
PY
then
  fail "A required service port is already in use. Stop the existing service before restarting."
fi

mkdir -p "$PROFILE_DIR/Default" "$DOWNLOADS_DIR"
python3 - "$PROFILE_DIR/Default/Preferences" "$DOWNLOADS_DIR" <<'PY'
import json
import os
import sys
from pathlib import Path

preferences_path = Path(sys.argv[1])
download_directory = str(Path(sys.argv[2]).resolve())
try:
    preferences = json.loads(preferences_path.read_text(encoding="utf-8"))
except FileNotFoundError:
    preferences = {}
except json.JSONDecodeError as error:
    raise SystemExit(f"Chrome preferences are invalid at {preferences_path}: {error}")

download_preferences = preferences.setdefault("download", {})
download_preferences["default_directory"] = download_directory
download_preferences["directory_upgrade"] = True
download_preferences["prompt_for_download"] = False
temporary_path = preferences_path.with_name("Preferences.belhaven-tmp")
temporary_path.write_text(json.dumps(preferences, separators=(",", ":")), encoding="utf-8")
os.replace(temporary_path, preferences_path)
PY

RUNTIME_DIR="$(mktemp -d "${TMPDIR:-/tmp}/belhaven-project.XXXXXXXX")"
LOG_DIR="$RUNTIME_DIR/logs"
PUBLIC_ROOT="$RUNTIME_DIR/public"
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

mkdir -p "$LOG_DIR" "$PUBLIC_ROOT"
cp -a "$ROOT_DIR/web/." "$PUBLIC_ROOT/"
cp -a "$CLIENT_ROOT/core" "$CLIENT_ROOT/vendor" "$PUBLIC_ROOT/"
cp "$CLIENT_LICENSE" "$PUBLIC_ROOT/CLIENT-LICENSE.txt"

export DISPLAY
start_child xvfb Xvfb "$DISPLAY" -screen 0 1440x900x24 -nolisten tcp -noreset
XVFB_PID="$LAST_CHILD_PID"
wait_for_display

start_child window-manager fluxbox -display "$DISPLAY"
sleep 0.3
if ! kill -0 "$LAST_CHILD_PID" 2>/dev/null; then
  show_log window-manager
  fail "The window manager stopped during startup."
fi

start_child desktop-service x11vnc \
  -display "$DISPLAY" \
  -forever \
  -shared \
  -nopw \
  -listen 127.0.0.1 \
  -rfbport "$VNC_PORT" \
  -xkb \
  -noxdamage \
  -nosel \
  -noclipboard \
  -nosetclipboard
if ! wait_for_tcp "$VNC_PORT"; then
  show_log desktop-service
  fail "The internal desktop service did not become ready."
fi

start_child chrome "$CHROME_BIN" \
  --user-data-dir="$PROFILE_DIR" \
  --no-first-run \
  --no-default-browser-check \
  --disable-dev-shm-usage \
  --start-maximized \
  --window-size=1440,900
CHROME_PID="$LAST_CHILD_PID"
sleep 1
if ! kill -0 "$CHROME_PID" 2>/dev/null; then
  show_log chrome
  fail "Google Chrome Stable stopped during startup."
fi

start_child page-service websockify \
  --web "$PUBLIC_ROOT" \
  "0.0.0.0:${WEB_PORT}" \
  "127.0.0.1:${VNC_PORT}"
WEBSOCKIFY_PID="$LAST_CHILD_PID"

page_ready=false
for ((attempt = 0; attempt < 50; attempt++)); do
  if ! kill -0 "$WEBSOCKIFY_PID" 2>/dev/null; then
    show_log page-service
    fail "The single-port web service stopped during startup."
  fi
  if curl --fail --silent --max-time 1 "http://127.0.0.1:$WEB_PORT/" -o "$RUNTIME_DIR/health.html" 2>/dev/null \
    && grep -q '<title>Belhaven Project</title>' "$RUNTIME_DIR/health.html"; then
    page_ready=true
    break
  fi
  sleep 0.2
done
if [[ "$page_ready" != true ]]; then
  show_log page-service
  fail "The project page did not become ready on port $WEB_PORT."
fi

if ! python3 - "$WEB_PORT" <<'PY'
import base64
import os
import socket
import sys

port = int(sys.argv[1])
key = base64.b64encode(os.urandom(16)).decode("ascii")
request = (
    f"GET /websockify HTTP/1.1\r\n"
    f"Host: 127.0.0.1:{port}\r\n"
    "Upgrade: websocket\r\n"
    "Connection: Upgrade\r\n"
    f"Sec-WebSocket-Key: {key}\r\n"
    "Sec-WebSocket-Version: 13\r\n"
    "Sec-WebSocket-Protocol: binary\r\n"
    "\r\n"
)
with socket.create_connection(("127.0.0.1", port), timeout=3) as connection:
    connection.sendall(request.encode("ascii"))
    response = connection.recv(4096)
if not response.startswith(b"HTTP/1.1 101"):
    raise SystemExit("The display WebSocket did not upgrade through the page port")
PY
then
  show_log page-service
  fail "The display connection could not be opened through port $WEB_PORT."
fi

printf 'Google Chrome Stable is running in Belhaven Project.\n'
printf 'Open the forwarded port labeled Belhaven Project.\n'
printf 'Downloads are stored in %s. Press Ctrl+C here to stop the session.\n' "$DOWNLOADS_DIR"

if wait -n "${CHILD_PIDS[@]}"; then
  fail "A desktop process exited. Restart the session if you closed Chrome intentionally."
else
  status=$?
  show_log page-service
  show_log desktop-service
  show_log chrome
  fail "A desktop process failed with exit status $status."
fi

