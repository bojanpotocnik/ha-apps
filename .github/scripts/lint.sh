#!/usr/bin/env bash

set -euo pipefail # Exit on error (including if command fails in a pipeline) and undefined variables.

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

# git_files [file name patterns...]
#   List relevant git files (tracked and new, but not ignored or unrelated) matching the given patterns.
git_files() {
    git ls-files --cached --others --exclude-standard -z "$@"
}

# lint_repository
#   Run linting checks for YAML and shell scripts in the repository.
lint_repository() {
    local yaml_files shell_files

    # Check YAML from tracked and new files, but not ignored or unrelated files.
    # NUL delimiters keep file names with spaces intact.
    mapfile -d '' yaml_files < <(git_files '*.yml' '*.yaml')
    if ((${#yaml_files[@]})); then
        yamllint "${yaml_files[@]}"
    fi

    # ShellCheck all files that start with a shell shebang, and all .sh files.
    # Deliberately force bash for consistency.
    mapfile -d '' shell_files < <(
        git_files |
            while IFS= read -r -d '' file; do
                [[ -f "$file" ]] || continue
                if [[ "$file" == *.sh ]]; then
                    printf '%s\0' "$file"
                    continue
                fi
                IFS= read -r first_line <"$file" || continue
                case "$first_line" in
                '#!'*sh*)
                    printf '%s\0' "$file"
                    ;;
                esac
            done
    )
    if ((${#shell_files[@]})); then
        shellcheck -s bash "${shell_files[@]}"
    fi
}

# Use host tools if available, otherwise use the isolated Docker container.
if command -v yamllint >/dev/null && command -v shellcheck >/dev/null; then
    lint_repository
elif [[ "${HA_APPS_LINT_IN_CONTAINER:-}" == "1" ]]; then
    # Here to prevent the container from recursively starting itself again below.
    # Impossible to land here unless Dockerfile is modified to remove the tools from container.
    echo "yamllint and shellcheck are required in the lint container" >&2
    exit 1
else
    # Build a basic container with the linting tools installed
    docker build --tag ha-apps-lint --file .github/scripts/Dockerfile .github/scripts

    # Mount repo read-only and disable networking - lint checks shall not
    # require network access or change any files.
    docker run \
        --rm \
        --network=none \
        --read-only \
        --tmpfs /tmp:rw,noexec,nosuid,size=16m \
        --user "$(id -u):$(id -g)" \
        --volume "$repo_root:/workspace:ro" \
        --workdir /workspace \
        --env HA_APPS_LINT_IN_CONTAINER=1 \
        ha-apps-lint \
        .github/scripts/lint.sh
fi

if [[ "${HA_APPS_LINT_IN_CONTAINER:-}" == "1" ]]; then
    # Running in the container, which just completed the repository linting above.
    # Exit here to avoid running the Dockerfile checks below, which require host Docker.
    exit 0
fi

# Check build syntax for each app that has a Dockerfile.
# Apps using a prebuilt image have no Dockerfile and are intentionally skipped.
while IFS= read -r -d '' dockerfile; do
    app=${dockerfile%/Dockerfile}
    if [[ -f "$app/config.json" || -f "$app/config.yaml" || -f "$app/config.yml" ]]; then
        docker build --check "$app"
    fi
done < <(git_files '*/Dockerfile')
