#!/usr/bin/env bash
set -euo pipefail

scripts=(
  ansible_install.sh
  gitlab-install.sh
  mongodb_install.sh
  mysql84_install.sh
  postgresql18_install.sh
  redis_install.sh
)

for script in "${scripts[@]}"; do
  echo "Checking bash syntax: ${script}"
  # Normalize possible CRLF line endings for syntax check without mutating source files.
  bash -n <(tr -d '\r' < "${script}")
done

echo "All script syntax checks passed."
