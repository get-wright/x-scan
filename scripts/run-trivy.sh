#!/bin/sh
set -e

trivy filesystem /scan \
  --format json \
  --output /reports/trivy-report.json \
  --scanners ${TRIVY_SCANNERS} \
  --severity ${TRIVY_SEVERITY} \
  --skip-dirs reports \
  --skip-files "*.json" \
  --cache-dir /root/.cache