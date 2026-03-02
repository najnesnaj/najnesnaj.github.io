---
title: 'trivy security scanning'
draft: false
---









# Trivy Security Scanning Procedure

## Overview

Trivy is a comprehensive security scanner from Aqua Security that detects:
- **Vulnerabilities** in application dependencies
- **Secrets** (exposed credentials, API keys, passwords)
- **Misconfigurations** (infrastructure as code issues)

## Installation Procedure

### Step 1: Download Trivy

```bash
# Get latest version
curl -sL "https://api.github.com/repos/aquasecurity/trivy/releases/latest" | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4

# Download using install script
curl -sLs https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /tmp/trivy

# Move to user bin
mv /tmp/trivy/trivy ~/.local/bin/
chmod +x ~/.local/bin/trivy

# Verify
trivy --version
```

## Scanning Commands

### 1. Vulnerability Scan (SCA)

Scans for known vulnerabilities in dependencies.

```bash
trivy fs --scanners vuln \
  --format json \
  --output trivy_results/vulnerabilities.json \
  /usr/src/ragflow
```

**Results:** 6 files with vulnerabilities detected

### 2. Secrets Scan

Scans for exposed secrets, API keys, passwords, and tokens.

```bash
trivy fs --scanners secret \
  --format json \
  --output trivy_results/secrets.json \
  /usr/src/ragflow
```

**Results:** 6 files with secrets detected

### 3. Misconfiguration Scan

Scans for misconfigurations in configuration files (Dockerfile, Kubernetes YAML, Terraform, etc.).

```bash
trivy fs --scanners misconfig \
  --format json \
  --output trivy_results/misconfig.json \
  /usr/src/ragflow
```

**Results:** 19 files with misconfigurations detected

### 4. Combined Scan (All)

Run all scanners at once:

```bash
trivy fs --scanners vuln,secret,misconfig \
  --format json \
  --output trivy_results/combined.json \
  /usr/src/ragflow
```

## Output Files

All results are saved to `/usr/src/ragflow/trivy_results/`:

```
trivy_results/
├── vulnerabilities.json    # Dependency vulnerabilities
├── secrets.json            # Exposed secrets
├── misconfig.json          # Configuration issues
└── combined.json           # All findings (if running combined)
```

## Usage Examples

### View Results Summary

```bash
# Text format
trivy fs /usr/src/ragflow

# JSON format for parsing
trivy fs --format json /usr/src/ragflow > results.json
```

### Filter by Severity

```bash
# Only critical and high
trivy fs --severity CRITICAL,HIGH /usr/src/ragflow
```

### Ignore Files

```bash
# Ignore specific paths
trivy fs --ignorepath .git --ignorepath node_modules /usr/src/ragflow
```

## Scan Results Summary

| Scan Type | Files with Issues |
|-----------|-------------------|
| Vulnerabilities | 6 |
| Secrets | 6 |
| Misconfigurations | 19 |

## Additional Trivy Capabilities

### Container Image Scanning

```bash
trivy image nginx:latest
```

### Git Repository Scanning

```bash
trivy repo https://github.com/aquasecurity/trivy
```

### Kubernetes Cluster Scanning

```bash
trivy k8s --report summary
```

### Filesystem with Custom Policies

```bash
trivy fs --policy ./custom-policies /usr/src/ragflow
```

## Recommendations

1. **Run regularly**: Add to CI/CD pipeline for automated scanning
2. **Review JSON output**: Parse for automated ticket creation
3. **Update DB regularly**: `trivy db update` for latest vulnerabilities
4. **Filter false positives**: Use `--ignore-unfixed` or custom ignore files
5. **Combine with other tools**: Use alongside Semgrep, OSV Scanner, and TruffleHog for comprehensive coverage
