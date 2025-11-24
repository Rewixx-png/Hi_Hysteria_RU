#!/bin/bash

# === СТАТИСТИКА ===
check_stats() {
    if [ ! -f "$SERVER_CONF" ]; then
        echo -e "${RED}Конфиг не найден!${Font}"
        return
    fi
    
    # Парсим порт из конфига
    API_PORT=$(grep -A 1 "^http:" "$SERVER_CONF" | grep "listen" | awk -F':' '{print $2}' | tr -d ' ')
    
    if [[ -z "$API_PORT" ]]; then
        echo -e "${RED}API выключен в конфиге.${Font}"
        return
    fi

    echo -e "${BLUE}>>> Запрос статистики...${Font}"
    
    # Проверка наличия jq
    if ! command -v jq &> /dev/null; then
        echo "Ошибка: jq не установлен. (Странно, он должен был поставиться в зависимостях)"
        return
    fi

    STATS_JSON=$(curl -s --max-time 3 "http://127.0.0.1:$API_PORT/traffic")
    
    if [[ -z "$STATS_JSON" ]]; then
        echo -e "${RED}Сервер не отвечает (API Port: $API_PORT).${Font}"
        return
    fi

    TX=$(echo "$STATS_JSON" | jq .tx 2>/dev/null)
    RX=$(echo "$STATS_JSON" | jq .rx 2>/dev/null)
    
    if [[ -z "$TX" ]]; then
        echo -e "${RED}Ошибка парсинга JSON.${Font}"
        return
    fi
    
    format_bytes() {
        if command -v bc &> /dev/null; then
            num=$1
            if [ $(echo "$num > 1073741824" | bc) -eq 1 ]; then
                echo "$(echo "scale=2; $num/1073741824" | bc) GB"
            else
                echo "$(echo "scale=2; $num/1048576" | bc) MB"
            fi
        else
            echo "$1 Bytes (Install 'bc' for human readable)"
        fi
    }

    echo -e "${GREEN}=== TRAFFIC ===${Font}"
    echo -e "TX (Out): ${YELLOW}$(format_bytes $TX)${Font}"
    echo -e "RX (In):  ${YELLOW}$(format_bytes $RX)${Font}"
    echo -e "${GREEN}===============${Font}"
}

# === ЛОГИ ===
show_log() {
    echo -e "${BLUE}Нажмите Ctrl+C для выхода...${Font}"
    journalctl -u hihy -f -n 100
}

# === ЗАГЛУШКИ ДЛЯ ОТСУТСТВУЮЩЕГО ФУНКЦИОНАЛА ===

manage_acl() {
    echo -e "${YELLOW}Функционал ACL еще не реализован в этой версии.${Font}"
}

add_socks5_outbound() {
    echo -e "${YELLOW}Добавление Socks5 Outbound временно отключено.${Font}"
}

switch_ipv4_ipv6() {
    echo -e "${YELLOW}Переключение приоритета IPv4/IPv6 еще не реализовано.${Font}"
    echo "Вы можете вручную настроить это в системном /etc/gai.conf"
}

update_core() {
    echo -e "${BLUE}Обновление ядра...${Font}"
    install_hy2 # Просто переустанавливаем бинарник
}

update_hihy() {
    echo -e "${BLUE}Обновление скрипта...${Font}"
    echo "Функция 'git pull' требует, чтобы папка была git-репозиторием."
    echo "Если вы скачали скрипт вручную, скачайте его заново."
}