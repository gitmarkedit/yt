#!/usr/bin/env bats

setup() {
    REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "Doctor reports structured 4-point issue when yt-dlp is missing" {
    run /bin/bash -c "
        source '$REPO_DIR/yt.sh'
        # Override command to simulate missing yt-dlp
        command() {
            if [ \"\$1\" = \"-v\" ] && [ \"\$2\" = \"yt-dlp\" ]; then
                return 1
            fi
            builtin command \"\$@\"
        }
        diagnose_system 0
    "
    [ "$status" -eq 1 ]
    [[ "$output" =~ "1. Что неисправно: yt-dlp не найден" ]]
    [[ "$output" =~ "2. Причина" ]]
    [[ "$output" =~ "3. Как исправить" ]]
    [[ "$output" =~ "4. Повторная проверка: yt --doctor" ]]
}

@test "Non-fzf fallback works when fzf is missing" {
    # Run select_menu without fzf in PATH
    run /bin/bash -c "
        source '$REPO_DIR/yt.sh'
        # Override command to simulate no fzf
        command() {
            if [ \"\$1\" = \"-v\" ] && [ \"\$2\" = \"fzf\" ]; then
                return 1
            fi
            builtin command \"\$@\"
        }
        # Simulate user choosing option 2
        printf '2\n' | select_menu 'Тестовое меню' 'Вариант 1' 'Вариант 2' 'Вариант 3'
    "
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Вариант 2" ]]
}
