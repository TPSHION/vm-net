#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData/vm-net-fljkabdsafgpqcbpzilrjhgptmpy"
APP_PATH="$DERIVED_DATA/Build/Products/Debug/vm-net.app"
PROCESS_NAME="vm-net"

kill_running_app() {
  pkill -x "$PROCESS_NAME" 2>/dev/null || true
}

build_app() {
  xcodebuild \
    -project "$ROOT_DIR/vm-net.xcodeproj" \
    -scheme "vm-net" \
    -configuration Debug \
    CODE_SIGNING_ALLOWED=NO \
    build
}

run_app() {
  /usr/bin/open -n "$APP_PATH"
}

verify_running() {
  pgrep -x "$PROCESS_NAME" >/dev/null
}

kill_running_app
build_app
run_app

if [[ "${1:-}" == "--verify" ]]; then
  sleep 1
  verify_running
fi
