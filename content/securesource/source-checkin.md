---
title: 'source checking'
draft: false
---








# Security Scanning Setup Overview

## Summary

This document outlines the security scanning infrastructure created for the RAGFlow project using four security tools: Semgrep, OSV Scanner, TruffleHog, and ClamAV.

## Actions Taken

### 1. Created Security Scanning Script

Created `/usr/src/ragflow/security_scan.sh` - a comprehensive bash script that:
- Automatically installs missing security tools
- Runs four different types of security scans
- Generates a summary report with findings

### 2. Tool Installation

#### Semgrep (SAST - Static Application Security Testing)
- **Status**: Pre-installed via pip
- **Purpose**: Static code analysis for finding security vulnerabilities
- **Scan type**: Pattern-based analysis across all source files

#### OSV Scanner (SCA - Software Composition Analysis)
- **Status**: Manually installed (binary download)
- **Version**: 2.3.3
- **Purpose**: Detects known vulnerabilities in dependencies
- **Installation method**: Downloaded from GitHub releases to `~/.local/bin/osv-scanner`
- **Command used**: `osv-scanner scan source --format json`

#### TruffleHog (Secrets Detection)
- **Status**: Manually installed (binary download)
- **Version**: 3.93.4
- **Purpose**: Finds exposed credentials and secrets in codebase
- **Installation method**: Downloaded from GitHub releases to `~/.local/bin/trufflehog`
- **Command used**: `trufflehog filesystem --json`

#### ClamAV (Malware Detection)
- **Status**: Not installed
- **Reason**: Requires root permissions for apt-get install
- **Purpose**: Scanning for malware/trojans in source files

### 3. Scan Results

| Tool | Type | Findings |
|------|------|----------|
| Semgrep | SAST | 74 code issues detected |
| OSV Scanner | SCA | 43 vulnerabilities in dependencies |
| TruffleHog | Secrets | 2 unverified secrets found |
| ClamAV | Malware | Not available |

### 4. Output Files

All results are saved to `/usr/src/ragflow/security_scan_results/`:

```
security_scan_results/
├── semgrep_results.json      # Static analysis results
├── osv_results.json         # Dependency vulnerabilities
└── trufflehog_results.json   # Secrets detection results
```

## Usage

### Run Full Security Scan

```bash
./security_scan.sh
```

### Prerequisites

The script automatically handles:
- Checking for tool availability
- Attempting to install missing tools
- Running all available scanners

### Manual Tool Paths

If tools are not found, add to PATH:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Tool Descriptions

### Semgrep
A fast static analysis engine that finds bugs and security vulnerabilities using pattern matching. It supports 30+ languages and has extensive rule sets for common vulnerabilities.

### OSV Scanner
Google's OSV (Open Source Vulnerabilities) scanner that checks dependencies against the OSV database, supporting multiple ecosystems including PyPI, npm, Go, etc.

### TruffleHog
Scans repositories for leaked credentials, API keys, passwords, and other sensitive information. Supports filesystem and git scanning.

### ClamAV
Open-source antivirus engine for detecting malware, trojans, and viruses. Requires system-level installation.

## Recommendations

1. **For ClamAV**: Install with root access using `sudo apt-get install clamav clamav-daemon`

2. **Periodic Scanning**: Consider adding to CI/CD pipeline:
   ```bash
   ./security_scan.sh && echo "Security scan completed"
   ```

3. **Review Results**: Manually review the JSON output files for:
   - False positives in Semgrep
   - Vulnerable packages in OSV results
   - Actual secrets vs test data in TruffleHog results

4. **Fix Vulnerabilities**:
   - Update vulnerable dependencies identified by OSV Scanner
   - Remove or rotate exposed secrets found by TruffleHog
   - Address code issues flagged by Semgrep
