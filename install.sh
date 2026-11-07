#!/usr/bin/env bash
# ==============================================================================
#  ⚡ Установщик yt (macOS Edition)
#  Оптимизировано для macOS (Apple Silicon M1/M2/M3/M4 & Intel) и Linux
#  Автономный режим: не требует предварительной установки Xcode или Homebrew
# ==============================================================================

# Определение директории скрипта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"
mkdir -p "$BIN_DIR" 2>/dev/null || true

# Автоматическое подключение стандартных путей
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
# Автономные функции загрузки бинарников для macOS
# ------------------------------------------------------------------------------
install_standalone_ytdlp() {
    if ! command -v yt-dlp &>/dev/null && [ ! -x "$BIN_DIR/yt-dlp" ]; then
        echo -e "${CYAN}⚡ Загрузка официального универсального yt-dlp для macOS...${RESET}"
        mkdir -p "$BIN_DIR"
        if curl -fL --progress-bar "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos" -o "$BIN_DIR/yt-dlp"; then
            chmod +x "$BIN_DIR/yt-dlp"
            xattr -d com.apple.quarantine "$BIN_DIR/yt-dlp" 2>/dev/null || true
            echo -e "${GREEN}✓ yt-dlp успешно установлен в $BIN_DIR/yt-dlp!${RESET}"
            return 0
        fi
        return 1
    fi
    return 0
}

install_standalone_ffmpeg() {
    if ! command -v ffmpeg &>/dev/null && [ ! -x "$BIN_DIR/ffmpeg" ]; then
        echo -e "${CYAN}⚡ Загрузка медиа-движка FFmpeg (с ускорением VideoToolbox для $ARCH)...${RESET}"
        mkdir -p "$BIN_DIR"
        local temp_dir="$BIN_DIR/temp_extract"
        mkdir -p "$temp_dir"
        if curl -fL --progress-bar "https://github.com/homebridge/ffmpeg-for-homebridge/releases/latest/download/ffmpeg-darwin-${ARCH}.tar.gz" | tar -xz -C "$temp_dir" 2>/dev/null; then
            if [ -f "$temp_dir/usr/local/bin/ffmpeg" ]; then
                mv "$temp_dir/usr/local/bin/ffmpeg" "$BIN_DIR/ffmpeg"
                chmod +x "$BIN_DIR/ffmpeg"
                xattr -d com.apple.quarantine "$BIN_DIR/ffmpeg" 2>/dev/null || true
                echo -e "${GREEN}✓ FFmpeg с VideoToolbox успешно установлен в $BIN_DIR/ffmpeg!${RESET}"
            fi
        fi
        rm -rf "$temp_dir"
    fi
    return 0
}

# ------------------------------------------------------------------------------
# Шаг 2: Проверка и установка зависимостей
# ------------------------------------------------------------------------------
echo -e "${YELLOW}📦 Шаг 2: Проверка и настройка компонентов...${RESET}"

if [ "$OS" = "Darwin" ]; then
    if ! check_internet; then
        echo -e "${RED}❌ Отсутствует подключение к интернету для загрузки компонентов.${RESET}"
        echo -e "${YELLOW}Подключитесь к сети и повторите запуск.${RESET}"
        exit 1
    fi

    # 1. Если Homebrew уже установлен, пробуем штатную установку
    if [ -x "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x "/usr/local/bin/brew" ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    if command -v brew &>/dev/null; then
        echo -e "${GREEN}✓ Обнаружен Homebrew${RESET}"
        missing_pkgs=()
        command -v yt-dlp &>/dev/null || missing_pkgs+=("yt-dlp")
        command -v ffmpeg &>/dev/null || missing_pkgs+=("ffmpeg")
        command -v fzf &>/dev/null || missing_pkgs+=("fzf")

        if [ ${#missing_pkgs[@]} -gt 0 ]; then
            echo -e "${CYAN}Установка пакетов через Homebrew: ${missing_pkgs[*]}...${RESET}"
            brew install "${missing_pkgs[@]}" 2>&1 || true
        else
            echo -e "${GREEN}✓ Все ключевые утилиты уже установлены!${RESET}"
        fi
    fi

    # 2. Автономный Fallback: гарантированная загрузка бинарников
    # Работает если Homebrew отсутствует, выдает ошибку Tier 3 или нет прав root
    install_standalone_ytdlp
    install_standalone_ffmpeg

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
    echo -e "${RED}⚠️ FFmpeg не найден!${RESET}"
fi

# ------------------------------------------------------------------------------
# Шаг 4: Настройка прав запуска
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}⚙️ Шаг 4: Настройка прав запуска...${RESET}"
chmod +x "$SCRIPT_DIR/yt.sh" "$SCRIPT_DIR/start.sh" "$SCRIPT_DIR/install.sh" 2>/dev/null || true
[ -x "$BIN_DIR/yt-dlp" ] && chmod +x "$BIN_DIR/yt-dlp" 2>/dev/null || true
[ -x "$BIN_DIR/ffmpeg" ] && chmod +x "$BIN_DIR/ffmpeg" 2>/dev/null || true
echo -e "${GREEN}✓ Права на исполнение выданы!${RESET}"

# ------------------------------------------------------------------------------
# Шаг 5: Настройка глобальной команды 'yt' и системных путей
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}🔗 Шаг 5: Настройка быстрого запуска команды 'yt'...${RESET}"

# 1. Попытка создания системных ссылок в глобальные папки
for target_dir in "/opt/homebrew/bin" "/usr/local/bin"; do
    if [ -d "$target_dir" ] && [ -w "$target_dir" ]; then
        ln -sf "$SCRIPT_DIR/yt.sh" "$target_dir/yt" 2>/dev/null && \
        echo -e "${GREEN}✓ Создана системная ссылка: $target_dir/yt${RESET}"
        [ -x "$BIN_DIR/yt-dlp" ] && ln -sf "$BIN_DIR/yt-dlp" "$target_dir/yt-dlp" 2>/dev/null || true
        [ -x "$BIN_DIR/ffmpeg" ] && ln -sf "$BIN_DIR/ffmpeg" "$target_dir/ffmpeg" 2>/dev/null || true
        break
    fi
done

# 2. Пользовательская папка ~/.local/bin (всегда доступна без прав root)
mkdir -p "$HOME/.local/bin" 2>/dev/null || true
ln -sf "$SCRIPT_DIR/yt.sh" "$HOME/.local/bin/yt" 2>/dev/null || true
[ -x "$BIN_DIR/yt-dlp" ] && ln -sf "$BIN_DIR/yt-dlp" "$HOME/.local/bin/yt-dlp" 2>/dev/null || true
[ -x "$BIN_DIR/ffmpeg" ] && ln -sf "$BIN_DIR/ffmpeg" "$HOME/.local/bin/ffmpeg" 2>/dev/null || true

# 3. Идемпотентная настройка алиаса и путей в shell profile
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
            echo "export PATH=\"\$HOME/.local/bin:$BIN_DIR:\$PATH\""
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
