#!/bin/sh
set -e

while IFS="," read -r repo dir || [ -n "$repo" ]; do
  if [ ! -d "/rules/$dir" ]; then 
    cd /rules && git clone "$repo" "$dir"
  fi
done < /rules/rules.txt

CONFIG_PATHS=""
while IFS="," read -r _ dir || [ -n "$dir" ]; do
  CONFIG_PATHS="$CONFIG_PATHS --config=/rules/$dir/"
done < /rules/rules.txt

mkdir -p /reports
semgrep --disable-version-check \
        --max-target-bytes=2000000 \
        --timeout=0 \
        $CONFIG_PATHS . \
        --json \
        --output=/reports/semgrep-report.json || true