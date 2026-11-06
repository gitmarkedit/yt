#!/usr/bin/env bash
# ==============================================================================
#  ⚡ Установщик всех зависимостей для YT-DLP Ultimate Downloader
# ==============================================================================

set -e

# Определение директории скрипта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"
mkdir -p "$BIN_DIR"

# Цвета
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

clear
echo -e "${CYAN}${BOLD}"
cat << "EOF"
   ╭─────────────────────────────────────────────────────────────╮
   │         ⚡  У С Т А Н О В К А   Y T - D L P  ⚡             │
   │       Автоматическая установка всех зависимостей            │
   ╰─────────────────────────────────────────────────────────────╯
EOF
echo -e "${RESET}"

echo -e "${YELLOW}🔍 Шаг 1: Проверка системы...${RESET}"
OS="$(uname -s)"
ARCH="$(uname -m)"
echo -e "${GREEN}✓ ОС: $OS ($ARCH)${RESET}\n"

# ------------------------------------------------------------------------------
# 1. Установка утилит
# ------------------------------------------------------------------------------
echo -e "${YELLOW}📦 Шаг 2: Установка зависимостей (yt-dlp, ffmpeg, fzf)...${RESET}"

if [ "$OS" = "Darwin" ]; then
    # Проверка Homebrew
    if ! command -v brew &>/dev/null && [ ! -f "/opt/homebrew/bin/brew" ] && [ ! -f "/usr/local/bin/brew" ]; then
        echo -e "${YELLOW}Homebrew не обнаружен на вашем Mac.${RESET}"
        echo -e "Выберите способ установки:"
        echo -e "  ${CYAN}1)${RESET} Установить Homebrew и все пакеты автоматически (Рекомендуется)"
        echo -e "  ${CYAN}2)${RESET} Скачать готовые бинарники yt-dlp напрямую (Быстро, без Homebrew)"
        read -p "Выберите вариант [1/2, по умолчанию 1]: " brew_choice
        brew_choice=${brew_choice:-1}

        if [ "$brew_choice" = "1" ]; then
            echo -e "\n${CYAN}Установка Homebrew (потребуется подтверждение и пароль от Mac)...${RESET}"
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            
            # Подключение путей brew
            if [ -f "/opt/homebrew/bin/brew" ]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
            elif [ -f "/usr/local/bin/brew" ]; then
                eval "$(/usr/local/bin/brew shellenv)"
            fi
            
            echo -e "${CYAN}Установка yt-dlp, ffmpeg и fzf через Homebrew...${RESET}"
            brew install yt-dlp ffmpeg fzf || true
        else
            echo -e "\n${CYAN}Скачивание автономного yt-dlp в папку проекта...${RESET}"
            curl -L "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos" -o "$BIN_DIR/yt-dlp"
            chmod +x "$BIN_DIR/yt-dlp"
            echo -e "${GREEN}✓ yt-dlp установлен в $BIN_DIR/yt-dlp${RESET}"

            # Проверка ffmpeg
            if ! command -v ffmpeg &>/dev/null; then
                echo -e "${YELLOW}Для объединения 1080p/4K видео и конвертации в MP3 нужен ffmpeg.${RESET}"
                echo -e "${CYAN}Устанавливаем Homebrew для ffmpeg...${RESET}"
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                if [ -f "/opt/homebrew/bin/brew" ]; then
                    eval "$(/opt/homebrew/bin/brew shellenv)"
                elif [ -f "/usr/local/bin/brew" ]; then
                    eval "$(/usr/local/bin/brew shellenv)"
                fi
                brew install ffmpeg fzf || true
            fi
        fi
    else
        # Homebrew есть
        if [ -f "/opt/homebrew/bin/brew" ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -f "/usr/local/bin/brew" ]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
        echo -e "${CYAN}Установка/обновление yt-dlp, ffmpeg и fzf через Homebrew...${RESET}"
        brew install yt-dlp ffmpeg fzf || true
    fi

elif [ "$OS" = "Linux" ]; then
    if command -v apt-get &>/dev/null; then
        echo -e "${CYAN}Установка пакетов через apt-get...${RESET}"
        sudo apt-get update
        sudo apt-get install -y ffmpeg fzf curl python3
        sudo curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
        sudo chmod a+rx /usr/local/bin/yt-dlp
    elif command -v pacman &>/dev/null; then
        sudo pacman -Sy --noconfirm yt-dlp ffmpeg fzf
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y yt-dlp ffmpeg fzf
    fi
fi

# ------------------------------------------------------------------------------
# 2. Настройка прав на исполнение
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}⚙️ Шаг 3: Настройка прав запуска...${RESET}"
chmod +x "$SCRIPT_DIR/yt.sh" "$SCRIPT_DIR/start.sh" 2>/dev/null || true
echo -e "${GREEN}✓ Файлы скрипта готовы к запуску!${RESET}"

# ------------------------------------------------------------------------------
# 3. Настройка глобальной команды 'yt'
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}🔗 Шаг 4: Настройка быстрого запуска команды 'yt'${RESET}"

# Симлинк в системную папку (если есть права)
if [ -d "/opt/homebrew/bin" ] && [ -w "/opt/homebrew/bin" ]; then
    ln -sf "$SCRIPT_DIR/yt.sh" /opt/homebrew/bin/yt 2>/dev/null && \
    echo -e "${GREEN}✓ Создана системная ссылка: /opt/homebrew/bin/yt${RESET}"
elif [ -d "/usr/local/bin" ] && [ -w "/usr/local/bin" ]; then
    ln -sf "$SCRIPT_DIR/yt.sh" /usr/local/bin/yt 2>/dev/null && \
    echo -e "${GREEN}✓ Создана системная ссылка: /usr/local/bin/yt${RESET}"
fi

# Добавление алиаса в shell rc файл (~/.zshrc / ~/.bashrc)
SHELL_RC=""
if [ -f "$HOME/.zshrc" ] || [ "$SHELL" = "/bin/zsh" ]; then
    SHELL_RC="$HOME/.zshrc"
    [ ! -f "$SHELL_RC" ] && touch "$SHELL_RC"
elif [ -f "$HOME/.bashrc" ] || [ "$SHELL" = "/bin/bash" ]; then
    SHELL_RC="$HOME/.bashrc"
fi

if [ -n "$SHELL_RC" ]; then
    if ! grep -q "alias yt=" "$SHELL_RC" 2>/dev/null; then
        echo "" >> "$SHELL_RC"
        echo "# YT-DLP Ultimate Downloader" >> "$SHELL_RC"
        echo "alias yt=\"$SCRIPT_DIR/yt.sh\"" >> "$SHELL_RC"
        echo -e "${GREEN}✓ Добавлен алиас 'yt' в $SHELL_RC${RESET}"
    else
        echo -e "${GREEN}✓ Алиас 'yt' уже присутствует в $SHELL_RC${RESET}"
    fi
fi

echo -e "\n${GREEN}${BOLD}🎉 ВСЁ ГОТОВО К РАБОТЕ!${RESET}"
echo -e "─────────────────────────────────────────────────────────────"
echo -e "${BOLD}Как теперь запускать программу:${RESET}"
echo -e "  1. Напишите в терминале:      ${CYAN}yt${RESET}"
echo -e "  2. Или из папки проекта:     ${CYAN}bash start.sh${RESET}"
echo -e "─────────────────────────────────────────────────────────────\n"
