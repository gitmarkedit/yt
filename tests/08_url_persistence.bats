#!/usr/bin/env bats

setup() {
    REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "get_url returns typed query even when candidate list has no matches (exit code 1 resilience)" {
    run /bin/bash -c "
        source '$REPO_DIR/yt.sh'
        # Mock fzf to simulate user pasting 'https://youtu.be/custom123' and pressing Enter with 0 matches
        fzf() {
            printf 'https://youtu.be/custom123\n'
            return 1
        }
        res=\$(get_url)
        st=\$?
        echo \"RES=\$res\"
        echo \"STATUS=\$st\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" =~ "RES=https://youtu.be/custom123" ]]
    [[ "$output" =~ "STATUS=0" ]]
}

@test "get_url returns 130 when user exits via q or Esc" {
    run /bin/bash -c "
        source '$REPO_DIR/yt.sh'
        # Mock fzf to simulate Esc key (exit code 130)
        fzf() {
            return 130
        }
        get_url
        echo \"STATUS=\$?\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" =~ "STATUS=130" ]]
}

@test "get_url falls back to fresh macOS clipboard if Enter is pressed without query" {
    run /bin/bash -c "
        source '$REPO_DIR/yt.sh'
        # Mock pbpaste to simulate newly copied URL
        pbpaste() {
            echo 'https://www.youtube.com/watch?v=fresh_link'
        }
        # Mock fzf with empty query and empty selection
        fzf() {
            printf '\n'
            return 0
        }
        res=\$(get_url)
        st=\$?
        echo \"RES=\$res\"
        echo \"STATUS=\$st\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" =~ "RES=https://www.youtube.com/watch?v=fresh_link" ]]
    [[ "$output" =~ "STATUS=0" ]]
}
