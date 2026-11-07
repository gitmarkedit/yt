#!/usr/bin/env bash
# ==============================================================================
#  ⚡ Установщик yt (macOS Edition)
#  Оптимизировано для macOS (Apple Silicon M1/M2/M3/M4 & Intel) и Linux
# ==============================================================================

# Определение директории скрипта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"
mkdir -p "$BIN_DIR" 2>/dev/null || true

# Автоматическое подключение стандартных путей Homebrew
export PATH="$BIN_DIR:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:$HOME/.local/bin:$PATH"

# Цвета
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
GRAY='\033[38;5;244m'
RESET='\033[0m'

clear 2>/dev/null || true
echo -e "${CYAN}${BOLD}"
cat << "EOF"
   ╭──────────────────────────────────────────────────────────╮
   │                    yt (macOS Edition)                    │
   │    Высокоскоростная загрузка с аппаратным медиа-ядром    │
   ╰──────────────────────────────────────────────────────────╯
EOF
echo -e "${RESET}"

echo -e "${YELLOW}🔍 Шаг 1: Проверка аппаратной платформы...${RESET}"
OS="$(uname -s 2>/dev/null || echo "Unknown")"
ARCH="$(uname -m 2>/dev/null || echo "Unknown")"
CPU_MODEL="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "$ARCH")"

echo -e "   • Платформа : ${GREEN}$OS ($ARCH)${RESET}"
echo -e "   • Процессор : ${CYAN}$CPU_MODEL${RESET}\n"

# Проверка интернет-соединения
check_internet() {
    curl -fs --head --connect-timeout 4 https://github.com >/dev/null 2>&1 || \
    curl -fs --head --connect-timeout 4 https://raw.githubusercontent.com >/dev/null 2>&1
}

# ------------------------------------------------------------------------------
# Шаг 2: Установка зависимостей (yt-dlp, ffmpeg, fzf)
# ------------------------------------------------------------------------------
echo -e "${YELLOW}📦 Шаг 2: Проверка и установка зависимостей...${RESET}"

