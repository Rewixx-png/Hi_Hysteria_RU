#!/bin/bash

# === СТАТИСТИКА ===
check_stats() {
    # 1. Ищем порт API в конфиге
    if [ ! -f "$SERVER_CONF" ]; then
        echo -e "${RED}Конфиг не найден!${Font}"
        return
    fi
    
    # Парсим порт из yaml (грубо, через grep, чтобы не зависеть от yq)
    # Ищем строку "  listen: 127.0.0.1:XXXX" под блоком "http:"
    API_PORT=$(grep -A 1 "^http:" "$SERVER_CONF" | grep "listen" | awk -F':' '{print $2}' | tr -d ' ')
    
    if [[ -z "$API_PORT" ]]; then
        echo -e "${RED}В конфиге не включен HTTP API! Статистика недоступна.${Font}"
        echo "Переустановите сервер через пункт 1 или добавьте блок 'http' в конфиг вручную."
        return
    fi

    # 2. Запрашиваем статистику
    echo -e "${BLUE}>>> Запрос статистики (Hysteria 2 API)...${Font}"
    
    if ! command -v jq &> /dev/null; then
        echo "Устанавливаем jq для парсинга JSON..."
        apt-get install -y jq &>/dev/null || yum install -y jq &>/dev/null
    fi

    STATS_JSON=$(curl -s "http://127.0.0.1:$API_PORT/traffic")
    
    if [[ -z "$STATS_JSON" ]]; then
        echo -e "${RED}Не удалось получить данные. Сервер запущен?${Font}"
        return
    fi

    # 3. Вывод
    TX=$(echo "$STATS_JSON" | jq .tx)
    RX=$(echo "$STATS_JSON" | jq .rx)
    
    # Конвертация байт в МБ/ГБ
    format_bytes() {
        num=$1
        if [ $num -gt 1073741824 ]; then
            echo "$(echo "scale=2; $num/1073741824" | bc) GB"
        else
            echo "$(echo "scale=2; $num/1048576" | bc) MB"
        fi
    }
    
    # Для bc (калькулятора) если его нет
    if ! command -v bc &> /dev/null; then apt-get install -y bc &>/dev/null; fi

    echo -e "${GREEN}================================${Font}"
    echo -e "Трафик (с момента запуска):"
    echo -e "Отправлено (TX): ${YELLOW}$(format_bytes $TX)${Font}"
    echo -e "Принято (RX):    ${YELLOW}$(format_bytes $RX)${Font}"
    echo -e "${GREEN}================================${Font}"
}

# === ОБНОВЛЕНИЕ СКРИПТА ===
update_hihy() {
    echo -e "${BLUE}>>> Обновление Hysteria Manager...${Font}"
    cd /etc/hihy || exit
    git pull
    chmod +x server/hihy
    chmod +x server/lib/*.sh
    echo -e "${GREEN}Обновление завершено! Перезапустите скрипт.${Font}"
    exit 0
}

# === ОБНОВЛЕНИЕ ЯДРА ===
update_core() {
    echo -e "${BLUE}>>> Проверка новой версии Hysteria 2...${Font}"
    # Тут можно добавить парсинг API Github, но пока просто перекачаем latest
    systemctl stop hihy
    
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        *) echo "Arch not supported"; return ;;
    esac
    
    wget -q --show-progress -O "$APP_BIN" "https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-${ARCH}"
    chmod +x "$APP_BIN"
    
    systemctl start hihy
    echo -e "${GREEN}Ядро обновлено до Latest!${Font}"
}

# === SOCKS5 (Упрощенно) ===
add_socks5_outbound() {
    echo -e "${YELLOW}Функция добавления Socks5 (WARP) пока в разработке.${Font}"
    echo -e "В Hysteria 2 это делается через добавление 'socks5' в секцию 'outbounds' конфига."
    echo -e "Рекомендуется пока использовать готовый клиент WARP отдельно."
}

# === ACL ===
manage_acl() {
    echo -e "${YELLOW}Управление ACL (GeoIP) пока в разработке.${Font}"
    echo -e "По умолчанию Hysteria 2 работает без блокировок."
}