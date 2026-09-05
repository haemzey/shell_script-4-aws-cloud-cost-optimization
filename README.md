# GitHub Actions Log Archival to S3

Enterprise-oriented Bash automation for **archiving GitHub Actions workflow logs to Amazon S3** and reducing long-term CI/CD log storage costs.

## Workflow

```text
GitHub Actions
      │
      ▼
GitHub API
      │
      ▼
Bash + jq
      │
      ▼
Workflow Logs
      │
      ▼
Amazon S3
      │
      ▼
Lifecycle / Retention Policies
      │
      ├── Transition to Glacier
      └── Delete after retention period
```

## Script

`github-actions-log-archive.sh`

The script:

* Retrieves GitHub Actions workflow runs
* Identifies runs for a specific date
* Downloads workflow logs
* Organizes logs by repository, date, workflow, and run ID
* Uploads logs to Amazon S3
* Uses structured logging and error handling
* Validates required dependencies
* Uses environment-based configuration
* Supports CI/CD automation

## Requirements

```text
Bash
GitHub CLI (gh)
jq
AWS CLI
```

Validate:

```bash
bash --version
gh --version
jq --version
aws --version
```

## Configuration

```bash
export S3_BUCKET="my-ci-log-archive"
export GITHUB_REPOSITORY="owner/repository"
```

Authenticate GitHub CLI:

```bash
gh auth login
```

Authenticate AWS:

```bash
aws sts get-caller-identity
```

For production CI/CD, prefer **GitHub Actions OIDC with an IAM role** instead of long-lived AWS access keys.

## Usage

```bash
chmod +x github-actions-log-archive.sh
./github-actions-log-archive.sh
```

Specify a particular date if required:

```bash
DATE="2026-09-06" ./github-actions-log-archive.sh
```

## S3 Storage Structure

Logs are stored using a predictable key structure:

```text
s3://bucket/
└── github-actions/
    └── owner/repository/
        └── 2026-09-06/
            ├── build-123456.zip
            ├── deploy-123457.zip
            └── test-123458.zip
```

## Cost Optimization

The script itself provides **log archival**, while S3 lifecycle policies provide the actual storage-cost optimization.

Example strategy:

```text
0–30 days
   ↓
S3 Standard

30–90 days
   ↓
S3 Glacier

90+ days
   ↓
Delete
```

This prevents CI/CD logs from remaining indefinitely in higher-cost storage.

## Security

* Never hard-code AWS credentials.
* Never commit GitHub tokens.
* Use environment variables or CI/CD secret management.
* Prefer GitHub OIDC for AWS authentication.
* Grant the IAM role only the required S3 permissions.

Example permissions should be limited to the target bucket where possible:

```text
s3:PutObject
s3:GetObject
s3:ListBucket
```

## Bash Engineering Practices

The script follows production-oriented shell practices:

```bash
set -Eeuo pipefail
```

and includes:

* Input validation
* Dependency validation
* Error handling
* Structured logging
* Temporary workspace cleanup
* Safe variable handling
* Explicit exit status
* API-based automation
* Idempotent archival design

## Validation

Check syntax:

```bash
bash -n github-actions-log-archive.sh
```

Run ShellCheck:

```bash
shellcheck github-actions-log-archive.sh
```

## DevOps Skills Demonstrated

* Bash / Shell scripting
* GitHub Actions
* GitHub REST API
* GitHub CLI
* AWS CLI
* Amazon S3
* `jq`
* CI/CD log management
* AWS cost optimization
* S3 lifecycle management
* IAM
* OIDC authentication
* Error handling
* Production automation
