```bash
#!/usr/bin/env bash

set -Eeuo pipefail

readonly REPOSITORY="${GITHUB_REPOSITORY:your-gh-repo-name}"
readonly S3_BUCKET="${S3_BUCKET:your-s3-bucket-name}"
readonly WORK_DIR="${WORK_DIR:-/tmp/github-actions-logs}"
readonly DATE="${DATE:-$(date -u +%Y-%m-%d)}"

log() {
    printf '[INFO] %s\n' "$*"
}

warn() {
    printf '[WARN] %s\n' "$*" >&2
}

die() {
    printf '[ERROR] %s\n' "$*" >&2
    exit 1
}

cleanup() {
    rm -rf "$WORK_DIR"
}

trap cleanup EXIT
trap 'die "Command failed at line $LINENO: $BASH_COMMAND"' ERR

for cmd in gh aws jq; do
    command -v "$cmd" >/dev/null 2>&1 ||
        die "Required command not found: $cmd"
done

gh auth status >/dev/null 2>&1 ||
    die "GitHub CLI is not authenticated."

AWS_ACCOUNT_ID="$(
    aws sts get-caller-identity \
        --query 'Account' \
        --output text
)"

log "AWS Account : $AWS_ACCOUNT_ID"
log "Repository  : $REPOSITORY"
log "Date        : $DATE"

mkdir -p "$WORK_DIR"

log "Workspace: $WORK_DIR"

log "Fetching GitHub Actions workflow runs..."

RUNS="$(
    gh api \
        --paginate \
        "repos/${REPOSITORY}/actions/runs?per_page=100" |
    jq -s 'map(.workflow_runs) | add'
)"

RUN_COUNT="$(
    jq --arg date "$DATE" '
        [
            .[] |
            select(.created_at | startswith($date))
        ] |
        length
    ' <<< "$RUNS"
)"

if [[ "$RUN_COUNT" -eq 0 ]]; then
    warn "No workflow runs found for $DATE."
    exit 0
fi

log "Workflow runs found: $RUN_COUNT"

while IFS=$'\t' read -r RUN_ID WORKFLOW STATUS CONCLUSION; do

    SAFE_WORKFLOW="$(
        printf '%s' "$WORKFLOW" |
        tr '[:space:]/' '_' |
        tr -cd '[:alnum:]_.-'
    )"

    LOG_FILE="${WORK_DIR}/${SAFE_WORKFLOW}-${RUN_ID}.zip"

    log "Processing workflow: $WORKFLOW"
    log "Run ID             : $RUN_ID"
    log "Status             : $STATUS"
    log "Conclusion         : ${CONCLUSION:-unknown}"

    gh run download "$RUN_ID" \
        --repo "$REPOSITORY" \
        --dir "${WORK_DIR}/${RUN_ID}" \
        >/dev/null 2>&1 || {
            warn "Unable to download artifacts for run $RUN_ID"
        }

    gh api \
        "repos/${REPOSITORY}/actions/runs/${RUN_ID}/logs" \
        > "$LOG_FILE"

    S3_KEY="github-actions/${REPOSITORY}/${DATE}/${SAFE_WORKFLOW}-${RUN_ID}.zip"

    aws s3 cp \
        "$LOG_FILE" \
        "s3://${S3_BUCKET}/${S3_KEY}" \
        --only-show-errors

    log "Archived: s3://${S3_BUCKET}/${S3_KEY}"

done < <(
    jq -r --arg date "$DATE" '
        .[] |
        select(.created_at | startswith($date)) |
        [
            .id,
            .name,
            .status,
            (.conclusion // "")
        ] |
        @tsv
    ' <<< "$RUNS"
)

log "GitHub Actions log archival completed successfully."
