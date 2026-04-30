#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

submodules=(
  "sysmind-ui|git@github.com:bijuvarghese/sysmind-ui.git"
  "sysmind-mcp|git@github.com:bijuvarghese/sysmind-mcp.git"
)

is_git_work_tree=false
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  is_git_work_tree=true
fi

if [[ "$is_git_work_tree" == "true" && -f .gitmodules ]]; then
  echo "Initializing Git submodules..."
  git submodule sync --recursive
  git submodule update --init --recursive
fi

for submodule in "${submodules[@]}"; do
  IFS="|" read -r path url <<< "$submodule"

  if [[ -d "$path/.git" || -f "$path/.git" ]]; then
    echo "Submodule '$path' is already present."
    continue
  fi

  if [[ -d "$path" && -n "$(find "$path" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
    echo "Directory '$path' exists but is not a Git checkout. Please move it aside or clone the submodule manually." >&2
    exit 1
  fi

  echo "Cloning missing submodule '$path'..."
  rm -rf "$path"
  git clone "$url" "$path"
done

echo "Submodules are ready."
