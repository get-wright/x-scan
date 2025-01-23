#!/bin/sh
set -e

mkdir -p /reports
kubescape scan /scan \
  --format json \
  --format-version v2 \
  --output /reports/kubescape-report.json