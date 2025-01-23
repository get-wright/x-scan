#!/bin/sh
set -e

gitleaks detect \
  --source="/scan" \
  --report-format=json \
  --report-path=/reports/gitleaks-report.json \