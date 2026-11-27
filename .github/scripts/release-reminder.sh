#!/usr/bin/env bash
# List app image changes not yet released by a `version` bump.
#
#   release-reminder.sh         print unreleased commits per app
#   release-reminder.sh issues  open, update or close one "Unreleased changes in <app>" issue per app
#
# Supervisor only pulls a new image when `version` changes, so a change to anything the image
# build consumes stays unreleased until the next `version` bump.

# Backticks in single-quoted strings are Markdown code spans, not command substitutions.
# shellcheck disable=SC2016

set -euo pipefail # Exit on error (including if command fails in a pipeline) and undefined variables.

cd "$(git rev-parse --show-toplevel)"

# Top-level `version:` in YAML, `"version":` in JSON.
version_regex='^(version|[[:space:]]*"version")[[:space:]]*:'

# apps
#   List app directories that build an image. Apps using a prebuilt image have no Dockerfile.
apps() {
    local dockerfile app
    while IFS= read -r -d '' dockerfile; do
        app=${dockerfile%/Dockerfile}
        if [[ -f "$app/config.json" || -f "$app/config.yaml" || -f "$app/config.yml" ]]; then
            printf '%s\n' "$app"
        fi
    done < <(git ls-files -z '*/Dockerfile')
}

# released <app>
#   Print the last commit that changed `version` in the app config.
released() {
    git log -1 --format=%h -E -G "$version_regex" -- "$1/config.json" "$1/config.yaml" "$1/config.yml"
}

# unreleased <app>
#   List commits after the last `version` change that changed the files triggering the image build.
unreleased() {
    local app=$1 release
    release=$(released "$app")
    git log --no-merges --format='- %h %s' "${release:+$release..}HEAD" -- \
        "$app/config.json" "$app/config.yaml" "$app/config.yml" "$app/Dockerfile" "$app/rootfs"
}

# issues
#   Keep one open issue per app with unreleased changes; close it once `version` changed.
issues() {
    local app title number commits body open_issues
    open_issues=$(gh issue list --state open --limit 1000 --json number,title)
    while IFS= read -r app; do
        title="Unreleased changes in $app"
        number=$(jq -r --arg title "$title" '[.[] | select(.title == $title)][0].number // empty' <<<"$open_issues")
        commits=$(unreleased "$app")
        if [[ -n "$commits" ]]; then
            body=$(
                printf '`%s` image changes on `main` without a `version` bump:\n\n%s\n\n%s\n' "$app" "$commits" \
                    'Bump `version` in the app config and add a CHANGELOG entry to release them. This issue closes when `version` changes.'
            )
            if [[ -n "$number" ]]; then
                gh issue edit "$number" --body "$body" >/dev/null
            else
                gh issue create --title "$title" --body "$body" >/dev/null
            fi
        elif [[ -n "$number" ]]; then
            gh issue close "$number" --comment "Released in $(released "$app")."
        fi
    done < <(apps)
}

case "${1:-}" in
"")
    while IFS= read -r app; do
        printf '%s:\n%s\n' "$app" "$(unreleased "$app")"
    done < <(apps)
    ;;
issues) issues ;;
*)
    echo "usage: $0 [issues]" >&2
    exit 2
    ;;
esac
