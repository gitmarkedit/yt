#!/usr/bin/env bash
# ==============================================================================
#  ⚡ YT-DLP ULTIMATE DOWNLOADER
#  Интерактивный, быстрый и стильный скрипт загрузки медиа
# ==============================================================================

# Определение директории скрипта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Совместимость с macOS и путями (включая локальную папку bin/ внутри проекта)
export PATH="$SCRIPT_DIR/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$HOME/.local/bin:$PATH"

# Настройки по умолчанию и пути
CONFIG_DIR="$HOME/.config/yt-downloader"
CONFIG_FILE="$CONFIG_DIR/config.env"
DEFAULT_DEST="$HOME/Downloads/Media"

DEST="$DEFAULT_DEST"
EMBED_METADATA="true"
EMBED_THUMBNAIL="true"
DEFAULT_CONTAINER="mp4"
CONCURRENT_FRAGMENTS="4"
NOTIFY_SOUND="Glass"

# ------------------------------------------------------------------------------
# Стили и Цвета (ANSI)
# ------------------------------------------------------------------------------
if [ -t 1 ]; then
    BOLD='\033[1m'
    DIM='\033[2m'
    ITALIC='\033[3m'
    RED='\033[38;5;196m'
    GREEN='\033[38;5;46m'
    YELLOW='\033[38;5;220m'
    BLUE='\033[38;5;39m'
    MAGENTA='\033[38;5;201m'
    CYAN='\033[38;5;51m'
    WHITE='\033[38;5;231m'
    GRAY='\033[38;5;244m'
    RESET='\033[0m'
else
    BOLD=''
    DIM=''
    ITALIC=''
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    MAGENTA=''
    CYAN=''
    WHITE=''
    GRAY=''
    RESET=''
fi

# ------------------------------------------------------------------------------
# Конфигурация
# ------------------------------------------------------------------------------
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck disable=SC1090
        source "$CONFIG_FILE" 2>/dev/null || true
    fi
    mkdir -p "$DEST" 2>/dev/null || true
}

save_config() {
    mkdir -p "$CONFIG_DIR" 2>/dev/null || true
    cat > "$CONFIG_FILE" <<EOF
# YT-DLP Ultimate Downloader Configuration
DEST="$DEST"
EMBED_METADATA="$EMBED_METADATA"
EMBED_THUMBNAIL="$EMBED_THUMBNAIL"
DEFAULT_CONTAINER="$DEFAULT_CONTAINER"
CONCURRENT_FRAGMENTS="$CONCURRENT_FRAGMENTS"
EOF
}

# ------------------------------------------------------------------------------
# Проверка зависимостей с автоматической установкой
# ------------------------------------------------------------------------------
check_dependencies() {
    local missing=()
    command -v yt-dlp &>/dev/null || missing+=("yt-dlp")
    command -v ffmpeg &>/dev/null || missing+=("ffmpeg")

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}${BOLD}❌ На вашем компьютере не найдены обязательные утилиты:${RESET} ${missing[*]}"
        echo -e "${YELLOW}Запустить автоматическую установку всех зависимостей прямо сейчас? [Y/n]${RESET}"
        read -p "> " auto_install
        auto_install=${auto_install:-y}

        if [[ "$auto_install" =~ ^[YyДд] ]]; then
            if [ -f "$SCRIPT_DIR/install.sh" ]; then
                bash "$SCRIPT_DIR/install.sh"
            else
                if command -v brew &>/dev/null; then
                    brew install "${missing[@]}" fzf || true
                else
                    echo -e "${RED}Установите Homebrew или запустите install.sh вручную.${RESET}"
                    exit 1
                fi
            fi
            
            # Повторная проверка
            export PATH="$SCRIPT_DIR/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$HOME/.local/bin:$PATH"
            if ! command -v yt-dlp &>/dev/null; then
                echo -e "${RED}Не удалось автоматически запустить yt-dlp. Попробуйте перезапустить терминал.${RESET}"
                exit 1
            fi
        else
            echo -e "${YELLOW}Для работы скрипта требуются yt-dlp и ffmpeg. Установка отменена.${RESET}"
            exit 1
        fi
    fi
}

# ------------------------------------------------------------------------------
# Анимации: Спиннер и Очистка
# ------------------------------------------------------------------------------
SPINNER_PID=""

start_spinner() {
    local message="$1"
    tput civis 2>/dev/null || true
    (
        local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
        local i=0
        while true; do
            printf "\r${CYAN}%s${RESET} %s" "${frames[i]}" "$message"
            i=$(( (i + 1) % 10 ))
            sleep 0.08
        done
    ) &
    SPINNER_PID=$!
}

