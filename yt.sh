#!/usr/bin/env bash
# ==============================================================================
#  ⚡ yt (macOS Edition)
#  Высокопроизводительный медиа-загрузчик с аппаратным ускорением VideoToolbox
# ==============================================================================

# Корректное определение реальной директории скрипта даже при запуске через symlink
SOURCE="${BASH_SOURCE[0]:-$0}"
while [ -L "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" 2>/dev/null && pwd)"

# Автоматическое подключение путей Homebrew (Apple Silicon /opt/homebrew и Intel /usr/local)
export PATH="$SCRIPT_DIR/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:$HOME/.local/bin:$PATH"

if command -v brew &>/dev/null; then
    BREW_PREFIX="$(brew --prefix 2>/dev/null)"
    if [ -n "$BREW_PREFIX" ] && [ -d "$BREW_PREFIX/bin" ]; then
        case ":$PATH:" in
            *":$BREW_PREFIX/bin:"*) ;;
            *) export PATH="$BREW_PREFIX/bin:$BREW_PREFIX/sbin:$PATH" ;;
        esac
    fi
fi

# Определение платформы и процессора Mac
OS_NAME="$(uname -s 2>/dev/null || echo "Unknown")"
CPU_ARCH="$(uname -m 2>/dev/null || echo "Unknown")"
CPU_BRAND="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "$CPU_ARCH")"

# Конфигурация и пути по умолчанию
CONFIG_DIR="$HOME/.config/yt-downloader"
CONFIG_FILE="$CONFIG_DIR/config.env"
DEFAULT_DEST="$HOME/Downloads/Media"

DEST="$DEFAULT_DEST"
EMBED_METADATA="true"
EMBED_THUMBNAIL="true"
DEFAULT_CONTAINER="mp4"
CONCURRENT_FRAGMENTS="8"     # На Apple Silicon 8 потоков дают максимальную утилизацию сети
COOKIE_BROWSER="none"       # none, safari, chrome, firefox
APPLE_COMPAT_MODE="true"    # Форсировать H.264/AAC для 100% работы в QuickTime & Finder QuickLook
SOUND_ENABLED="true"
DEBUG_MODE="false"

# Определение движка JavaScript для yt-dlp (ускорение обхода YouTube player challenge)
JS_RUNTIME_ARGS=()
if command -v node &>/dev/null; then
    JS_RUNTIME_ARGS=("--js-runtimes" "node")
elif command -v deno &>/dev/null; then
    JS_RUNTIME_ARGS=("--js-runtimes" "deno")
fi

# ------------------------------------------------------------------------------
# Стили и Цвета (ANSI 256 / TrueColor)
# ------------------------------------------------------------------------------
if [ -t 1 ]; then
    BOLD='\033[1m'
    DIM='\033[2m'
    RED='\033[38;5;196m'
    GREEN='\033[38;5;46m'
    YELLOW='\033[38;5;220m'
    BLUE='\033[38;5;39m'
    CYAN='\033[38;5;51m'
    WHITE='\033[38;5;231m'
    GRAY='\033[38;5;244m'
    RESET='\033[0m'
else
    BOLD='' DIM='' RED='' GREEN='' YELLOW='' BLUE='' CYAN='' WHITE='' GRAY='' RESET=''
fi

# ------------------------------------------------------------------------------
# Управление конфигурацией
# ------------------------------------------------------------------------------
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck disable=SC1090
        source "$CONFIG_FILE" 2>/dev/null || true
    fi

    # Валидация и защита от некорректных значений
    [[ "$EMBED_METADATA" =~ ^(true|false)$ ]] || EMBED_METADATA="true"
    [[ "$EMBED_THUMBNAIL" =~ ^(true|false)$ ]] || EMBED_THUMBNAIL="true"
    [[ "$SOUND_ENABLED" =~ ^(true|false)$ ]] || SOUND_ENABLED="true"
    [[ "$APPLE_COMPAT_MODE" =~ ^(true|false)$ ]] || APPLE_COMPAT_MODE="true"
    [[ "$CONCURRENT_FRAGMENTS" =~ ^[0-9]+$ ]] || CONCURRENT_FRAGMENTS="8"
    [[ "$DEFAULT_CONTAINER" =~ ^(mp4|mkv|webm)$ ]] || DEFAULT_CONTAINER="mp4"
    [[ "$COOKIE_BROWSER" =~ ^(none|safari|chrome|firefox)$ ]] || COOKIE_BROWSER="none"

    [ -z "$DEST" ] && DEST="$DEFAULT_DEST"
    DEST="${DEST%/}"
    mkdir -p "$DEST" 2>/dev/null || true
}

save_config() {
    mkdir -p "$CONFIG_DIR" 2>/dev/null || true
    cat > "$CONFIG_FILE" <<EOF
# yt (macOS Edition) Configuration
DEST="$DEST"
EMBED_METADATA="$EMBED_METADATA"
EMBED_THUMBNAIL="$EMBED_THUMBNAIL"
DEFAULT_CONTAINER="$DEFAULT_CONTAINER"
CONCURRENT_FRAGMENTS="$CONCURRENT_FRAGMENTS"
COOKIE_BROWSER="$COOKIE_BROWSER"
APPLE_COMPAT_MODE="$APPLE_COMPAT_MODE"
SOUND_ENABLED="$SOUND_ENABLED"
EOF
}

# ------------------------------------------------------------------------------
# Анимации: Спиннер и Управление курсором
# ------------------------------------------------------------------------------
SPINNER_PID=""

stop_spinner() {
    if [ -n "$SPINNER_PID" ] && kill -0 "$SPINNER_PID" 2>/dev/null; then
        kill "$SPINNER_PID" 2>/dev/null
        wait "$SPINNER_PID" 2>/dev/null || true
    fi
    SPINNER_PID=""
    tput cnorm 2>/dev/null || true
    printf "\r\033[K"
}

