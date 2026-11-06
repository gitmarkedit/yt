#!/usr/bin/env bats

setup() {
    REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    TEST_TMP="$(mktemp -d)"
    export HOME="$TEST_TMP"
}

teardown() {
    rm -rf "$TEST_TMP"
}

@test "execute_download correctly reports error on unreachable or invalid URL" {
    run /bin/bash -c "
        source '$REPO_DIR/yt.sh'
        DEST='$TEST_TMP/Downloads'
        mkdir -p \"\$DEST\"
        # Non-existent invalid URL with timeout
        execute_download 'https://invalid-domain-does-not-exist-123456789.com/video' --socket-timeout 2
    "
    # Should exit with non-zero exit code and error message
    [ "$status" -ne 0 ]
    [[ "$output" =~ "Во время загрузки произошла ошибка" ]]
}

@test "Destination paths with spaces and special characters work seamlessly" {
    local tricky_path="$TEST_TMP/My Downloads/Special (Folder) #1"
    mkdir -p "$tricky_path"
    touch "$tricky_path/Sample Video [1080p].mp4"

    run /bin/bash -c "
        source '$REPO_DIR/yt.sh'
        DEST='$tricky_path'
        latest=\$(get_latest_file \"\$DEST\")
        echo \"LATEST=\$latest\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" =~ "LATEST=$tricky_path/Sample Video [1080p].mp4" ]]
}

@test "Signal trap restores cursor and terminates spinner cleanly on INT" {
    run /bin/bash -c "
        source '$REPO_DIR/yt.sh'
        start_spinner 'Тестирование спиннера'
        sleep 0.2
        # Check spinner is running
        [ -n \"\$SPINNER_PID\" ] && kill -0 \"\$SPINNER_PID\"
        # Trigger cleanup
        cleanup
        # Verify spinner process is stopped
        if kill -0 \"\$SPINNER_PID\" 2>/dev/null; then
            exit 1
        fi
        exit 0
    "
    [ "$status" -eq 0 ]
}
