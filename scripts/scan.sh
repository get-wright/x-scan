#!/bin/sh
set -e

# Function to check if files match a pattern
check_files() {
    pattern=$1
    find /scan -type f -name "$pattern" 2>/dev/null | grep -q .
    return $?
}

# Function to run tool if relevant files exist
run_tool() {
    tool=$1
    patterns=$2
    
    # Check each pattern
    found=0
    for pattern in $patterns; do
        if check_files "$pattern"; then
            found=1
            break
        fi
    done
    
    if [ $found -eq 1 ]; then
        echo "Running $tool scan..."
        sh "/scripts/run-$tool.sh"
    else
        echo "No relevant files found for $tool scan"
    fi
}

# Parse command line arguments
TOOLS=""
while [ "$1" != "" ]; do
    case $1 in
        --tools)
            shift
            TOOLS=$1
            ;;
    esac
    shift
done

# If no tools specified, show usage
if [ -z "$TOOLS" ]; then
    echo "Usage: scan.sh --tools tool1,tool2,..."
    echo "Available tools: semgrep,gitleaks,trivy,checkov,kubescape"
    exit 1
fi

# Create reports directory
mkdir -p /reports

# Process each tool
echo "$TOOLS" | tr ',' '\n' | while read -r tool; do
    case $tool in
        "semgrep")
            run_tool "semgrep" "*.py *.js *.java *.go *.cpp *.c *.cs *.php *.rb *.ts"
            ;;
        "gitleaks")
            run_tool "gitleaks" "*"
            ;;
        "trivy")
            run_tool "trivy" "Dockerfile* *.yaml *.yml package*.json requirements.txt"
            ;;
        "checkov")
            run_tool "checkov" "*.tf *.yaml *.yml Dockerfile* .dockerignore package.json"
            ;;
        "kubescape")
            run_tool "kubescape" "*.yaml *.yml"
            ;;
        *)
            echo "Unknown tool: $tool"
            ;;
    esac
done