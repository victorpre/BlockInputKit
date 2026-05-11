#!/bin/bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

demo_process_pattern='(^|/)BlockInputKitDemo([[:space:]]|$)'
demo_binary="$repo_root/.build/xcode/Build/Products/Debug/BlockInputKitDemo"
demo_log="${TMPDIR:-/tmp}/blockinputkit-demo.log"

run_and_format() {
  if command -v xcsift >/dev/null 2>&1; then
    "$@" 2>&1 | xcsift -f toon -w
  else
    "$@"
  fi
}

stop_existing_demo() {
  local pids
  pids=$(pgrep -f "$demo_process_pattern" || true)
  if [ -z "$pids" ]; then
    return
  fi

  echo "Stopping existing BlockInputKitDemo process(es): ${pids//$'\n'/ }"
  kill $pids 2>/dev/null || true

  for _ in {1..20}; do
    pids=$(pgrep -f "$demo_process_pattern" || true)
    if [ -z "$pids" ]; then
      return
    fi
    sleep 0.1
  done

  echo "Force stopping existing BlockInputKitDemo process(es): ${pids//$'\n'/ }"
  kill -9 $pids 2>/dev/null || true
}

stop_existing_demo

run_and_format xcodebuild \
  -scheme BlockInputKitDemo \
  -destination 'platform=macOS' \
  -derivedDataPath .build/xcode \
  build

nohup "$demo_binary" "$@" >"$demo_log" 2>&1 &
echo "Started BlockInputKitDemo (pid $!). Log: $demo_log"