stop_spinner() {
    if [ -n "$SPINNER_PID" ] && kill -0 "$SPINNER_PID" 2>/dev/null; then
        kill "$SPINNER_PID" 2>/dev/null
        wait "$SPINNER_PID" 2>/dev/null || true
    fi
    SPINNER_PID=""
    tput cnorm 2>/dev/null || true
    printf "\r\033[K"
}

cleanup() {
    stop_spinner
    tput cnorm 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# ------------------------------------------------------------------------------
# Визуальные элементы (Баннер, Карточка видео)
# ------------------------------------------------------------------------------
show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << "EOF"
   ╭─────────────────────────────────────────────────────────────╮
   │           ⚡  Y T - D L P   U L T I M A T E  ⚡             │
   │       Интерактивный медиа-загрузчик нового поколения       │
   ╰─────────────────────────────────────────────────────────────╯
EOF
    echo -e "${RESET}"
}

fetch_and_display_info() {
    local url="$1"
    start_spinner "Получение информации о медиа..."

    local meta
    meta=$(yt-dlp \
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
        echo -e "${BLUE}│${RESET} ${BOLD}Название:${RESET}  $title"
        [ -n "$uploader" ] && [ "$uploader" != "NA" ] && \
        echo -e "${BLUE}│${RESET} ${DIM}Автор:${RESET}     $uploader"
        [ -n "$duration" ] && [ "$duration" != "NA" ] && \
        echo -e "${BLUE}│${RESET} ${DIM}Время:${RESET}     $duration"
        [ -n "$views" ] && [ "$views" != "NA" ] && \
        echo -e "${BLUE}│${RESET} ${DIM}Просмотры:${RESET} $views"
        echo -e "${BLUE}╰───────────────────────────────────────────────────────────────╯${RESET}"
        echo ""
    fi
}

# ------------------------------------------------------------------------------
# Меню выбора (FZF с фоллбэком на чистый Bash)
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
            --color="prompt:cyan,pointer:magenta,marker:green,header:yellow,border:blue"
    else
        echo -e "\n${CYAN}${BOLD}$prompt${RESET}"
        local i=1
        for opt in "${options[@]}"; do
            printf "  ${YELLOW}%2d)${RESET} %s\n" "$i" "$opt"
            i=$((i + 1))
        done
        while true; do
            read -p "Выберите номер [1-${#options[@]}]: " choice
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
                echo "${options[$((choice - 1))]}"
                return 0
            fi
            echo -e "${RED}Неверный ввод, повторите попытку.${RESET}"
        done
    fi
}

