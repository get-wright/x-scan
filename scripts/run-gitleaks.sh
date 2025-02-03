#!/bin/sh
set -e

# Initialize empty report
echo "[]" > /reports/gitleaks-report.json

# Check if directory is a git repository
if [ -d "/scan/.git" ]; then
    echo "Scanning git repository..."
    gitleaks detect \
        --source="/scan" \
        --report-format=json \
        --report-path=/reports/gitleaks-report.json
else
    echo "Not a git repository. Performing filesystem scan..."
    cd /scan
    gitleaks detect \
        --source="." \
        --no-git \
        --verbose \
        --report-format=json \
        --report-path=/reports/gitleaks-report.json || true
fi