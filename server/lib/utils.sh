#!/bin/bash

# === ЦВЕТА ===
export RED="\033[31m"
export GREEN="\033[32m"
export YELLOW="\033[33m"
export BLUE="\033[36m"
export Font="\033[0m"

# === ГЛОБАЛЬНЫЕ ПУТИ ===
export HY_DIR="/etc/hihy"
export CONF_DIR="/etc/hihy/conf"
export CERT_DIR="/etc/hihy/cert"
export LOG_DIR="/etc/hihy/log"
export BIN_DIR="/etc/hihy/bin"
export CONF_FILE="${CONF_DIR}/hihy.conf"
export SERVER_CONF="${CONF_DIR}/config.yaml"
export APP_BIN="${BIN_DIR}/appS"

# === ЛОГОТИП ===
logo() {
    echo -e "${GREEN}
 -------------------------------------------
|**********      Hi Hysteria       **********|
|**********    Author: emptysuns   **********|
|**********    Refactor: LeadDev   **********|
|**********     Version: 1.0.4     **********|
 -------------------------------------------
${Font}"
}

# === ПРОВЕРКИ СИСТЕМЫ ===
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Ошибка: Запустите скрипт от имени root!${Font}"
        exit 1
    fi
}

check_sys() {
    if [[ -f /etc/redhat-release ]]; then
        export RELEASE="centos"
    elif cat /etc/issue | grep -q -E -i "debian"; then
        export RELEASE="debian"
    elif cat /etc/issue | grep -q -E -i "ubuntu"; then
        export RELEASE="ubuntu"
    elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
        export RELEASE="centos"
    else
        export RELEASE="unknown"
    fi
}

install_dependencies() {
    echo -e "${BLUE}>>> Проверка и установка зависимостей...${Font}"
    if [[ "${RELEASE}" == "centos" ]]; then
        if command -v dnf &> /dev/null; then
            dnf install -y wget curl socat openssl tar crontabs jq lsof bc
        else
            yum install -y wget curl socat openssl tar crontabs jq lsof bc
        fi
    else
        apt-get update
        apt-get install -y wget curl socat openssl tar cron jq lsof bc
    fi
    
    # Создаем структуру папок
    mkdir -p "$HY_DIR" "$CONF_DIR" "$CERT_DIR" "$LOG_DIR" "$BIN_DIR"
}

# === ПРОВЕРКИ СТАТУСА УСТАНОВКИ ===
check_install() {
    if [ ! -f "$CONF_FILE" ] || [ ! -f "$APP_BIN" ]; then
        echo -e "${RED}Ошибка: Hysteria 2 не установлена или повреждена!${Font}"
        echo -e "${YELLOW}Пожалуйста, выберите пункт 1 для установки.${Font}"
        return 1
    fi
    return 0
}

check_uninstall() {
    return 0
}

# === СЕТЕВЫЕ УТИЛИТЫ ===
get_random_port() {
    local port=0
    while true; do
        port=$(shuf -i 10000-65535 -n 1)
        if ! lsof -i :$port >/dev/null 2>&1; then
            echo $port
            break
        fi
    done
}

get_ip() {
    local ip=$(curl -s4m8 https://api.ipify.org)
    if [[ -z "$ip" ]]; then
        ip=$(curl -s4m8 https://ip.gs)
    fi
    if [[ -z "$ip" ]]; then
        echo -e "${RED}Не удалось определить IP!${Font}" >&2
        echo "127.0.0.1"
    else
        echo $ip
    fi
}