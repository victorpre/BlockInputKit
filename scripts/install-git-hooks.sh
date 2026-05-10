#!/bin/sh
set -eu

repo_root=$(git rev-parse --show-toplevel)
hooks_path="$repo_root/.githooks"

mkdir -p "$hooks_path"
git config core.hooksPath .githooks

echo "Git hooks path set to .githooks"
