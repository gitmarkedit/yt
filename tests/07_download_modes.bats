#!/usr/bin/env bats

setup() {
    REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    TEST_TMP="$(mktemp -d)"
    export HOME="$TEST_TMP"
}

teardown() {
    rm -rf "$TEST_TMP"
}

@test "execute_download builds valid syntax for video download with FastStart" {
    run /bin/bash -c "
        source '$REPO_DIR/yt.sh'
        DEST='$TEST_TMP/Downloads'
        # Run with --simulate so no actual file is written to network
        execute_download 'https://www.youtube.com/watch?v=aqz-KE-bpKQ' --simulate -f 'bestvideo+bestaudio/best'
    "
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Запуск загрузки на максимальной скорости" ]]
}

@test "execute_download builds valid syntax for audio extraction with thumbnail embed" {
    run /bin/bash -c "
        source '$REPO_DIR/yt.sh'
        DEST='$TEST_TMP/Downloads'
        # Run with --simulate and audio extraction arguments
        execute_download 'https://www.youtube.com/watch?v=aqz-KE-bpKQ' --simulate -x --audio-format mp3 --audio-quality 0
    "
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Запуск загрузки на максимальной скорости" ]]
}

@test "Subtitles download arguments pass yt-dlp syntax verification" {
    run /bin/bash -c "
        export PATH=\"/opt/homebrew/bin:/usr/local/bin:\$PATH\"
        yt-dlp --simulate --write-subs --sub-langs 'ru.*,ru' --skip-download 'https://www.youtube.com/watch?v=aqz-KE-bpKQ'
    "
    [ "$status" -eq 0 ]
}

@test "Playlist items argument verification" {
    run /bin/bash -c "
        export PATH=\"/opt/homebrew/bin:/usr/local/bin:\$PATH\"
        yt-dlp --simulate --playlist-items '1-2' 'https://www.youtube.com/watch?v=aqz-KE-bpKQ'
    "
    [ "$status" -eq 0 ]
}
