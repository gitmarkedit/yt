#!/usr/bin/env bats

setup() {
    REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    TEST_TMP="$(mktemp -d)"
    export HOME="$TEST_TMP"
    touch "$TEST_TMP/.zshrc"
}

teardown() {
    rm -rf "$TEST_TMP"
}

@test "Installer is idempotent: multiple runs do not duplicate shell aliases" {
    # Run installer first time (non-interactive)
    run /bin/bash "$REPO_DIR/install.sh" < /dev/null
    [ "$status" -eq 0 ]

    # Check alias count in .zshrc
    local count1
    count1=$(grep -c "alias yt=" "$TEST_TMP/.zshrc" || true)
    [ "$count1" -eq 1 ]

    # Run installer second time
    run /bin/bash "$REPO_DIR/install.sh" < /dev/null
    [ "$status" -eq 0 ]

    # Check alias count in .zshrc remains 1
    local count2
    count2=$(grep -c "alias yt=" "$TEST_TMP/.zshrc" || true)
    [ "$count2" -eq 1 ]
}