# ------------------------------------------------------------------------------
# Получение URL (Аргумент, буфер обмена или ввод)
# ------------------------------------------------------------------------------
get_url() {
    local input_url="$1"
    if [ -n "$input_url" ]; then
        echo "$input_url"
        return 0
    fi

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
            prompt_list="📋 Использовать из буфера: $clip_url"
        fi

        local res
        res=$(printf "%s\n" "$prompt_list" | fzf \
            --print-query \
            --height=7 \
            --layout=reverse \
            --border=rounded \
            --prompt="URL > " \
            --header="Вставьте ссылку и нажмите Enter (Esc - выход):" \
            --color="prompt:cyan,pointer:magenta,header:yellow,border:blue")

        local exit_code=$?
        [ $exit_code -ne 0 ] && return 1

        local typed_query selected_item
        typed_query=$(echo "$res" | sed -n '1p')
        selected_item=$(echo "$res" | sed -n '2p')

        if [[ "$selected_item" =~ ^📋\ Использовать\ из\ буфера:\ (https?://.+) ]]; then
            echo "${BASH_REMATCH[1]}"
        elif [ -n "$typed_query" ]; then
            echo "$typed_query"
        elif [ -n "$clip_url" ]; then
            echo "$clip_url"
        fi
    else
        if [ -n "$clip_url" ]; then
            echo -e "${CYAN}Найдена ссылка в буфере обмена:${RESET} $clip_url"
            read -p "Использовать её? [Y/n]: " use_clip
            use_clip=${use_clip:-y}
            if [[ "$use_clip" =~ ^[YyДд] ]]; then
                echo "$clip_url"
                return 0
            fi
        fi
        read -p "Вставьте ссылку на видео/аудио: " manual_url
        echo "$manual_url"
    fi
}

# ------------------------------------------------------------------------------
# Запуск загрузки с общими параметрами
# ------------------------------------------------------------------------------
execute_download() {
    local url="$1"
    shift
    local extra_args=("$@")

    local common_args=(
        "--no-mtime"
        "-N" "$CONCURRENT_FRAGMENTS"
        "--console-title"
    )

    if [ "$EMBED_METADATA" = "true" ]; then
        common_args+=("--embed-metadata" "--embed-chapters")
    fi

    echo -e "${CYAN}🚀 Запуск загрузки...${RESET}\n"

    yt-dlp "${common_args[@]}" "${extra_args[@]}" "$url"
    local dl_status=$?

    echo ""
    if [ $dl_status -eq 0 ]; then
        echo -e "${GREEN}${BOLD}╭─────────────────────────────────────────────────────────────╮${RESET}"
        echo -e "${GREEN}${BOLD}│  ✅ Загрузка успешно завершена!                             │${RESET}"
        echo -e "${GREEN}│${RESET}  📁 Папка: ${CYAN}$DEST${RESET}"
        echo -e "${GREEN}${BOLD}╰─────────────────────────────────────────────────────────────╯${RESET}"

        # Системное уведомление macOS
        if command -v osascript &>/dev/null; then
            osascript -e "display notification \"Файл сохранён в $DEST\" with title \"Загрузка завершена!\" sound name \"$NOTIFY_SOUND\"" 2>/dev/null || true
        fi
        return 0
    else
        echo -e "${RED}${BOLD}❌ Во время загрузки произошла ошибка (код: $dl_status).${RESET}"
        return $dl_status
    fi
}

# ------------------------------------------------------------------------------
# Подменю: Выбор разрешения видео
# ------------------------------------------------------------------------------
menu_resolution() {
    local url="$1"

    local choice
    choice=$(select_menu "Выберите разрешение видео >" \
        "🌟 4K Ultra HD (2160p)" \
        "💎 2K Quad HD (1440p)" \
        "🎬 Full HD (1080p - Оптимально)" \
        "📱 HD (720p - Мобильное)" \
        "📉 SD (480p)" \
        "🪶 360p (Экономный трафик)" \
        "↩️  Назад")

    local height_limit=""
    case "$choice" in
        *"2160p"*) height_limit="2160" ;;
        *"1440p"*) height_limit="1440" ;;
        *"1080p"*) height_limit="1080" ;;
        *"720p"*)  height_limit="720" ;;
        *"480p"*)  height_limit="480" ;;
        *"360p"*)  height_limit="360" ;;
        *) return 0 ;;
    esac

    local container_choice
    container_choice=$(select_menu "Выберите контейнер/формат >" \
        "MP4 (Универсальный, рекомендуется)" \
        "MKV (Поддержка любых дорожек и субтитров)" \
        "WEBM (Оригинал Google/VP9)")

    local container="mp4"
    case "$container_choice" in
        *"MKV"*)  container="mkv" ;;
        *"WEBM"*) container="webm" ;;
        *)        container="mp4" ;;
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
        "🎶 MP3 (Максимальный битрейт ~320k, обложка, теги)" \
        "🍏 M4A / AAC (Apple нативный формат без пересжатия)" \
        "🎼 FLAC (Lossless студийный звук)" \
        "🎧 WAV (Несжатый звук)" \
        "📻 OPUS (Максимальное качество при малом весе)" \
        "⚡ Оригинальный аудиопоток без перекодирования (Быстро)" \
        "↩️  Назад")

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
        *"Оригинальный"*)
            execute_download "$url" \
                --no-playlist \
                -x \
                "${thumb_args[@]}" \
                -o "$DEST/%(title)s.%(ext)s"
            ;;
        *)
            return 0
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Подменю: Скачивание фрагмента / отрезка по времени
# ------------------------------------------------------------------------------
menu_timeslice() {
    local url="$1"
    echo ""
    echo -e "${CYAN}${BOLD}✂️ Скачивание конкретного отрезка видео/аудио${RESET}"
    echo -e "${DIM}Примеры интервалов: 01:15-02:30 или 00:00:10-00:01:45${RESET}"
    read -p "Введите начало и конец (ЧЧ:ММ:СС-ЧЧ:ММ:СС): " time_range

    if [ -z "$time_range" ]; then
        echo -e "${YELLOW}Интервал не введён. Возврат в меню.${RESET}"
        sleep 1
        return 0
    fi

    local slice_type
    slice_type=$(select_menu "В каком формате скачать фрагмент? >" \
        "🎬 Видео (MP4 Full HD)" \
        "🎵 Аудио (MP3 320k)" \
        "↩️  Отмена")

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
            return 0
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
        "📥 Скачать весь плейлист целиком" \
        "🔢 Выбрать диапазон видео (например: 1-10 или 2,5,8)" \
        "↩️  Назад")

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
            read -p "Введите диапазон (например, 1-5 или 1,3,7): " range
            if [ -n "$range" ]; then
                execute_download "$url" \
                    --yes-playlist \
                    --playlist-items "$range" \
                    -f "bestvideo+bestaudio/best" \
                    --merge-output-format "$DEFAULT_CONTAINER" \
                    -o "$DEST/%(playlist_title,playlist)s/%(playlist_index)02d - %(title)s.%(ext)s"
            fi
            ;;
        *)
            return 0
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
        "🇷🇺 Русские (ru)" \
        "🇬🇧 Английские (en)" \
        "🌐 Все доступные языки" \
        "↩️  Назад")

    local lang="ru.*,ru"
    case "$choice" in
        *"Русские"*)   lang="ru.*,ru" ;;
        *"Английские"*) lang="en.*,en" ;;
        *"Все"*)        lang="all" ;;
        *) return 0 ;;
    esac

    echo -e "${CYAN}Загрузка субтитров...${RESET}"
    yt-dlp \
        --write-subs \
        --write-auto-subs \
        --sub-langs "$lang" \
        --sub-format "srt/vtt" \
        --skip-download \
        -o "$DEST/%(title)s.%(ext)s" \
        "$url"
    
    echo -e "\n${GREEN}✅ Субтитры сохранены в $DEST${RESET}"
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

        local choice
        choice=$(select_menu "Настройки yt-downloader >" \
            "📁 Папка сохранения : $DEST" \
            "🖼️  Вшивать обложку : [$thumb_status]" \
            "🏷️  Вшивать метаданные : [$meta_status]" \
            "🎞️  Контейнер видео : [$DEFAULT_CONTAINER]" \
            "⚡ Потоков скачивания : [$CONCURRENT_FRAGMENTS]" \
            "🔄 Обновить yt-dlp до последней версии" \
            "↩️  Назад в главное меню")

        case "$choice" in
            *"Папка сохранения"*)
                echo ""
                echo -e "Текущая папка: ${CYAN}$DEST${RESET}"
                read -p "Введите новый путь: " new_dest
                if [ -n "$new_dest" ]; then
                    new_dest="${new_dest/#\~/$HOME}"
                    mkdir -p "$new_dest" 2>/dev/null && DEST="$new_dest"
                    save_config
                    echo -e "${GREEN}✓ Папка обновлена!${RESET}"
                    sleep 1
                fi
                ;;
            *"Вшивать обложку"*)
                if [ "$EMBED_THUMBNAIL" = "true" ]; then
                    EMBED_THUMBNAIL="false"
                else
                    EMBED_THUMBNAIL="true"
                fi
                save_config
                ;;
            *"Вшивать метаданные"*)
                if [ "$EMBED_METADATA" = "true" ]; then
                    EMBED_METADATA="false"
                else
                    EMBED_METADATA="true"
                fi
                save_config
                ;;
            *"Контейнер видео"*)
                local cont_choice
                cont_choice=$(select_menu "Выберите контейнер по умолчанию >" "mp4" "mkv" "webm")
                if [ -n "$cont_choice" ]; then
                    DEFAULT_CONTAINER="$cont_choice"
                    save_config
                fi
                ;;
            *"Потоков скачивания"*)
                local frag_choice
                frag_choice=$(select_menu "Количество одновременных фрагментов >" "2" "4 (Рекомендуется)" "8 (Быстрый интернет)" "16")
                case "$frag_choice" in
                    *"2"*)  CONCURRENT_FRAGMENTS="2" ;;
                    *"4"*)  CONCURRENT_FRAGMENTS="4" ;;
                    *"8"*)  CONCURRENT_FRAGMENTS="8" ;;
                    *"16"*) CONCURRENT_FRAGMENTS="16" ;;
                esac
                save_config
                ;;
            *"Обновить yt-dlp"*)
                echo -e "\n${CYAN}Проверка обновлений yt-dlp...${RESET}"
                if command -v brew &>/dev/null; then
                    brew upgrade yt-dlp || yt-dlp -U
                else
                    yt-dlp -U
                fi
                echo -e "${GREEN}✓ Готово!${RESET}"
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
            "🔄 Загрузить ещё одно медиа" \
            "📂 Открыть папку в Finder" \
            "🎬 Воспроизвести скачанный файл" \
            "❌ Выйти")
    else
        choice=$(select_menu "Что сделать дальше? >" \
            "🔄 Попробовать ещё раз" \
            "📂 Открыть папку в Finder" \
            "❌ Выйти")
    fi

    case "$choice" in
        *"ещё одно"*|*"Попробовать"*)
            return 0
            ;;
        *"Finder"*)
            open "$DEST"
            post_download_menu "$status"
            ;;
        *"Воспроизвести"*)
            local latest_file
            latest_file=$(ls -t "$DEST" 2>/dev/null | head -n 1)
            if [ -n "$latest_file" ] && [ -f "$DEST/$latest_file" ]; then
                open "$DEST/$latest_file"
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
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        show_banner
        echo -e "${BOLD}Использование:${RESET}"
        echo "  ./yt.sh                  # Запуск в интерактивном режиме (FZF / меню)"
        echo "  ./yt.sh <URL>            # Запуск сразу с указанной ссылкой"
        echo "  ./yt.sh -h | --help      # Показать справку"
        echo ""
        echo -e "${BOLD}Особенности:${RESET}"
        echo "  • Быстрые пресеты: Максимальное качество, 1080p, Минимальное качество, Сразу MP3"
        echo "  • Выбор качества вручную: 4K, 2K, 1080p, 720p, 480p, 360p"
        echo "  • Аудио форматы: MP3 (320k), M4A, FLAC, WAV, OPUS, Direct Stream"
        echo "  • ✂️ Скачивание конкретных отрезков (Time-slice)"
        echo "  • Автоматический захват ссылки из буфера обмена (macOS)"
        echo "  • Вшивание метаданных, глав (chapters) и обложек высокого разрешения"
        echo "  • Нативные уведомления macOS со звуком"
        echo "  • Сохранение настроек в ~/.config/yt-downloader/config.env"
        exit 0
    fi

    check_dependencies
    load_config

    local initial_url="$1"

    while true; do
        show_banner

        local URL=""
        if [ -n "$initial_url" ]; then
            URL="$initial_url"
            initial_url="" # Сбрасываем для следующей итерации
        else
            URL=$(get_url)
        fi

        if [ -z "$URL" ]; then
            echo -e "${YELLOW}Завершение работы.${RESET}"
            exit 0
        fi

        # Отображение информации о видео
        fetch_and_display_info "$URL"

        # Главное меню выбора действия
        local ACTION
        ACTION=$(select_menu "Выберите действие для медиа >" \
            "🚀 Максимальное качество (Best Video + Audio • $DEFAULT_CONTAINER)" \
            "🎵 Сразу MP3 (Макс. битрейт 320k + обложка)" \
            "🪶 Минимальный вес (Экономный режим / быстрый просмотр)" \
            "🎯 Выбрать точное разрешение (4K, 2K, 1080p, 720p, 480p...)" \
            "🎧 Другие аудиоформаты (M4A, FLAC, WAV, OPUS...)" \
            "✂️  Скачать конкретный отрезок (по времени)" \
            "📜 Загрузить плейлист (весь или диапазон)" \
            "📋 Показать форматы и выбрать ID вручную" \
            "💬 Скачать субтитры" \
            "🖼️  Скачать только обложку" \
            "⚙️  Настройки и конфигурация" \
            "❌ Выход")

        local thumb_args=()
        if [ "$EMBED_THUMBNAIL" = "true" ]; then
            thumb_args=("--embed-thumbnail" "--convert-thumbnails" "jpg")
        fi

        local last_status=0

        case "$ACTION" in
            *"Максимальное качество"*)
                execute_download "$URL" \
                    --no-playlist \
                    -f "bestvideo+bestaudio/best" \
                    --merge-output-format "$DEFAULT_CONTAINER" \
                    "${thumb_args[@]}" \
                    -o "$DEST/%(title)s.%(ext)s"
                last_status=$?
                ;;

            *"Сразу MP3"*)
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
                ;;

            *"Другие аудиоформаты"*)
                menu_audio "$URL"
                last_status=$?
                ;;

            *"Скачать конкретный отрезок"*)
                menu_timeslice "$URL"
                last_status=$?
                ;;

            *"Загрузить плейлист"*)
                menu_playlist "$URL"
                last_status=$?
                ;;

            *"Показать форматы"*)
                echo ""
                yt-dlp -F "$URL"
                echo ""
                read -p "Введите ID формата (например, 137+140 или best): " custom_format
                if [ -n "$custom_format" ]; then
                    execute_download "$URL" \
                        -f "$custom_format" \
                        -o "$DEST/%(title)s.%(ext)s"
                    last_status=$?
                fi
                ;;

            *"Скачать субтитры"*)
                menu_subtitles "$URL"
                last_status=$?
                ;;

            *"только обложку"*)
                echo -e "${CYAN}Загрузка обложки...${RESET}"
                yt-dlp \
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
                echo -e "${GREEN}Выход. До встречи! 👋${RESET}"
                exit 0
                ;;
        esac

        post_download_menu "$last_status"
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
