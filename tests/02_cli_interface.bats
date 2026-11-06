#!/usr/bin/env bats

setup() {
    REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "yt.sh --help displays help banner and options" {
    run /bin/bash "$REPO_DIR/yt.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Использование:" ]]
    [[ "$output" =~ "yt --doctor" ]]
    [[ "$output" =~ "VideoToolbox" ]]
}

@test "yt.sh -h displays help banner" {
    run /bin/bash "$REPO_DIR/yt.sh" -h
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Использование:" ]]
}

@test "yt.sh --doctor runs system diagnosis with exit code 0 on healthy environment" {
    run /bin/bash "$REPO_DIR/yt.sh" --doctor
    [ "$status" -eq 0 ]
    [[ "$output" =~ "ДИАГНОСТИКА ОКРУЖЕНИЯ И САМООТЛАДКА" ]]
    [[ "$output" =~ "Командная оболочка (Bash)" ]]
    [[ "$output" =~ "Мультимедиа-движок (FFmpeg & ffprobe)" ]]
    [[ "$output" =~ "Загрузчик медиа (yt-dlp)" ]]
}

@test "yt.sh --diag is an alias to doctor" {
    run /bin/bash "$REPO_DIR/yt.sh" --diag
    [ "$status" -eq 0 ]
    [[ "$output" =~ "ДИАГНОСТИКА ОКРУЖЕНИЯ И САМООТЛАДКА" ]]
}

@test "start.sh propagates flags and arguments to yt.sh" {
    run /bin/bash "$REPO_DIR/start.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Использование:" ]]
}