start_spinner() {
    stop_spinner
    local message="$1"
    tput civis 2>/dev/null || true
    (
        local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
        local colors=("\033[38;5;51m" "\033[38;5;45m" "\033[38;5;39m" "\033[38;5;33m" "\033[38;5;27m" "\033[38;5;33m" "\033[38;5;39m" "\033[38;5;45m")
        local i=0
        local start_sec=$SECONDS
        while true; do
            local elapsed=$(( SECONDS - start_sec ))
            local c_idx=$(( i % ${#colors[@]} ))
            local col="${colors[c_idx]}"
            printf "\r${col}%s${RESET} [%02d:%02d] %s" "${frames[i]}" "$((elapsed / 60))" "$((elapsed % 60))" "$message"
            i=$(( (i + 1) % ${#frames[@]} ))
            sleep 0.07
        done
    ) &
    SPINNER_PID=$!
}

cleanup() {
    stop_spinner
    tput cnorm 2>/dev/null || true
}
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM
trap cleanup EXIT

# ------------------------------------------------------------------------------
# Проверка и Самодиагностика зависимостей
# ------------------------------------------------------------------------------
check_dependencies() {
    local missing=()
    command -v yt-dlp &>/dev/null || missing+=("yt-dlp")
    command -v ffmpeg &>/dev/null || missing+=("ffmpeg")

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}${BOLD}❌ На вашем компьютере не найдены обязательные утилиты:${RESET} ${missing[*]}"
        
        if [ ! -t 0 ]; then
            echo -e "${YELLOW}Для автоматической установки запустите: bash install.sh${RESET}"
            exit 1
        fi

        echo -e "${YELLOW}Запустить автоматическую установку всех зависимостей? [Y/n]${RESET}"
        read -r -p "> " auto_install
        auto_install=${auto_install:-y}

        if [[ "$auto_install" =~ ^[YyДд] ]]; then
            if [ -f "$SCRIPT_DIR/install.sh" ]; then
                bash "$SCRIPT_DIR/install.sh" --no-launch
            else
                if command -v brew &>/dev/null; then
                    brew install "${missing[@]}" fzf || true
                else
                    echo -e "${RED}Homebrew не найден. Установите yt-dlp и ffmpeg вручную.${RESET}"
                    exit 1
                fi
            fi
            export PATH="$SCRIPT_DIR/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:$HOME/.local/bin:$PATH"
            if ! command -v yt-dlp &>/dev/null; then
                echo -e "\n${YELLOW}⚡ Автономная установка официального бинарника yt-dlp для macOS...${RESET}"
                mkdir -p "$SCRIPT_DIR/bin"
                if curl -fL --progress-bar "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos" -o "$SCRIPT_DIR/bin/yt-dlp"; then
                    chmod +x "$SCRIPT_DIR/bin/yt-dlp"
                    xattr -d com.apple.quarantine "$SCRIPT_DIR/bin/yt-dlp" 2>/dev/null || true
                    echo -e "${GREEN}✓ yt-dlp успешно установлен в $SCRIPT_DIR/bin/yt-dlp!${RESET}"
                fi
            fi
            if ! command -v ffmpeg &>/dev/null; then
                echo -e "\n${YELLOW}⚡ Автономная установка медиа-движка FFmpeg (с ускорением VideoToolbox)...${RESET}"
                mkdir -p "$SCRIPT_DIR/bin"
                local arch
                arch="$(uname -m 2>/dev/null || echo "arm64")"
                local temp_dir="$SCRIPT_DIR/bin/temp_extract"
                mkdir -p "$temp_dir"
                if curl -fL --progress-bar "https://github.com/homebridge/ffmpeg-for-homebridge/releases/latest/download/ffmpeg-darwin-${arch}.tar.gz" | tar -xz -C "$temp_dir" 2>/dev/null; then
                    if [ -f "$temp_dir/usr/local/bin/ffmpeg" ]; then
                        mv "$temp_dir/usr/local/bin/ffmpeg" "$SCRIPT_DIR/bin/ffmpeg"
                        chmod +x "$SCRIPT_DIR/bin/ffmpeg"
                        xattr -d com.apple.quarantine "$SCRIPT_DIR/bin/ffmpeg" 2>/dev/null || true
                        echo -e "${GREEN}✓ FFmpeg успешно установлен в $SCRIPT_DIR/bin/ffmpeg!${RESET}"
                    fi
                fi
                rm -rf "$temp_dir"
            fi
            if ! command -v fzf &>/dev/null; then
                local fzf_arch="arm64"
                local cur_arch
                cur_arch="$(uname -m 2>/dev/null || echo "arm64")"
                [ "$cur_arch" = "x86_64" ] && fzf_arch="amd64"
                local tag
                tag=$(curl -sIL https://github.com/junegunn/fzf/releases/latest 2>/dev/null | tr -d '\r' | awk -F'/tag/' '/[Ll]ocation:/ {print $2}' | tail -n 1)
                [ -z "$tag" ] && tag="v0.75.0"
                local ver="${tag#v}"
                local fzf_url="https://github.com/junegunn/fzf/releases/download/${tag}/fzf-${ver}-darwin_${fzf_arch}.tar.gz"
                if curl -fL --progress-bar "$fzf_url" | tar -xz -C "$SCRIPT_DIR/bin" 2>/dev/null; then
                    chmod +x "$SCRIPT_DIR/bin/fzf" 2>/dev/null || true
                    xattr -d com.apple.quarantine "$SCRIPT_DIR/bin/fzf" 2>/dev/null || true
                fi
            fi
            if ! command -v yt-dlp &>/dev/null || ! command -v ffmpeg &>/dev/null; then
                echo -e "${RED}❌ Не удалось автоматически установить компоненты. Проверьте подключение к интернету.${RESET}"
                exit 1
            fi
        else
            echo -e "${YELLOW}Для работы скрипта требуются yt-dlp и ffmpeg.${RESET}"
            exit 1
        fi
    fi
}

# ------------------------------------------------------------------------------
# Идеально выверенный баннер (без глитчей и сдвигов границ)
# ------------------------------------------------------------------------------
show_banner() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}"
    cat << "EOF"
   ╭──────────────────────────────────────────────────────────╮
   │                    yt (macOS Edition)                    │
   │    Высокоскоростная загрузка с аппаратным медиа-ядром    │
   ╰──────────────────────────────────────────────────────────╯
EOF
    echo -e "${RESET}"

    # Статус платформы с ровным выравниванием двоеточий
    if [ "$OS_NAME" = "Darwin" ]; then
        local hw_accel_info=""
        if ffmpeg -hwaccels 2>/dev/null | grep -q "videotoolbox"; then
            hw_accel_info="${GREEN}VideoToolbox [Hardware Accelerated]${RESET}"
        else
            hw_accel_info="${YELLOW}Software (CPU)${RESET}"
        fi
        echo -e "  ${GRAY}  Модель  :${RESET} ${WHITE}${BOLD}$CPU_BRAND${RESET} (${CYAN}$CPU_ARCH${RESET})"
        echo -e "  ${YELLOW}⚡ Движок  :${RESET} $hw_accel_info  ${GRAY}• Потоков:${RESET} ${CYAN}${CONCURRENT_FRAGMENTS}${RESET}"
    else
        echo -e "  ${GRAY}Система    :${RESET} ${WHITE}$OS_NAME ($CPU_ARCH)${RESET}"
    fi
    echo ""
}

# ------------------------------------------------------------------------------
# Карточка информации о медиа
# ------------------------------------------------------------------------------
fetch_and_display_info() {
    local url="$1"
    start_spinner "Анализ медиа и проверка доступных разрешений..."

    local cookie_flag=()
    if [ "$COOKIE_BROWSER" != "none" ]; then
        cookie_flag=("--cookies-from-browser" "$COOKIE_BROWSER")
    fi

    local meta
    meta=$(yt-dlp \
        "${JS_RUNTIME_ARGS[@]}" \
        "${cookie_flag[@]}" \
        --no-warnings \
        --no-playlist \
        --skip-download \
        --print "%(title)s	%(uploader,channel,creator)s	%(duration_string)s	%(view_count)s" \
        "$url" 2>/dev/null | head -n 1)

    stop_spinner

    if [ -n "$meta" ]; then
        local title uploader duration views
        IFS=$'\t' read -r title uploader duration views <<< "$meta"

        echo -e "${BLUE}╭─ 📺 Информация о медиа ───────────────────────────────────────╮${RESET}"
        echo -e "${BLUE}│${RESET} ${BOLD}Название  :${RESET}  $title"
        [ -n "$uploader" ] && [ "$uploader" != "NA" ] && \
        echo -e "${BLUE}│${RESET} ${DIM}Автор     :${RESET}  $uploader"
        [ -n "$duration" ] && [ "$duration" != "NA" ] && \
        echo -e "${BLUE}│${RESET} ${DIM}Время     :${RESET}  $duration"
        [ -n "$views" ] && [ "$views" != "NA" ] && \
        echo -e "${BLUE}│${RESET} ${DIM}Просмотры :${RESET}  $views"
        if [ "$APPLE_COMPAT_MODE" = "true" ]; then
            echo -e "${BLUE}│${RESET} ${GREEN} Режим   :${RESET}  100% QuickTime & QuickLook (Пробел) совместимость"
        fi
        echo -e "${BLUE}╰───────────────────────────────────────────────────────────────╯${RESET}"
        echo ""
    else
        echo -e "${YELLOW}⚠️ Не удалось извлечь предпросмотр (возможно, закрытое видео или плейлист).${RESET}\n"
    fi
}

# ------------------------------------------------------------------------------
# Меню выбора (FZF с автоподстройкой или встроенный fallback)
# ------------------------------------------------------------------------------
select_menu() {
    local prompt="$1"
    shift
    local options=("$@")

    if command -v fzf &>/dev/null; then
        local height=$(( ${#options[@]} + 4 ))
        [ "$height" -gt 22 ] && height=22
        [ "$height" -lt 6 ] && height=6

        printf "%s\n" "${options[@]}" | fzf \
            --height="$height" \
            --layout=reverse \
            --border=rounded \
            --prompt="$prompt " \
            --pointer="▶" \
            --marker="✓" \
            --bind="esc:cancel,ctrl-c:abort" \
            --color="prompt:cyan,pointer:magenta,marker:green,header:yellow,border:blue"
    else
        echo -e "\n${CYAN}${BOLD}$prompt${RESET}"
        local i=1
        for opt in "${options[@]}"; do
            printf "  ${YELLOW}%2d)${RESET} %s\n" "$i" "$opt"
            i=$((i + 1))
        done
        while true; do
            local choice=""
            if ! read -r -p "Выберите номер [1-${#options[@]}]: " choice; then
                return 130
            fi
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
                echo "${options[$((choice - 1))]}"
                return 0
            fi
            echo -e "${RED}Неверный ввод, повторите попытку.${RESET}"
        done
    fi
}

# ------------------------------------------------------------------------------
# Получение URL (Буфер обмена macOS или ввод)
# ------------------------------------------------------------------------------
get_url() {
    local clip_url=""
    if command -v pbpaste &>/dev/null; then
        local raw
        raw=$(pbpaste 2>/dev/null | tr -d '\r\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        if [[ "$raw" =~ ^https?:// ]]; then
            clip_url="$raw"
        fi
    fi

    if command -v fzf &>/dev/null; then
        local prompt_list=""
        if [ -n "$clip_url" ]; then
            prompt_list="📋 Использовать из буфера macOS: $clip_url"
        fi

        local res exit_code
        res=$(printf "%s\n" "$prompt_list" | fzf \
            --print-query \
            --height=7 \
            --layout=reverse \
            --border=rounded \
            --prompt="Ссылка > " \
            --header="Вставьте ссылку и нажмите Enter (Esc - выход):" \
            --bind="enter:accept-or-print-query,esc:cancel,ctrl-c:abort" \
            --color="prompt:cyan,pointer:magenta,header:yellow,border:blue")
        exit_code=$?

        # 130 = нажатие Esc или Ctrl+C (явная отмена / выход)
        if [ $exit_code -eq 130 ]; then
            return 130
        fi

        local typed_query selected_item
        typed_query=$(echo "$res" | sed -n '1p' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        selected_item=$(echo "$res" | sed -n '2p' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

        # 1. Если пользователь вставил или напечатал ссылку (любой текст в строке fzf)
        if [ -n "$typed_query" ]; then
            if [[ "$typed_query" =~ ^(q|quit|exit)$ ]]; then
                return 130
            fi
            echo "$typed_query"
            return 0
        # 2. Если пользователь нажал Enter на строке с ссылкой из буфера
        elif [ -n "$selected_item" ]; then
            local extracted_url
            extracted_url=$(echo "$selected_item" | grep -o 'https\?://[^ ]*')
            if [ -n "$extracted_url" ]; then
                echo "$extracted_url"
                return 0
            else
                echo "$selected_item"
                return 0
            fi
        # 3. Динамическая проверка: если пользователь скопировал ссылку, пока окно было открыто
        elif command -v pbpaste &>/dev/null; then
            local fresh_clip
            fresh_clip=$(pbpaste 2>/dev/null | tr -d '\r\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            if [[ "$fresh_clip" =~ ^https?:// ]]; then
                echo "$fresh_clip"
                return 0
            fi
        fi

        return 1
    else
        local clip_msg=""
        if [ -n "$clip_url" ]; then
            clip_msg=" (Enter для ссылки из буфера: $clip_url)"
        fi
        echo -e "${CYAN}Вставьте ссылку на медиа${clip_msg}${RESET}"
        local manual_url=""
        if ! read -r -p "Ссылка (или 'q' для выхода) > " manual_url; then
            return 130
        fi
        manual_url=$(echo "$manual_url" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        if [[ "$manual_url" =~ ^(q|quit|exit)$ ]]; then
            return 130
        fi
        if [ -n "$manual_url" ]; then
            echo "$manual_url"
            return 0
        elif [ -n "$clip_url" ]; then
            echo "$clip_url"
            return 0
        fi
        return 1
    fi
}

# ------------------------------------------------------------------------------
# Запуск загрузки с аппаратной оптимизацией под macOS
# ------------------------------------------------------------------------------
execute_download() {
    local url="$1"
    shift
    local extra_args=("$@")

    local common_args=(
        "--no-mtime"
        "-N" "$CONCURRENT_FRAGMENTS"
        "--console-title"
        "--progress-template" "download:  %(progress._percent_str)s of %(progress._total_bytes_str,progress._total_bytes_estimate_str)s at %(progress._speed_str)s [ETA %(progress._eta_str)s]"
    )

    if [ ${#JS_RUNTIME_ARGS[@]} -gt 0 ]; then
        common_args+=("${JS_RUNTIME_ARGS[@]}")
    fi

    # Куки браузера (для обхода ограничений YouTube/VK)
    if [ "$COOKIE_BROWSER" != "none" ]; then
        common_args+=("--cookies-from-browser" "$COOKIE_BROWSER")
    fi

    # Вшивание метаданных и глав для Apple экосистемы
    if [ "$EMBED_METADATA" = "true" ]; then
        common_args+=("--embed-metadata" "--embed-chapters")
    fi

    # QuickTime / Finder QuickLook оптимизация (быстрый старт видео без задержек)
    common_args+=("--postprocessor-args" "Merger:-movflags +faststart")

    # Сортировка форматов под кодеки Apple Silicon (H.264/HEVC)
    if [ "$APPLE_COMPAT_MODE" = "true" ]; then
        common_args+=("-S" "vcodec:h264,vcodec:hevc,lang,quality,res,fps")
    fi

    if [ "$DEBUG_MODE" = "true" ]; then
        echo -e "${YELLOW}[DEBUG] Команда:${RESET} yt-dlp ${common_args[*]} ${extra_args[*]} $url\n"
    fi

    echo -e "${CYAN}▶ Запуск загрузки на максимальной скорости...${RESET}\n"

    yt-dlp "${common_args[@]}" "${extra_args[@]}" "$url"
    local dl_status=$?

    echo ""
    if [ $dl_status -eq 0 ]; then
        echo -e "${GREEN}${BOLD}╭─────────────────────────────────────────────────────────────╮${RESET}"
        echo -e "${GREEN}${BOLD}│  ✅ Загрузка успешно завершена!                             │${RESET}"
        echo -e "${GREEN}│${RESET}  📁 Папка: ${CYAN}$DEST${RESET}"
        echo -e "${GREEN}${BOLD}╰─────────────────────────────────────────────────────────────╯${RESET}"

        # Звуковой сигнал macOS (приятный системный Glass)
        if [ "$SOUND_ENABLED" = "true" ] && [ -f "/System/Library/Sounds/Glass.aiff" ]; then
            afplay "/System/Library/Sounds/Glass.aiff" 2>/dev/null &
        fi

        # Системное уведомление macOS
        if command -v osascript &>/dev/null; then
            osascript -e "display notification \"Файл сохранён в $DEST\" with title \"yt (macOS Edition)\" sound name \"Glass\"" 2>/dev/null || true
        fi
        return 0
    else
        echo -e "${RED}${BOLD}❌ Во время загрузки произошла ошибка (код: $dl_status).${RESET}"
        return $dl_status
    fi
}

# ------------------------------------------------------------------------------
# Подменю: Выбор точного разрешения
# ------------------------------------------------------------------------------
menu_resolution() {
    local url="$1"

    local choice
    choice=$(select_menu "Выберите разрешение видео >" \
        "◈  4K Ultra HD (2160p)" \
        "◇  2K Quad HD (1440p)" \
        "⏵  Full HD (1080p - Рекомендуется)" \
        "◻  HD (720p - Оптимально для телефонов)" \
        "◽  SD (480p)" \
        "▫  360p (Экономный режим)" \
        "↩  Назад")

    local height_limit=""
    case "$choice" in
        *"2160p"*) height_limit="2160" ;;
        *"1440p"*) height_limit="1440" ;;
        *"1080p"*) height_limit="1080" ;;
        *"720p"*)  height_limit="720" ;;
        *"480p"*)  height_limit="480" ;;
        *"360p"*)  height_limit="360" ;;
        *) return 130 ;;
    esac

    local container_choice
    container_choice=$(select_menu "Выберите формат контейнера >" \
        "MP4 (Рекомендуется для Mac, iPhone и QuickTime)" \
        "MKV (Поддержка любых дорожек и субтитров)" \
        "WEBM (Оригинал Google)")

    local container="mp4"
    case "$container_choice" in
        *"MKV"*)  container="mkv" ;;
        *"WEBM"*) container="webm" ;;
        *"MP4"*)  container="mp4" ;;
        *)        return 130 ;;
    esac

    local thumb_args=()
    if [ "$EMBED_THUMBNAIL" = "true" ]; then
        thumb_args=("--embed-thumbnail" "--convert-thumbnails" "jpg")
    fi

    execute_download "$url" \
        --no-playlist \
        -f "bestvideo[height<=${height_limit}]+bestaudio/best[height<=${height_limit}]/best" \
        --merge-output-format "$container" \
        "${thumb_args[@]}" \
        -o "$DEST/%(title)s.%(ext)s"
}

# ------------------------------------------------------------------------------
# Подменю: Аудио форматы
# ------------------------------------------------------------------------------
menu_audio() {
    local url="$1"

    local choice
    choice=$(select_menu "Выберите формат аудио >" \
        "♫  MP3 (Максимальный битрейт ~320k, обложка, теги)" \
        "  M4A / AAC (Apple нативный без пересжатия)" \
        "◈  FLAC (Lossless студийный звук)" \
        "◇  WAV (Несжатый PCM звук)" \
        "◖  OPUS (Максимальное качество при малом весе)" \
        "⤓  Direct Stream Copy (Мгновенное сохранение оригинала)" \
        "↩  Назад")

    local thumb_args=()
    if [ "$EMBED_THUMBNAIL" = "true" ]; then
        thumb_args=("--embed-thumbnail" "--convert-thumbnails" "jpg")
    fi

    case "$choice" in
        *"MP3"*)
            execute_download "$url" \
                --no-playlist \
                -x \
                --audio-format mp3 \
                --audio-quality 0 \
                "${thumb_args[@]}" \
                -o "$DEST/%(title)s.%(ext)s"
            ;;
        *"M4A"*)
            execute_download "$url" \
                --no-playlist \
                -x \
                --audio-format m4a \
                "${thumb_args[@]}" \
                -o "$DEST/%(title)s.%(ext)s"
            ;;
        *"FLAC"*)
            execute_download "$url" \
                --no-playlist \
                -x \
                --audio-format flac \
                "${thumb_args[@]}" \
                -o "$DEST/%(title)s.%(ext)s"
            ;;
        *"WAV"*)
            execute_download "$url" \
                --no-playlist \
                -x \
                --audio-format wav \
                -o "$DEST/%(title)s.%(ext)s"
            ;;
        *"OPUS"*)
            execute_download "$url" \
                --no-playlist \
                -x \
                --audio-format opus \
                "${thumb_args[@]}" \
                -o "$DEST/%(title)s.%(ext)s"
            ;;
        *"Direct Stream"*)
            execute_download "$url" \
                --no-playlist \
                -x \
                "${thumb_args[@]}" \
                -o "$DEST/%(title)s.%(ext)s"
            ;;
        *)
            return 130
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Подменю: Скачивание фрагмента (Time-slice)
# ------------------------------------------------------------------------------
menu_timeslice() {
    local url="$1"
    echo ""
    echo -e "${CYAN}${BOLD}✂️ Скачивание фрагмента по таймкоду${RESET}"
    echo -e "${DIM}Примеры интервалов: 01:15-02:30 или 00:05:00-00:08:30${RESET}"
    local time_range=""
    read -r -p "Введите начало и конец (ММ:СС-ММ:СС): " time_range
    time_range=$(echo "$time_range" | tr -d ' ')

    if [ -z "$time_range" ]; then
        echo -e "${YELLOW}Интервал не указан.${RESET}"
        sleep 1
        return 130
    fi

    local slice_type
    slice_type=$(select_menu "Формат для отрезка >" \
        "⏵  Видео Full HD (MP4)" \
        "♫  Аудио MP3 (320k)" \
        "↩  Отмена")

    case "$slice_type" in
        *"Видео"*)
            execute_download "$url" \
                --no-playlist \
                --download-sections "*$time_range" \
                -f "bestvideo[height<=1080]+bestaudio/best" \
                --merge-output-format "mp4" \
                -o "$DEST/%(title)s [${time_range}].%(ext)s"
            ;;
        *"Аудио"*)
            execute_download "$url" \
                --no-playlist \
                --download-sections "*$time_range" \
                -x --audio-format mp3 --audio-quality 0 \
                -o "$DEST/%(title)s [${time_range}].%(ext)s"
            ;;
        *)
            return 130
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Подменю: Плейлисты
# ------------------------------------------------------------------------------
menu_playlist() {
    local url="$1"

    local choice
    choice=$(select_menu "Режим загрузки плейлиста >" \
        "☰  Скачать весь плейлист целиком" \
        "🔢 Выбрать диапазон номеров (например: 1-10 или 2,5,8)" \
        "↩  Назад")

    case "$choice" in
        *"целиком"*)
            execute_download "$url" \
                --yes-playlist \
                -f "bestvideo+bestaudio/best" \
                --merge-output-format "$DEFAULT_CONTAINER" \
                -o "$DEST/%(playlist_title,playlist)s/%(playlist_index)02d - %(title)s.%(ext)s"
            ;;
        *"диапазон"*)
            echo ""
            local range=""
            read -r -p "Введите диапазон (например, 1-5 или 1,3,7): " range
            range=$(echo "$range" | tr -d ' ')
            if [ -n "$range" ]; then
                execute_download "$url" \
                    --yes-playlist \
                    --playlist-items "$range" \
                    -f "bestvideo+bestaudio/best" \
                    --merge-output-format "$DEFAULT_CONTAINER" \
                    -o "$DEST/%(playlist_title,playlist)s/%(playlist_index)02d - %(title)s.%(ext)s"
            else
                return 130
            fi
            ;;
        *)
            return 130
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Подменю: Субтитры
# ------------------------------------------------------------------------------
menu_subtitles() {
    local url="$1"

    local choice
    choice=$(select_menu "Выберите язык субтитров >" \
        "🗨  Русские (ru)" \
        "🗨  Английские (en)" \
        "🌐 Все доступные языки" \
        "↩  Назад")

    local lang="ru.*,ru"
    case "$choice" in
        *"Русские"*)    lang="ru.*,ru" ;;
        *"Английские"*) lang="en.*,en" ;;
        *"Все"*)        lang="all" ;;
        *)              return 130 ;;
    esac

    echo -e "${CYAN}Загрузка субтитров...${RESET}"
    yt-dlp \
        "${JS_RUNTIME_ARGS[@]}" \
        --write-subs \
        --write-auto-subs \
        --sub-langs "$lang" \
        --sub-format "srt/vtt" \
        --skip-download \
        -o "$DEST/%(title)s.%(ext)s" \
        "$url"
    local sub_status=$?

    if [ $sub_status -eq 0 ]; then
        echo -e "\n${GREEN}✅ Субтитры сохранены в $DEST${RESET}"
    else
        echo -e "\n${RED}❌ Ошибка при загрузке субтитров (код: $sub_status).${RESET}"
    fi
    return $sub_status
}

