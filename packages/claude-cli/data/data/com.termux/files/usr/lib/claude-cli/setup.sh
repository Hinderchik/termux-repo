#!/data/data/com.termux/files/usr/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Claude Opus 4.6 + Claude Code CLI Установщик          ║${NC}"
echo -e "${BLUE}║           Для Termux / Android / Linux Mint               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"

# Запрос API-ключа и URL у пользователя
echo -e "${YELLOW}➜ Введите ваш ANTHROPIC_API_KEY (начинается с sk_live_...):${NC}"
read -r ANTHROPIC_API_KEY

echo -e "${YELLOW}➜ Введите ваш ANTHROPIC_BASE_URL (например, https://ваш-сервер.online):${NC}"
read -r ANTHROPIC_BASE_URL

echo -e "${YELLOW}➜ Введите модель (по умолчанию claude-opus-4-6-20250514):${NC}"
read -r ANTHROPIC_MODEL
ANTHROPIC_MODEL=${ANTHROPIC_MODEL:-claude-opus-4-6-20250514}

echo -e "${GREEN}➜ API ключ: ${ANTHROPIC_API_KEY:0:15}...${NC}"
echo -e "${GREEN}➜ Base URL: $ANTHROPIC_BASE_URL${NC}"
echo -e "${GREEN}➜ Модель: $ANTHROPIC_MODEL${NC}"

# Проверка ОС
OS=$(uname -o 2>/dev/null || uname -s)
echo -e "${GREEN}➜ Определена ОС: $OS${NC}"

# 1. Обновление пакетов
echo -e "${YELLOW}➜ Обновление пакетов...${NC}"
if command -v pkg &> /dev/null; then
    pkg update && pkg upgrade -y
    pkg install proot-distro curl wget git nano -y
elif command -v apt &> /dev/null; then
    sudo apt update && sudo apt upgrade -y
    sudo apt install curl wget git nano -y
fi

# 2. Установка Node.js (если нужно для Codex)
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}➜ Установка Node.js...${NC}"
    if command -v pkg &> /dev/null; then
        pkg install nodejs-lts -y
    elif command -v apt &> /dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
        sudo apt install nodejs -y
    fi
fi

# 3. Установка Alpine Linux через proot-distro
echo -e "${YELLOW}➜ Установка Alpine Linux...${NC}"
if ! proot-distro list | grep -q alpine; then
    proot-distro install alpine
else
    echo -e "${GREEN}✓ Alpine уже установлен${NC}"
fi

# 4. Установка Claude Code CLI внутри Alpine
echo -e "${YELLOW}➜ Установка Claude Code CLI внутри Alpine...${NC}"
proot-distro login alpine -- bash -c "
    apk update && apk upgrade
    apk add nodejs npm git curl bash
    npm install -g @anthropic-ai/claude-code
"

# 5. Создание конфигурации внутри Alpine с введёнными данными
echo -e "${YELLOW}➜ Настройка API ключа и прокси...${NC}"
proot-distro login alpine -- bash -c "
    mkdir -p ~/.claude
    cat > ~/.claude/settings.json << INNEREOF
{
  \"env\": {
    \"ANTHROPIC_API_KEY\": \"$ANTHROPIC_API_KEY\",
    \"ANTHROPIC_BASE_URL\": \"$ANTHROPIC_BASE_URL\",
    \"ANTHROPIC_MODEL\": \"$ANTHROPIC_MODEL\"
  }
}
INNEREOF

    # Добавляем переменные в .bashrc
    echo 'export ANTHROPIC_API_KEY=\"$ANTHROPIC_API_KEY\"' >> ~/.bashrc
    echo 'export ANTHROPIC_BASE_URL=\"$ANTHROPIC_BASE_URL\"' >> ~/.bashrc
    echo 'export ANTHROPIC_MODEL=\"$ANTHROPIC_MODEL\"' >> ~/.bashrc
"

# 6. Создание скрипта запуска с подстановкой переменных
echo -e "${YELLOW}➜ Создание скрипта запуска...${NC}"
cat > ~/claude-opus << CLAUDE_EOF
#!/data/data/com.termux/files/usr/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Берём текущую папку или папку из аргумента
if [ -n "\$1" ]; then
    TARGET_DIR=\$(realpath "\$1")
else
    TARGET_DIR=\$(pwd)
