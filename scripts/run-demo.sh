#!/bin/bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

demo_process_pattern='(^|/)BlockInputKitDemo([[:space:]]|$)'
demo_binary="$repo_root/.build/xcode/Build/Products/Debug/BlockInputKitDemo"
demo_log="${TMPDIR:-/tmp}/blockinputkit-demo.log"
demo_launch_label="com.blockinputkit.demo"

run_and_format() {
  if command -v xcsift >/dev/null 2>&1; then
    "$@" 2>&1 | xcsift -f toon -w
  else
    "$@"
  fi
}

remove_demo_launch_jobs() {
  local labels
  labels=$(launchctl print "gui/$(id -u)" 2>/dev/null | awk '/com\.blockinputkit\.demo/ { print $3 }' || true)
  for label in $labels; do
    launchctl remove "$label" >/dev/null 2>&1 || true
  done
}

stop_existing_demo() {
  local pids
  pids=$(pgrep -f "$demo_process_pattern" || true)
  if [ -z "$pids" ]; then
    remove_demo_launch_jobs
    return
  fi

  echo "Stopping existing BlockInputKitDemo process(es): ${pids//$'\n'/ }"
  kill $pids 2>/dev/null || true

  for _ in {1..20}; do
    pids=$(pgrep -f "$demo_process_pattern" || true)
    if [ -z "$pids" ]; then
      remove_demo_launch_jobs
      return
    fi
    sleep 0.1
  done

  echo "Force stopping existing BlockInputKitDemo process(es): ${pids//$'\n'/ }"
  kill -9 $pids 2>/dev/null || true
  remove_demo_launch_jobs
}

stop_existing_demo

run_and_format xcodebuild \
  -scheme BlockInputKitDemo \
  -destination 'platform=macOS' \
  -derivedDataPath .build/xcode \
  build

launchctl submit -l "$demo_launch_label" -o "$demo_log" -e "$demo_log" -- "$demo_binary" "$@"
sleep 0.5

pids=$(pgrep -f "$demo_process_pattern" || true)
if [ -z "$pids" ]; then
  echo "Failed to start BlockInputKitDemo"
  if [ -s "$demo_log" ]; then
    tail -40 "$demo_log"
  fi
  exit 1
fi

echo "Started BlockInputKitDemo (pid(s): ${pids//$'\n'/ }). Log: $demo_log"