# ------------------------------------------------------------------------------
# Надежный поиск последнего сохраненного файла (с поддержкой пробелов и спецсимволов)
# ------------------------------------------------------------------------------
get_latest_file() {
    local target_dir="$1"
    [ ! -d "$target_dir" ] && return 1

    local latest=""
    if [ "$OS_NAME" = "Darwin" ]; then
        latest=$(find "$target_dir" -maxdepth 1 -type f -exec stat -f "%m %N" {} + 2>/dev/null | sort -nr | head -n 1 | cut -d' ' -f2-)
    else
        latest=$(find "$target_dir" -maxdepth 1 -type f -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 1 | cut -d' ' -f2-)
    fi

    if [ -z "$latest" ]; then
        local simple_name
        simple_name=$(find "$target_dir" -maxdepth 1 -type f 2>/dev/null | head -n 1)
        latest="$simple_name"
    fi

    echo "$latest"
}

# ------------------------------------------------------------------------------
# Единый режим диагностики и самоотладки (yt --doctor / yt --diag)
# ------------------------------------------------------------------------------
diagnose_system() {
    local is_interactive="${1:-0}"
    [ "$is_interactive" = "1" ] && clear 2>/dev/null || true

    echo -e "${CYAN}${BOLD}╭──────────────────────────────────────────────────────────╮${RESET}"
    echo -e "${CYAN}${BOLD}│       🩺 ДИАГНОСТИКА ОКРУЖЕНИЯ И САМООТЛАДКА (DOCTOR)    │${RESET}"
    echo -e "${CYAN}${BOLD}╰──────────────────────────────────────────────────────────╯${RESET}\n"

    local issues=()
    local critical_failed=0

    # 1. Проверка командной оболочки Bash
    echo -e "${WHITE}${BOLD}1. Командная оболочка (Bash):${RESET}"
    local bash_ver="${BASH_VERSION:-Unknown}"
    echo "   • Версия Bash        : $bash_ver"
    local bash_major="${BASH_VERSINFO[0]:-0}"
    local bash_minor="${BASH_VERSINFO[1]:-0}"
    if [ "$bash_major" -ge 3 ] && { [ "$bash_major" -gt 3 ] || [ "$bash_minor" -ge 2 ]; }; then
        echo -e "   • Совместимость      : ${GREEN}✓ Поддерживается (Bash 3.2+ / macOS native)${RESET}"
    else
        echo -e "   • Совместимость      : ${RED}✗ Устаревшая версия Bash (< 3.2)${RESET}"
        issues+=("1. Что неисправно: Версия Bash ($bash_ver) ниже минимально необходимой 3.2.\n   2. Причина: Запуск скрипта в устаревшем командном интерпретаторе.\n   3. Как исправить: Запустите через стандартный /bin/bash: /bin/bash yt.sh\n   4. Повторная проверка: yt --doctor")
        critical_failed=1
    fi
    echo ""

    # 2. Аппаратная платформа и операционная система
    echo -e "${WHITE}${BOLD}2. Аппаратная платформа и ОС:${RESET}"
    echo "   • Модель процессора  : $CPU_BRAND"
    echo "   • Архитектура        : $CPU_ARCH"
    local os_ver
    os_ver=$(sw_vers -productVersion 2>/dev/null || echo "Unknown")
    echo "   • Версия системы     : $OS_NAME $os_ver"
    echo ""

    # 3. Загрузчик yt-dlp
    echo -e "${WHITE}${BOLD}3. Загрузчик медиа (yt-dlp):${RESET}"
    if command -v yt-dlp &>/dev/null; then
        local ytdlp_path ytdlp_ver
        ytdlp_path="$(command -v yt-dlp)"
        ytdlp_ver="$(yt-dlp --version 2>/dev/null || echo "Error")"
        echo "   • Путь к бинарнику   : $ytdlp_path"
        echo -e "   • Версия             : ${GREEN}$ytdlp_ver${RESET}"
        if [ -x "$ytdlp_path" ]; then
            echo -e "   • Права запуска      : ${GREEN}✓ Исполняемый${RESET}"
        else
            echo -e "   • Права запуска      : ${RED}✗ Нет прав на исполнение (+x)${RESET}"
            issues+=("1. Что неисправно: Файл yt-dlp не имеет прав на запуск.\n   2. Причина: Не установлены флаги исполнения.\n   3. Как исправить: chmod +x \"$ytdlp_path\"\n   4. Повторная проверка: yt --doctor")
            critical_failed=1
        fi
    else
        echo -e "   • Статус             : ${RED}✗ НЕ УСТАНОВЛЕН!${RESET}"
        issues+=("1. Что неисправно: yt-dlp не найден в системных путях PATH.\n   2. Причина: Утилита не установлена или путь к ней отсутствует в PATH.\n   3. Как исправить: Выполните 'bash install.sh' или 'brew install yt-dlp'.\n   4. Повторная проверка: yt --doctor")
        critical_failed=1
    fi
    echo ""

    # 4. Мультимедиа-движок (FFmpeg и ffprobe)
    echo -e "${WHITE}${BOLD}4. Мультимедиа-движок (FFmpeg & ffprobe):${RESET}"
    if command -v ffmpeg &>/dev/null; then
        local ff_ver
        ff_ver=$(ffmpeg -version 2>/dev/null | head -n 1)
        echo "   • FFmpeg путь        : $(command -v ffmpeg)"
        echo "   • FFmpeg сборка      : $ff_ver"
        if ffmpeg -hwaccels 2>/dev/null | grep -q "videotoolbox"; then
            echo -e "   • VideoToolbox       : ${GREEN}✓ ВКЛЮЧЕНО (Apple Hardware Acceleration активен)${RESET}"
        else
            echo -e "   • VideoToolbox       : ${YELLOW}ℹ️ Software (CPU)${RESET}"
        fi
    else
        echo -e "   • FFmpeg             : ${RED}✗ НЕ УСТАНОВЛЕН!${RESET}"
        issues+=("1. Что неисправно: FFmpeg не найден.\n   2. Причина: Без FFmpeg невозможно объединять аудио/видео 1080p/4K и конвертировать MP3.\n   3. Как исправить: Выполните 'brew install ffmpeg' или 'bash install.sh'.\n   4. Повторная проверка: yt --doctor")
        critical_failed=1
    fi

    if command -v ffprobe &>/dev/null; then
        echo -e "   • ffprobe            : ${GREEN}✓ Доступен ($(command -v ffprobe))${RESET}"
    else
        echo -e "   • ffprobe            : ${YELLOW}⚠️ Не найден (рекомендуется для анализа потоков)${RESET}"
    fi
    echo ""

    # 5. Интерактивный селектор (fzf - опционально)
    echo -e "${WHITE}${BOLD}5. Интерактивный интерфейс (fzf):${RESET}"
    if command -v fzf &>/dev/null; then
        local fzf_ver
        fzf_ver=$(fzf --version 2>/dev/null | head -n 1)
        echo -e "   • Статус             : ${GREEN}✓ Установлен ($fzf_ver)${RESET}"
    else
        echo -e "   • Статус             : ${YELLOW}ℹ️ Не установлен (активен встроенный режим нумерованного меню)${RESET}"
    fi
    echo ""

    # 6. Пакетный менеджер и внешние компоненты
    echo -e "${WHITE}${BOLD}6. Системные компоненты и пакетный менеджер:${RESET}"
    if [ "$OS_NAME" = "Darwin" ]; then
        if command -v brew &>/dev/null; then
            echo -e "   • Homebrew           : ${GREEN}✓ Обнаружен ($(command -v brew))${RESET}"
        else
            echo -e "   • Homebrew           : ${CYAN}ℹ️ Не установлен (используются автономные бинарники)${RESET}"
        fi
        if xcode-select -p &>/dev/null; then
            echo -e "   • Xcode CLI Tools    : ${GREEN}✓ Доступен ($(xcode-select -p 2>/dev/null))${RESET}"
        else
            echo -e "   • Xcode CLI Tools    : ${GRAY}ℹ️ Не установлен (не требуется для работы)${RESET}"
        fi
        command -v osascript &>/dev/null && echo -e "   • Уведомления macOS  : ${GREEN}✓ osascript доступен${RESET}" || echo -e "   • Уведомления macOS  : ${GRAY}✗ недоступно${RESET}"
        command -v afplay &>/dev/null && echo -e "   • Звуки macOS        : ${GREEN}✓ afplay доступен${RESET}" || echo -e "   • Звуки macOS        : ${GRAY}✗ недоступно${RESET}"
        command -v pbpaste &>/dev/null && echo -e "   • Буфер обмена macOS : ${GREEN}✓ pbpaste доступен${RESET}" || echo -e "   • Буфер обмена macOS : ${GRAY}✗ недоступно${RESET}"
    else
        echo -e "   • Linux Package Mgr  : $(command -v apt-get || command -v pacman || command -v dnf || echo 'None')"
    fi
    if command -v node &>/dev/null; then
        echo -e "   • JavaScript Engine  : ${GREEN}✓ Node.js ($(node -v 2>/dev/null)) [Решение JS challenge YouTube]${RESET}"
    elif command -v deno &>/dev/null; then
        echo -e "   • JavaScript Engine  : ${GREEN}✓ Deno [Решение JS challenge YouTube]${RESET}"
    else
        echo -e "   • JavaScript Engine  : ${YELLOW}ℹ️ Не найден (рекомендуется node для максимальной скорости)${RESET}"
    fi
    echo ""

    # 7. Дисковая подсистема и права доступа
    echo -e "${WHITE}${BOLD}7. Дисковая подсистема:${RESET}"
    echo "   • Папка загрузки     : $DEST"
    mkdir -p "$DEST" 2>/dev/null || true
    if [ -w "$DEST" ]; then
        echo -e "   • Права на запись    : ${GREEN}✓ Доступно${RESET}"
        local free_space
        free_space=$(df -h "$DEST" 2>/dev/null | awk 'NR==2 {print $4}')
        echo -e "   • Свободно места     : ${GREEN}$free_space${RESET}"
    else
        echo -e "   • Права на запись    : ${RED}✗ ЗАПРЕЩЕНО! Проверьте права на директорию.${RESET}"
        issues+=("1. Что неисправно: Нет прав на запись в целевую папку: $DEST\n   2. Причина: Директория защищена правами или принадлежит root.\n   3. Как исправить: mkdir -p \"$DEST\" && chmod u+w \"$DEST\"\n   4. Повторная проверка: yt --doctor")
        critical_failed=1
    fi
    echo ""

    # 8. Конфигурация проекта
    echo -e "${WHITE}${BOLD}8. Конфигурация ($CONFIG_FILE):${RESET}"
    if [ -f "$CONFIG_FILE" ]; then
        if bash -n "$CONFIG_FILE" 2>/dev/null; then
            echo -e "   • Синтаксис файла    : ${GREEN}✓ Корректный${RESET}"
        else
            echo -e "   • Синтаксис файла    : ${RED}✗ Ошибка синтаксиса в config.env!${RESET}"
            issues+=("1. Что неисправно: Файл настроек поврежден: $CONFIG_FILE\n   2. Причина: Некорректный синтаксис переменных bash.\n   3. Как исправить: Удалите файл конфигурации 'rm \"$CONFIG_FILE\"' для сброса на дефолты.\n   4. Повторная проверка: yt --doctor")
        fi
    else
        echo -e "   • Файл конфигурации  : ${GRAY}Будет автоматически создан при первом сохранении настроек${RESET}"
    fi
    echo ""

    # Итог проверки
    if [ ${#issues[@]} -eq 0 ]; then
        echo -e "${GREEN}${BOLD}═════════════════════════════════════════════════════════════${RESET}"
        echo -e "${GREEN}${BOLD}✅ Все обязательные компоненты и окружение настроены идеально!${RESET}"
        echo -e "${GREEN}${BOLD}═════════════════════════════════════════════════════════════${RESET}\n"
    else
        echo -e "${RED}${BOLD}═════════════════════════════════════════════════════════════${RESET}"
        echo -e "${RED}${BOLD}⚠️ ОБНАРУЖЕНЫ ПРОБЛЕМЫ (${#issues[@]}):${RESET}\n"
        local idx=1
        for issue in "${issues[@]}"; do
            echo -e "${YELLOW}[Проблема #$idx]${RESET}"
            echo -e "$issue"
            echo ""
            idx=$((idx + 1))
        done
        echo -e "${CYAN}Команда для повторного аудита: ${BOLD}yt --doctor${RESET}"
        echo -e "${RED}${BOLD}═════════════════════════════════════════════════════════════${RESET}\n"
    fi

    if [ "$is_interactive" = "1" ]; then
        local _dummy=""
        read -r -p "Нажмите Enter для возврата в меню..." _dummy
    fi

    return $critical_failed
}

# ------------------------------------------------------------------------------
# Подменю: Настройки
# ------------------------------------------------------------------------------
menu_settings() {
    while true; do
        local meta_status="ВКЛ"
        [ "$EMBED_METADATA" != "true" ] && meta_status="ВЫКЛ"

        local thumb_status="ВКЛ"
        [ "$EMBED_THUMBNAIL" != "true" ] && thumb_status="ВЫКЛ"

        local apple_status="ВКЛ (H.264/AAC)"
        [ "$APPLE_COMPAT_MODE" != "true" ] && apple_status="ВЫКЛ (Любой)"

        local sound_status="ВКЛ"
        [ "$SOUND_ENABLED" != "true" ] && sound_status="ВЫКЛ"

        local choice
        choice=$(select_menu "Настройки yt (macOS Edition) >" \
            "📁 Папка сохранения : $DEST" \
            "◻  Вшивать обложку : [$thumb_status]" \
            "🏷  Вшивать метаданные : [$meta_status]" \
            "  Режим совместимости с Mac : [$apple_status]" \
            "🍪 Куки браузера для закрытых видео : [$COOKIE_BROWSER]" \
            "⚡ Потоков скачивания : [$CONCURRENT_FRAGMENTS]" \
            "🔔 Звук завершения : [$sound_status]" \
            "🩺 Диагностика Mac и VideoToolbox (Doctor)" \
            "🔄 Обновить yt-dlp" \
            "↩  Назад в главное меню")

        case "$choice" in
            *"Папка сохранения"*)
                echo ""
                echo -e "Текущая папка: ${CYAN}$DEST${RESET}"
                local new_dest=""
                read -r -p "Введите новый путь: " new_dest
                if [ -n "$new_dest" ]; then
                    new_dest="${new_dest/#\~/$HOME}"
                    new_dest="${new_dest%/}"
                    if mkdir -p "$new_dest" 2>/dev/null; then
                        DEST="$new_dest"
                        save_config
                        echo -e "${GREEN}✓ Папка обновлена!${RESET}"
                    else
                        echo -e "${RED}❌ Не удалось создать указанную папку.${RESET}"
                    fi
                    sleep 1
                fi
                ;;
            *"Вшивать обложку"*)
                [ "$EMBED_THUMBNAIL" = "true" ] && EMBED_THUMBNAIL="false" || EMBED_THUMBNAIL="true"
                save_config
                ;;
            *"Вшивать метаданные"*)
                [ "$EMBED_METADATA" = "true" ] && EMBED_METADATA="false" || EMBED_METADATA="true"
                save_config
                ;;
            *"Режим совместимости"*)
                [ "$APPLE_COMPAT_MODE" = "true" ] && APPLE_COMPAT_MODE="false" || APPLE_COMPAT_MODE="true"
                save_config
                ;;
            *"Куки браузера"*)
                local b_choice
                b_choice=$(select_menu "Выберите браузер для чтения cookies >" "none (Без куков)" "safari" "chrome" "firefox")
                case "$b_choice" in
                    *"safari"*)  COOKIE_BROWSER="safari" ;;
                    *"chrome"*)  COOKIE_BROWSER="chrome" ;;
                    *"firefox"*) COOKIE_BROWSER="firefox" ;;
                    *)           COOKIE_BROWSER="none" ;;
                esac
                save_config
                ;;
            *"Потоков скачивания"*)
                local frag_choice
                frag_choice=$(select_menu "Количество параллельных потоков >" "4" "8 (Рекомендуется для M1/M2/M3/M4)" "16 (Гигабитный интернет)" "2")
                case "$frag_choice" in
                    *"4"*)  CONCURRENT_FRAGMENTS="4" ;;
                    *"8"*)  CONCURRENT_FRAGMENTS="8" ;;
                    *"16"*) CONCURRENT_FRAGMENTS="16" ;;
                    *"2"*)  CONCURRENT_FRAGMENTS="2" ;;
                esac
                save_config
                ;;
            *"Звук завершения"*)
                [ "$SOUND_ENABLED" = "true" ] && SOUND_ENABLED="false" || SOUND_ENABLED="true"
                save_config
                ;;
            *"Диагностика"*)
                diagnose_system 1
                ;;
            *"Обновить yt-dlp"*)
                echo -e "\n${CYAN}Проверка обновлений yt-dlp...${RESET}"
                if command -v brew &>/dev/null; then
                    brew upgrade yt-dlp || yt-dlp -U || true
                else
                    yt-dlp -U || true
                fi
                echo -e "${GREEN}✓ Проверка обновлений завершена!${RESET}"
                sleep 2
                ;;
            *)
                break
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# Действия после загрузки
# ------------------------------------------------------------------------------
post_download_menu() {
    local status="${1:-0}"
    local choice

    if [ "$status" -eq 0 ]; then
        choice=$(select_menu "Что сделать дальше? >" \
            "⏵  Загрузить ещё одно медиа" \
            "📁 Открыть папку в Finder" \
            "▶  Воспроизвести скачанный файл" \
            "⎋  Выйти")
    else
        choice=$(select_menu "Что сделать дальше? >" \
            "🔄 Попробовать ещё раз" \
            "📁 Открыть папку в Finder" \
            "⎋  Выйти")
    fi

    case "$choice" in
        *"ещё одно"*|*"Попробовать"*)
            return 0
            ;;
        *"Finder"*)
            open "$DEST" 2>/dev/null || xdg-open "$DEST" 2>/dev/null || true
            post_download_menu "$status"
            ;;
        *"Воспроизвести"*)
            local latest_file
            latest_file="$(get_latest_file "$DEST")"
            if [ -n "$latest_file" ] && [ -f "$latest_file" ]; then
                open "$latest_file" 2>/dev/null || xdg-open "$latest_file" 2>/dev/null || true
            else
                echo -e "${YELLOW}Файл не найден.${RESET}"
            fi
            post_download_menu "$status"
            ;;
        *)
            echo -e "${GREEN}До встречи! 👋${RESET}"
            exit 0
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Главный цикл программы
# ------------------------------------------------------------------------------
main() {
    local initial_url=""

    # Обработка аргументов командной строки
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                show_banner
                echo -e "${BOLD}Использование:${RESET}"
                echo "  yt                       # Интерактивное меню (с автоподхватом из буфера macOS)"
                echo "  yt <URL>                 # Запуск сразу с указанной ссылкой"
                echo "  yt --doctor | --diag     # Диагностика системы, VideoToolbox и окружения"
                echo "  yt -h | --help           # Показать эту справку"
                echo ""
                echo -e "${BOLD}Особенности macOS:${RESET}"
                echo "  • Аппаратное ускорение VideoToolbox на процессорах Apple Silicon (M1/M2/M3/M4)"
                echo "  • Форсирование FastStart (-movflags +faststart) для мгновенного QuickLook в Finder"
                echo "  • Нативные звуки и баннеры уведомлений macOS"
                echo "  • Поддержка Safari/Chrome куков для загрузки приватных видео"
                exit 0
                ;;
            --doctor|--diag)
                load_config
                diagnose_system 0
                exit $?
                ;;
            --debug|-d)
                DEBUG_MODE="true"
                shift
                ;;
            *)
                if [ -z "$initial_url" ]; then
                    initial_url="$1"
                fi
                shift
                ;;
        esac
    done

    check_dependencies
    load_config

    while true; do
        show_banner

        local URL=""
        local url_status=0
        if [ -n "$initial_url" ]; then
            URL="$initial_url"
            initial_url=""
        else
            URL=$(get_url)
            url_status=$?
        fi

        # Если пользователь явно нажал Esc или ввел 'q'/'exit'
        if [ $url_status -eq 130 ]; then
            echo -e "${GREEN}До встречи! 👋${RESET}"
            exit 0
        fi

        URL=$(echo "$URL" | tr -d '\r\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

        # Если ссылка не указана (например, пользователь нажал Enter без вставки ссылки)
        if [ -z "$URL" ]; then
            echo -e "${YELLOW}⚠️ Ссылка не указана. Вставьте ссылку на медиа или нажмите Esc для выхода.${RESET}"
            sleep 1.5
            continue
        fi

        fetch_and_display_info "$URL"

        local ACTION
        ACTION=$(select_menu "Выберите действие для медиа >" \
            "⏵  Максимальное качество (Best Video + Audio • $DEFAULT_CONTAINER)" \
            "♫  Сразу MP3 (Макс. битрейт 320k + обложка)" \
            "⤓  Минимальный вес (Экономный режим / быстрый просмотр)" \
            "⌘  Выбрать точное разрешение (4K, 2K, 1080p, 720p, 480p...)" \
            "⌥  Другие аудиоформаты (M4A, FLAC, WAV, OPUS...)" \
            "✄  Скачать конкретный отрезок (по времени)" \
            "☰  Загрузить плейлист (весь или диапазон)" \
            "⌕  Показать форматы и выбрать ID вручную" \
            "🗨  Скачать субтитры" \
            "◻  Скачать только обложку" \
            "⚙  Настройки и конфигурация" \
            "⎋  Выход")

        local thumb_args=()
        if [ "$EMBED_THUMBNAIL" = "true" ]; then
            thumb_args=("--embed-thumbnail" "--convert-thumbnails" "jpg")
        fi

        local last_status=0
        local download_attempted=false

        case "$ACTION" in
            *"Максимальное качество"*)
                download_attempted=true
                execute_download "$URL" \
                    --no-playlist \
                    -f "bestvideo+bestaudio/best" \
                    --merge-output-format "$DEFAULT_CONTAINER" \
                    "${thumb_args[@]}" \
                    -o "$DEST/%(title)s.%(ext)s"
                last_status=$?
                ;;

            *"Сразу MP3"*)
                download_attempted=true
                execute_download "$URL" \
                    --no-playlist \
                    -x \
                    --audio-format mp3 \
                    --audio-quality 0 \
                    "${thumb_args[@]}" \
                    -o "$DEST/%(title)s.%(ext)s"
                last_status=$?
                ;;

            *"Минимальный вес"*)
                download_attempted=true
                execute_download "$URL" \
                    --no-playlist \
                    -f "worstvideo+worstaudio/worst" \
                    --merge-output-format "$DEFAULT_CONTAINER" \
                    -o "$DEST/%(title)s.%(ext)s"
                last_status=$?
                ;;

            *"Выбрать точное разрешение"*)
                menu_resolution "$URL"
                last_status=$?
                [ $last_status -eq 130 ] && continue
                download_attempted=true
                ;;

            *"Другие аудиоформаты"*)
                menu_audio "$URL"
                last_status=$?
                [ $last_status -eq 130 ] && continue
                download_attempted=true
                ;;

            *"Скачать конкретный отрезок"*)
                menu_timeslice "$URL"
                last_status=$?
                [ $last_status -eq 130 ] && continue
                download_attempted=true
                ;;

            *"Загрузить плейлист"*)
                menu_playlist "$URL"
                last_status=$?
                [ $last_status -eq 130 ] && continue
                download_attempted=true
                ;;

            *"Показать форматы"*)
                echo ""
                yt-dlp "${JS_RUNTIME_ARGS[@]}" -F "$URL"
                echo ""
                local custom_format=""
                read -r -p "Введите ID формата (например, 137+140 или best, Enter для отмены): " custom_format
                custom_format=$(echo "$custom_format" | tr -d ' ')
                if [ -n "$custom_format" ]; then
                    download_attempted=true
                    execute_download "$URL" \
                        -f "$custom_format" \
                        -o "$DEST/%(title)s.%(ext)s"
                    last_status=$?
                else
                    continue
                fi
                ;;

            *"Скачать субтитры"*)
                menu_subtitles "$URL"
                last_status=$?
                [ $last_status -eq 130 ] && continue
                download_attempted=true
                ;;

            *"только обложку"*)
                download_attempted=true
                echo -e "${CYAN}Загрузка обложки...${RESET}"
                yt-dlp \
                    "${JS_RUNTIME_ARGS[@]}" \
                    --write-thumbnail \
                    --skip-download \
                    --convert-thumbnails jpg \
                    -o "$DEST/%(title)s.%(ext)s" \
                    "$URL"
                last_status=$?
                if [ $last_status -eq 0 ]; then
                    echo -e "\n${GREEN}✅ Обложка сохранена в $DEST${RESET}"
                fi
                ;;

            *"Настройки"*)
                menu_settings
                continue
                ;;

            *)
                echo -e "${GREEN}До встречи! 👋${RESET}"
                exit 0
                ;;
        esac

        if [ "$download_attempted" = "true" ]; then
            post_download_menu "$last_status"
        fi
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