fi

echo -e "\${BLUE}╔════════════════════════════════════════════════════════════╗\${NC}"
echo -e "\${BLUE}║           Claude Opus 4.6 — Запуск                         ║\${NC}"
echo -e "\${BLUE}╚════════════════════════════════════════════════════════════╝\${NC}"
echo -e "\${GREEN}➜ Рабочая папка: \$TARGET_DIR\${NC}"

# Проверяем, существует ли папка
if [ ! -d "\$TARGET_DIR" ]; then
    echo -e "\${YELLOW}➜ Папка не существует. Создать? (y/n)\${NC}"
    read -r answer
    if [ "\$answer" = "y" ]; then
        mkdir -p "\$TARGET_DIR"
    else
        exit 1
    fi
fi

# Запускаем Alpine с примонтированной папкой и переменными
proot-distro login alpine \
    --bind "\$TARGET_DIR:/root/project" \
    -- bash -c "cd /root/project && \
                export ANTHROPIC_API_KEY='$ANTHROPIC_API_KEY' && \
                export ANTHROPIC_BASE_URL='$ANTHROPIC_BASE_URL' && \
                export ANTHROPIC_MODEL='$ANTHROPIC_MODEL' && \
                echo -e '\${GREEN}➜ Claude запущен в /root/project\${NC}' && \
                claude"
CLAUDE_EOF

chmod +x ~/claude-opus

# 7. Установка Ghost Engine (прокси/Tor) для обхода блокировок
echo -e "${YELLOW}➜ Установка Tor прокси...${NC}"
if command -v pkg &> /dev/null; then
    pkg install tor -y
fi

cat > ~/start-proxy << 'PROXY_EOF'
#!/data/data/com.termux/files/usr/bin/bash
GREEN='\033[0;32m'
NC='\033[0m'
echo -e "${GREEN}➜ Запуск Tor прокси...${NC}"
echo -e "${GREEN}➜ SOCKS5: 127.0.0.1:9050${NC}"
echo -e "${GREEN}➜ Для остановки нажми Ctrl+C${NC}"
tor
PROXY_EOF

chmod +x ~/start-proxy

# 8. Установка Codex (ChatGPT) как альтернатива
echo -e "${YELLOW}➜ Установка Codex (ChatGPT API) как альтернатива...${NC}"
if command -v npm &> /dev/null; then
    npm install -g @openai/codex 2>/dev/null || echo -e "${YELLOW}➜ Codex: npm install пропущен${NC}"
fi

# 9. Создание файла tz.txt примера
cat > ~/tz_example.txt << 'TZ_EOF'
Пример tz.txt с инструкциями:

1. Создай файл server.js с базовым HTTP сервером на Express
2. Добавь обработку корневого маршрута /
3. Запусти сервер на порту 3000
4. Добавь WebSocket поддержку
5. Создай простой клиент для чата

Для каждого пункта пиши "✅ готово: [что сделано]"
TZ_EOF

# 10. Итоговый вывод
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    УСТАНОВКА ЗАВЕРШЕНА!                    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo -e ""
echo -e "${YELLOW}📌 КОМАНДЫ ДЛЯ ЗАПУСКА:${NC}"
echo -e ""
echo -e "${GREEN}1. Запустить Claude Opus 4.6 в текущей папке:${NC}"
echo -e "   ${BLUE}~/claude-opus${NC}"
echo -e ""
echo -e "${GREEN}2. Запустить Claude Opus 4.6 в конкретной папке:${NC}"
echo -e "   ${BLUE}~/claude-opus ~/messenger-app${NC}"
echo -e ""
echo -e "${GREEN}3. Запустить прокси (Tor) для обхода блокировок (если нужно):${NC}"
echo -e "   ${BLUE}~/start-proxy${NC}"
echo -e ""
echo -e "${GREEN}4. Запустить Codex (ChatGPT) как альтернативу:${NC}"
echo -e "   ${BLUE}codex -m gpt-5.4${NC}"
echo -e ""
echo -e "${YELLOW}📁 Файлы:${NC}"
echo -e "   Пример tz.txt: ${BLUE}~/tz_example.txt${NC}"
echo -e "   Конфиг Claude: внутри Alpine ${BLUE}~/.claude/settings.json${NC}"
echo -e ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"

EOF