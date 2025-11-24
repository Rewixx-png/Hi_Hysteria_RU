#!/bin/bash

# === ЦВЕТА ===
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
Font="\033[0m"

# === ГЛОБАЛЬНЫЕ ПУТИ ===
HY_DIR="/etc/hihy"
CONF_DIR="/etc/hihy/conf"
CERT_DIR="/etc/hihy/cert"
LOG_DIR="/etc/hihy/log"
BIN_DIR="/etc/hihy/bin"
CONF_FILE="${CONF_DIR}/hihy.conf"
SERVER_CONF="${CONF_DIR}/config.yaml"
APP_BIN="${BIN_DIR}/appS"

# === ЛОГОТИП ===
logo() {
    echo -e "${GREEN}
 -------------------------------------------
|**********      Hi Hysteria       **********|
|**********    Author: emptysuns   **********|
|**********    Trans: Rewixx       **********|
|**********     Version: 1.0.3     **********|
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
        RELEASE="centos"
    elif cat /etc/issue | grep -q -E -i "debian"; then
        RELEASE="debian"
    elif cat /etc/issue | grep -q -E -i "ubuntu"; then
        RELEASE="ubuntu"
    elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
        RELEASE="centos"
    elif cat /proc/version | grep -q -E -i "debian"; then
        RELEASE="debian"
    elif cat /proc/version | grep -q -E -i "ubuntu"; then
        RELEASE="ubuntu"
    elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
        RELEASE="centos"
    else
        RELEASE="unknown"
    fi
}

install_dependencies() {
    echo -e "${BLUE}>>> Проверка и установка зависимостей...${Font}"
    if [[ "${RELEASE}" == "centos" ]]; then
        yum install -y wget curl socat openssl tar crontabs jq
    else
        apt-get update
        apt-get install -y wget curl socat openssl tar cron jq
    fi
    
    # Создаем папки
    mkdir -p "$HY_DIR" "$CONF_DIR" "$CERT_DIR" "$LOG_DIR" "$BIN_DIR"
}

# === ПРОВЕРКИ УСТАНОВКИ (ВАЖНО!) ===
check_install() {
    if [ ! -f "$CONF_FILE" ]; then
        echo -e "${RED}Ошибка: Hysteria 2 не установлена!${Font}"
        echo -e "${YELLOW}Пожалуйста, сначала выберите пункт 1 для установки.${Font}"
        return 1
    fi
    return 0
}

check_uninstall() {
    # Функция ничего не блокирует, просто возвращает true, 
    # так как install_hy2 сам справится с перезаписью.
    return 0
}

# === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===
get_random_port() {
    local port=0
    while true; do
        port=$(shuf -i 10000-65535 -n 1)
        if ! lsof -i :$port >/dev/null; then
            echo $port
            break
        fi
    done
}

get_ip() {
    local ip=$(curl -s4m8 https://ip.gs)
    if [[ -z "$ip" ]]; then
        ip=$(curl -s4m8 https://api.ipify.org)
    fi
    echo $ip
}
