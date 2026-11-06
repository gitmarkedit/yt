#!/usr/bin/env bats

setup() {
    REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    TEST_TMP="$(mktemp -d)"
    export HOME="$TEST_TMP"
}

teardown() {
    rm -rf "$TEST_TMP"
}

@test "Config loads default values when config.env is missing" {
    run /bin/bash -c "
        source '$REPO_DIR/yt.sh'
        load_config
        echo \"DEST=\$DEST\"
        echo \"EMBED_METADATA=\$EMBED_METADATA\"
        echo \"CONCURRENT_FRAGMENTS=\$CONCURRENT_FRAGMENTS\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" =~ "DEST=$TEST_TMP/Downloads/Media" ]]
    [[ "$output" =~ "EMBED_METADATA=true" ]]
    [[ "$output" =~ "CONCURRENT_FRAGMENTS=8" ]]
}

@test "Config saves and reloads customized settings" {
    run /bin/bash -c "
        source '$REPO_DIR/yt.sh'
        DEST='$TEST_TMP/Custom Downloads/Special [Media]'
        EMBED_METADATA='false'
        CONCURRENT_FRAGMENTS='16'
        save_config

        # Reset variables in memory
        DEST=''
        EMBED_METADATA=''
        CONCURRENT_FRAGMENTS=''

        load_config
        echo \"DEST=\$DEST\"
        echo \"EMBED_METADATA=\$EMBED_METADATA\"
        echo \"CONCURRENT_FRAGMENTS=\$CONCURRENT_FRAGMENTS\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" =~ "DEST=$TEST_TMP/Custom Downloads/Special [Media]" ]]
    [[ "$output" =~ "EMBED_METADATA=false" ]]
    [[ "$output" =~ "CONCURRENT_FRAGMENTS=16" ]]
}

@test "Config gracefully sanitizes corrupted values" {
    mkdir -p "$TEST_TMP/.config/yt-downloader"
    cat > "$TEST_TMP/.config/yt-downloader/config.env" << 'EOF'
EMBED_METADATA="invalid_boolean"
CONCURRENT_FRAGMENTS="not_a_number"
DEFAULT_CONTAINER="unsupported_format"
COOKIE_BROWSER="malicious_input"
EOF

    run /bin/bash -c "
        source '$REPO_DIR/yt.sh'
        load_config
        echo \"EMBED_METADATA=\$EMBED_METADATA\"
        echo \"CONCURRENT_FRAGMENTS=\$CONCURRENT_FRAGMENTS\"
        echo \"DEFAULT_CONTAINER=\$DEFAULT_CONTAINER\"
        echo \"COOKIE_BROWSER=\$COOKIE_BROWSER\"
    "
    [ "$status" -eq 0 ]
    # Values should be reset to safe defaults
    [[ "$output" =~ "EMBED_METADATA=true" ]]
    [[ "$output" =~ "CONCURRENT_FRAGMENTS=8" ]]
    [[ "$output" =~ "DEFAULT_CONTAINER=mp4" ]]
    [[ "$output" =~ "COOKIE_BROWSER=none" ]]
}
