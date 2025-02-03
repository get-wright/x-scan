# X-Scan Toolset

This project provides a containerized security scanning pipeline that runs multiple security analysis tools against your codebase.

## 🛡️ Included Scanners

- **Semgrep**: Static analysis for finding code patterns and security issues
- **Gitleaks**: Secret and credential scanning
- **Trivy**: Vulnerability and misconfiguration scanning
- **Checkov**: Infrastructure-as-Code security scanning
- **Kubescape**: Kubernetes security risk analysis

## ⚙️ Configuration

Configure the scanning environment in the 

.env

 file:

```env
SEMGREP_TOKEN=<your-semgrep-token>
SCAN_PATH=<path-to-code-to-scan>
RULES_PATH=<path-to-custom-rules>
TRIVY_SEVERITY=HIGH,CRITICAL
TRIVY_SCANNERS=vuln,misconfig,secret
```

## 🚀 Running Scans

1. Make sure you have Docker and Docker Compose installed

2. Start all scanners:
```bash
docker-compose up
```

## 📝 Custom Rules

The project includes two Semgrep rule repositories as Git submodules:
- 

semgrep-rules-modified

: Custom modified ruleset
- 

semgrep-rules-trail-of-bits

: Trail of Bits security rules

Initialize the rule submodules:
```bash
git submodule update --init
```

## 🔧 Advanced Configuration

Each scanner is configurable through environment variables and volume mounts in docker-compose.yml. The scan scripts in scripts folder.

## 🏗️ Project Structure

```
.
├── .env                   # Environment configuration
├── docker-compose.yml     # Container orchestration
├── reports/               # Scan results
├── rules/                 # Custom scanner rules
│   ├── semgrep-rules-modified/
│   └── semgrep-rules-trail-of-bits/
└── scripts/               # Scanner execution scripts
    ├── run-checkov.sh
    ├── run-gitleaks.sh
    ├── run-kubescape.sh
    ├── run-semgrep.sh
    └── run-trivy.sh
```
