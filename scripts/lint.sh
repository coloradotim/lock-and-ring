#!/usr/bin/env bash
set -euo pipefail

if command -v swiftlint >/dev/null 2>&1; then
  mkdir -p .build/swiftlint-cache
  swiftlint lint --strict --cache-path .build/swiftlint-cache
  exit 0
fi

echo "swiftlint is not installed; running fallback lint checks."

git diff --check

status=0
while IFS= read -r file; do
  while IFS=: read -r line length; do
    if [ "$length" -gt 120 ]; then
      echo "$file:$line: fallback line length violation: $length > 120"
      status=1
    fi
  done < <(awk '{ print NR ":" length($0) }' "$file")
done < <(find LockAndRing LockAndRingTests -name '*.swift' -print)

app_view_model_lines=$(
  awk '
    /final class AppViewModel/ { in_type = 1 }
    in_type && $0 !~ /^[[:space:]]*\/\// && $0 !~ /^[[:space:]]*$/ { count += 1 }
    END { print count + 0 }
  ' LockAndRing/App/AppViewModel.swift
)

if [ "$app_view_model_lines" -gt 300 ]; then
  echo "LockAndRing/App/AppViewModel.swift: fallback type body length violation: $app_view_model_lines > 300"
  status=1
fi

exit "$status"