if [ "$OS" = "Darwin" ]; then
    # Подключение brew окружения
    if [ -x "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x "/usr/local/bin/brew" ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    if ! command -v brew &>/dev/null; then
        echo -e "${YELLOW}Homebrew не обнаружен на вашем Mac.${RESET}"
        
        if ! check_internet; then
            echo -e "${RED}❌ Отсутствует подключение к интернету.${RESET}"
            echo -e "${YELLOW}Подключитесь к сети и повторите: bash install.sh${RESET}"
            exit 1
        fi

        brew_choice="1"
        if [ -t 0 ]; then
            echo -e "Выберите способ установки:"
            echo -e "  ${CYAN}1)${RESET} Установить Homebrew и все пакеты автоматически (Рекомендуется)"
            echo -e "  ${CYAN}2)${RESET} Скачать автономный yt-dlp напрямую (Быстро, без Homebrew)"
            read -r -p "Выберите вариант [1/2, по умолчанию 1]: " brew_choice
            brew_choice=${brew_choice:-1}
        fi

        if [ "$brew_choice" = "1" ]; then
            echo -e "\n${CYAN}Установка Homebrew...${RESET}"
            if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
                if [ -x "/opt/homebrew/bin/brew" ]; then
                    eval "$(/opt/homebrew/bin/brew shellenv)"
                elif [ -x "/usr/local/bin/brew" ]; then
                    eval "$(/usr/local/bin/brew shellenv)"
                fi
                echo -e "${CYAN}Установка yt-dlp, ffmpeg и fzf через Homebrew...${RESET}"
                brew install yt-dlp ffmpeg fzf || echo -e "${RED}Предупреждение: некоторые пакеты не удалось установить.${RESET}"
            else
                echo -e "${RED}❌ Не удалось установить Homebrew.${RESET}"
            fi
        else
            echo -e "\n${CYAN}Скачивание автономного yt-dlp для macOS...${RESET}"
            if curl -fL "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos" -o "$BIN_DIR/yt-dlp"; then
                chmod +x "$BIN_DIR/yt-dlp"
                echo -e "${GREEN}✓ yt-dlp установлен в $BIN_DIR/yt-dlp${RESET}"
            else
                echo -e "${RED}❌ Не удалось скачать yt-dlp.${RESET}"
            fi

            if ! command -v ffmpeg &>/dev/null; then
                echo -e "${YELLOW}Внимание: для объединения 4K видео и конвертации в MP3 рекомендуется ffmpeg.${RESET}"
            fi
        fi
    else
        echo -e "${GREEN}✓ Homebrew обнаружен${RESET}"
        missing_pkgs=()
        command -v yt-dlp &>/dev/null || missing_pkgs+=("yt-dlp")
        command -v ffmpeg &>/dev/null || missing_pkgs+=("ffmpeg")
        command -v fzf &>/dev/null || missing_pkgs+=("fzf")

        if [ ${#missing_pkgs[@]} -gt 0 ]; then
            echo -e "${CYAN}Установка пакетов через Homebrew: ${missing_pkgs[*]}...${RESET}"
            if ! check_internet; then
                echo -e "${RED}❌ Отсутствует подключение к интернету для загрузки пакетов.${RESET}"
            else
                brew install "${missing_pkgs[@]}" || true
            fi
        else
            echo -e "${GREEN}✓ Все ключевые утилиты (yt-dlp, ffmpeg, fzf) уже установлены!${RESET}"
        fi

        # ----------------------------------------------------------------------
        # Гарантированная самоотладка: если yt-dlp не удалось установить через brew
        # (например, Homebrew Tier 3, отсутствие bottles, конфликт xcode)
        # ----------------------------------------------------------------------
        if ! command -v yt-dlp &>/dev/null && [ ! -x "$BIN_DIR/yt-dlp" ]; then
            echo -e "\n${YELLOW}ℹ️ Homebrew сообщил об ограничении конфигурации (Tier 3).${RESET}"
            echo -e "${CYAN}⚡ Загрузка официального универсального бинарника yt-dlp для Mac...${RESET}"
            mkdir -p "$BIN_DIR"
            if curl -fL --progress-bar "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos" -o "$BIN_DIR/yt-dlp"; then
                chmod +x "$BIN_DIR/yt-dlp"
                xattr -d com.apple.quarantine "$BIN_DIR/yt-dlp" 2>/dev/null || true
                echo -e "${GREEN}✓ Автономный yt-dlp успешно установлен в $BIN_DIR/yt-dlp!${RESET}"
            elif command -v python3 &>/dev/null; then
                echo -e "${CYAN}Попытка установки через Python pip...${RESET}"
                python3 -m pip install --upgrade --user yt-dlp 2>/dev/null || true
            fi
        fi
    fi

elif [ "$OS" = "Linux" ]; then
    if ! check_internet; then
        echo -e "${RED}❌ Отсутствует подключение к интернету.${RESET}"
    fi

    if command -v apt-get &>/dev/null; then
        echo -e "${CYAN}Установка пакетов через apt-get...${RESET}"
        sudo apt-get update -y || true
        sudo apt-get install -y ffmpeg fzf curl python3 || true
        if ! command -v yt-dlp &>/dev/null; then
            sudo curl -fL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp && \
            sudo chmod a+rx /usr/local/bin/yt-dlp || true
        fi
    elif command -v pacman &>/dev/null; then
        sudo pacman -Sy --noconfirm yt-dlp ffmpeg fzf || true
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y yt-dlp ffmpeg fzf || true
    fi
fi

# ------------------------------------------------------------------------------
# Шаг 3: Проверка VideoToolbox аппаратного ускорения
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}⚡ Шаг 3: Проверка аппаратного ускорения Apple Silicon...${RESET}"
if command -v ffmpeg &>/dev/null; then
    if ffmpeg -hwaccels 2>/dev/null | grep -q "videotoolbox"; then
        echo -e "${GREEN}✓ VideoToolbox аппаратное ускорение АКТИВИРОВАНО!${RESET}"
        echo -e "   ${GRAY}Медиа-ядро вашего $CPU_MODEL будет аппаратно обрабатывать видео.${RESET}"
    else
        echo -e "${YELLOW}ℹ️ VideoToolbox не активен, используется стандартный CPU.${RESET}"
    fi
else
    echo -e "${RED}⚠️ FFmpeg не найден! Аппаратное кодирование недоступно.${RESET}"
fi

# ------------------------------------------------------------------------------
# Шаг 4: Настройка прав запуска
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}⚙️ Шаг 4: Настройка прав запуска...${RESET}"
chmod +x "$SCRIPT_DIR/yt.sh" "$SCRIPT_DIR/start.sh" "$SCRIPT_DIR/install.sh" 2>/dev/null || true
echo -e "${GREEN}✓ Права на исполнение выданы!${RESET}"

# ------------------------------------------------------------------------------
# Шаг 5: Настройка глобальной команды 'yt' (Идемпотентная конфигурация)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}🔗 Шаг 5: Настройка быстрого запуска команды 'yt'...${RESET}"

# Создание системных symlink в PATH при наличии прав
for target_dir in "/opt/homebrew/bin" "/usr/local/bin" "$HOME/.local/bin"; do
    if [ -d "$target_dir" ] && [ -w "$target_dir" ]; then
        if ln -sf "$SCRIPT_DIR/yt.sh" "$target_dir/yt" 2>/dev/null; then
            echo -e "${GREEN}✓ Создана системная ссылка: $target_dir/yt${RESET}"
        fi
        if [ -x "$BIN_DIR/yt-dlp" ]; then
            if ln -sf "$BIN_DIR/yt-dlp" "$target_dir/yt-dlp" 2>/dev/null; then
                echo -e "${GREEN}✓ Создана системная ссылка: $target_dir/yt-dlp${RESET}"
            fi
        fi
        break
    fi
done

# Идемпотентная настройка алиаса в shell profile
SHELL_RC=""
if [ -n "$ZSH_VERSION" ] || [ "${SHELL##*/}" = "zsh" ] || [ -f "$HOME/.zshrc" ]; then
    SHELL_RC="$HOME/.zshrc"
    [ ! -f "$SHELL_RC" ] && touch "$SHELL_RC" 2>/dev/null || true
elif [ -n "$BASH_VERSION" ] || [ "${SHELL##*/}" = "bash" ] || [ -f "$HOME/.bashrc" ]; then
    SHELL_RC="$HOME/.bashrc"
    [ ! -f "$SHELL_RC" ] && touch "$SHELL_RC" 2>/dev/null || true
fi

if [ -n "$SHELL_RC" ] && [ -f "$SHELL_RC" ]; then
    expected_alias="alias yt=\"$SCRIPT_DIR/yt.sh\""
    current_alias=$(grep "alias yt=" "$SHELL_RC" 2>/dev/null | tail -n 1)

    if [ "$current_alias" = "$expected_alias" ]; then
        echo -e "${GREEN}✓ Алиас 'yt' уже актуален в $SHELL_RC${RESET}"
    else
        # Безопасное обновление без дублирования
        cp "$SHELL_RC" "${SHELL_RC}.bak" 2>/dev/null || true
        grep -v "alias yt=" "${SHELL_RC}.bak" > "$SHELL_RC" 2>/dev/null || true
        rm -f "${SHELL_RC}.bak" 2>/dev/null || true
        {
            echo ""
            echo "# yt (macOS Edition)"
            echo "$expected_alias"
        } >> "$SHELL_RC"
        echo -e "${GREEN}✓ Алиас 'yt' настроен в $SHELL_RC${RESET}"
    fi
fi

echo -e "\n${GREEN}${BOLD}🎉 УСТАНОВКА И ОПТИМИЗАЦИЯ ЗАВЕРШЕНЫ!${RESET}"
echo -e "─────────────────────────────────────────────────────────────"
echo -e "${BOLD}Как запускать программу:${RESET}"
echo -e "  1. Из любой папки терминала :  ${CYAN}yt${RESET}"
echo -e "  2. Или из папки проекта    :  ${CYAN}bash start.sh${RESET}"
echo -e "  3. Проверка здоровья       :  ${CYAN}yt --doctor${RESET}"
echo -e "─────────────────────────────────────────────────────────────\n"
