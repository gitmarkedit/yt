#!/usr/bin/env bats

setup() {
    REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "ShellCheck linter passes on yt.sh, install.sh, and start.sh" {
    run /opt/homebrew/bin/shellcheck "$REPO_DIR/yt.sh" "$REPO_DIR/install.sh" "$REPO_DIR/start.sh"
    [ "$status" -eq 0 ]
}

@test "Native macOS Bash 3.2 syntax check passes on all scripts" {
    run /bin/bash -n "$REPO_DIR/yt.sh"
    [ "$status" -eq 0 ]

    run /bin/bash -n "$REPO_DIR/install.sh"
    [ "$status" -eq 0 ]

    run /bin/bash -n "$REPO_DIR/start.sh"
    [ "$status" -eq 0 ]
}
