#!/bin/sh
set -e

checkov -d /scan --output json > /reports/checkov-report.json