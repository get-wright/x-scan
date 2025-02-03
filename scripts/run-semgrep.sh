#!/bin/sh
set -e

# Create a temporary directory for valid rules
TEMP_RULES_DIR="/tmp/valid_rules"
mkdir -p "$TEMP_RULES_DIR"

# Function to validate and copy Semgrep rule files
process_rules() {
    local source_dir="$1"
    local target_dir="$2"
    
    find "$source_dir" -type f \( -name "*.yaml" -o -name "*.yml" \) | while read -r file; do
        if echo "$file" | grep -qE '(/\.|\.pre-commit|\.github/|\.gitlab/|\.circleci/)'; then
            continue
        fi
        
        if grep -q "rules:" "$file" && grep -qE "pattern:|patterns:" "$file"; then
            rel_dir=$(dirname "$file" | sed "s|^$source_dir||")
            mkdir -p "$target_dir$rel_dir"
            cp "$file" "$target_dir$rel_dir/"
        fi
    done
}

# Process rules from mounted directory
process_rules "/rules" "$TEMP_RULES_DIR"

# Check if we found any valid rules
if [ -z "$(find "$TEMP_RULES_DIR" -type f \( -name "*.yml" -o -name "*.yaml" \))" ]; then
    echo "Warning: No valid Semgrep rules found in the rules directory"
    echo "Rules should be YAML files containing 'rules:' and 'pattern:' or 'patterns:' sections"
    exit 1
fi

mkdir -p /reports

# Run semgrep and save raw output
semgrep --disable-version-check \
        --max-target-bytes=2000000 \
        --timeout=0 \
        --config="$TEMP_RULES_DIR" \
        . \
        --json \
        > /tmp/semgrep_raw.json || true

# Process and normalize the output using jq
jq '
{
  version: .version,
  findings: [.results[] | {
    # Extract rule category from checkId
    category: (
      if (.check_id | contains(".")) then
        (.check_id | split(".")[2:-1] | join("."))
      else
        "undefined"
      end
    ),
    rule: {
      id: .check_id,
      # Extract last part of checkId as name
      name: (.check_id | split(".")[-1])
    },
    file: {
      path: .path,
      location: {
        start: "\(.start.line):\(.start.col)",
        end: "\(.end.line):\(.end.col)"
      }
    },
    issue: {
      severity: .extra.severity,
      message: .extra.message,
      # Clean up code display
      code: (.extra.lines | gsub("\\t"; "  ")),
      ignored: .extra.is_ignored
    },
    # Add rule metadata if available
    metadata: (.extra.metadata // {})
  }],
  errors: [.errors[] | {
    type: .type,
    message: .message,
    # Include rule id if available
    ruleId: (.rule_id // null)
  }],
  stats: {
    findings: {
      total: (.results | length),
      byCategory: (
        .results | group_by(
          if (.check_id | contains(".")) then
            (.check_id | split(".")[2:-1] | join("."))
          else
            "undefined"
          end
        ) | map({
          key: .[0].check_id | split(".")[2:-1] | join("."),
          value: length
        }) | from_entries
      ),
      bySeverity: (
        .results | group_by(.extra.severity) | map({
          key: .[0].extra.severity,
          value: length
        }) | from_entries
      )
    },
    errors: {
      total: (.errors | length),
      byType: (
        .errors | group_by(.type) | map({
          key: .[0].type,
          value: length
        }) | from_entries
      )
    },
    scannedFiles: (.paths.scanned | length)
  }
}' /tmp/semgrep_raw.json > /reports/semgrep-report.json

# Cleanup
rm -rf "$TEMP_RULES_DIR" /tmp/semgrep_raw.json