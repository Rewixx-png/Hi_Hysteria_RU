#!/bin/bash

# === ОПРЕДЕЛЕНИЕ АРХИТЕКТУРЫ ===
get_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64) echo "amd64" ;;
        aarch64) echo "arm64" ;;
        armv7l) echo "arm" ;;
        s390x) echo "s390x" ;;
        mips64) echo "mips64le" ;;
        *) echo "unknown" ;;
    esac
}

# === УСТАНОВКА ===
install_hy2() {
    # 1. Проверка окружения
    check_root
    check_sys
    install_dependencies

    # 2. Определение архитектуры и скачивание
    ARCH=$(get_arch)
    if [ "$ARCH" == "unknown" ]; then
        echo -e "${RED}Ошибка: Архитектура $(uname -m) не поддерживается!${Font}"
        exit 1
    fi

    echo -e "${BLUE}>>> Скачивание ядра Hysteria 2 ($ARCH)...${Font}"
    # Используем API для получения последней версии (или хардкод на latest)
    DOWNLOAD_URL="https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-${ARCH}"
    
    wget -q --show-progress -O "$APP_BIN" "$DOWNLOAD_URL"
    chmod +x "$APP_BIN"

    if [ ! -f "$APP_BIN" ]; then
        echo -e "${RED}Ошибка: Скачивание не удалось. Проверьте сеть или GitHub API.${Font}"
        exit 1
    fi

    # 3. WIZARD (Мастер настройки)
    echo -e "${GREEN}>>> Настройка Hysteria 2${Font}"

    # --- СЕРТИФИКАТ ---
    echo -e "\n${YELLOW}(1/5) Сертификат:${Font}"
    echo -e "${GREEN}1)${Font} Автоматический (ACME/Let's Encrypt) - Нужен домен и 80 порт"
    echo -e "${GREEN}2)${Font} Самоподписанный (Self-signed) - Для работы по IP"
    echo -e "${GREEN}3)${Font} Свои файлы (.crt + .key)"
    read -p "Выбор [1]: " cert_choice
    cert_choice=${cert_choice:-1}

    tls_config=""
    domain=""
    
    if [[ "$cert_choice" == "1" ]]; then
        read -p "Введите ваш домен: " domain
        tls_config="acme:
  domains:
    - $domain
  email: admin@$domain"
    elif [[ "$cert_choice" == "2" ]]; then
        echo -e "${BLUE}Генерируем самоподписанный сертификат...${Font}"
        domain="www.bing.com" # Фейковый SNI для маскировки
        # Для самоподписанного генерируем через openssl
        openssl req -x509 -newkey rsa:2048 -nodes -sha256 -keyout "$CERT_DIR/self.key" -out "$CERT_DIR/self.crt" -days 3650 -subj "/CN=$domain" 2>/dev/null
        tls_config="tls:
  cert: $CERT_DIR/self.crt
  key: $CERT_DIR/self.key"
    elif [[ "$cert_choice" == "3" ]]; then
        read -p "Путь к .crt: " user_crt
        read -p "Путь к .key: " user_key
        cp "$user_crt" "$CERT_DIR/custom.crt"
        cp "$user_key" "$CERT_DIR/custom.key"
        tls_config="tls:
  cert: $CERT_DIR/custom.crt
  key: $CERT_DIR/custom.key"
    fi

    # --- ПОРТЫ И HOPPING ---
    echo -e "\n${YELLOW}(2/5) Порт сервера:${Font}"
    read -p "Основной порт [443]: " main_port
    main_port=${main_port:-443}

    listen_str=":$main_port"

    echo -e "\n${YELLOW}(3/5) Включить Port Hopping? (Рекомендуется)${Font}"
    echo -e "Это заставляет сервер слушать диапазон портов. Усложняет блокировку."
    read -p "Включить? [Y/n]: " hop_yn
    hop_yn=${hop_yn:-Y}

    hopping_range=""
    if [[ "$hop_yn" =~ ^[Yy]$ ]]; then
        read -p "Диапазон [20000-50000]: " hop_range
        hop_range=${hop_range:-"20000-50000"}
        # Синтаксис Hysteria 2: :443,20000-50000
        listen_str=":$main_port,$hop_range"
        hopping_range="$hop_range"
    fi

    # --- ПАРОЛЬ ---
    echo -e "\n${YELLOW}(4/5) Аутентификация:${Font}"
    read -p "Пароль (Enter для генерации): " password
    if [[ -z "$password" ]]; then
        password=$(cat /proc/sys/kernel/random/uuid)
        echo -e "Сгенерирован: ${GREEN}$password${Font}"
    fi

    # --- МАСКИРОВКА ---
    echo -e "\n${YELLOW}(5/5) Маскировка (Masquerade):${Font}"
    read -p "Сайт-жертва [https://www.bing.com]: " masq_site
    masq_site=${masq_site:-"https://www.bing.com"}

    # 4. ГЕНЕРАЦИЯ КОНФИГА
    echo -e "${BLUE}>>> Запись конфигурации...${Font}"
    
    # Генерируем порт для локального API (статистика)
    API_PORT=$(shuf -i 10000-60000 -n 1)

    cat > "$SERVER_CONF" <<EOF
server: $listen_str

$tls_config

auth:
  type: password
  password: $password

# API для статистики (слушает только localhost)
http:
  listen: 127.0.0.1:$API_PORT

masquerade:
  type: proxy
  proxy:
    url: $masq_site
    rewriteHost: true

quic:
  initStreamReceiveWindow: 8388608
  maxStreamReceiveWindow: 8388608
  initConnReceiveWindow: 20971520
  maxConnReceiveWindow: 20971520
  
bandwidth:
  up: 100 mbps
  down: 100 mbps
EOF

    # 5. SYSTEMD
    echo -e "${BLUE}>>> Настройка службы...${Font}"
    cat > /etc/systemd/system/hihy.service <<EOF
[Unit]
Description=Hysteria 2 Server
After=network.target

[Service]
Type=simple
User=root
ExecStart=$APP_BIN server -c $SERVER_CONF
WorkingDirectory=$HY_DIR
Restart=always
RestartSec=3
Environment=HYSTERIA_LOG_LEVEL=info

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable hihy
    systemctl restart hihy

    # 6. ИТОГ
    public_ip=$(get_ip)
    
    # Формируем ссылку
    share_link="hysteria2://$password@$public_ip:$main_port/?sni=$domain&insecure=1"
    if [[ -n "$hopping_range" ]]; then
        share_link="${share_link}&mport=$hopping_range"
    fi
    share_link="${share_link}#Hysteria-RU"

    echo -e "\n${GREEN}=========================================${Font}"
    echo -e "${GREEN}       УСТАНОВКА УСПЕШНО ЗАВЕРШЕНА       ${Font}"
    echo -e "${GREEN}=========================================${Font}"
    echo -e "IP: ${YELLOW}$public_ip${Font}"
    echo -e "Port: ${YELLOW}$main_port${Font}"
    if [[ -n "$hopping_range" ]]; then
        echo -e "Hopping: ${YELLOW}$hopping_range${Font}"
    fi
    echo -e "Password: ${YELLOW}$password${Font}"
    echo -e "SNI: ${YELLOW}$domain${Font}"
    echo -e "Masquerade: ${YELLOW}$masq_site${Font}"
    echo -e "\nСсылка для клиента (v2rayN / NekoBox):"
    echo -e "${BLUE}$share_link${Font}"
    echo -e "${GREEN}=========================================${Font}"

    # Маркер установки
    echo "installed" > "$CONF_FILE"
}

# === УПРАВЛЕНИЕ ===

start_service() {
    systemctl start hihy
    echo -e "${GREEN}Служба запущена.${Font}"
}

stop_service() {
    systemctl stop hihy
    echo -e "${RED}Служба остановлена.${Font}"
}

restart_service() {
    systemctl restart hihy
    echo -e "${GREEN}Служба перезагружена.${Font}"
}

show_status() {
    systemctl status hihy --no-pager
}

show_log() {
    echo -e "${BLUE}Нажмите Ctrl+C для выхода из логов${Font}"
    journalctl -u hihy -f
}

uninstall() {
    echo -e "${RED}!!! ВНИМАНИЕ !!!${Font}"
    read -p "Вы действительно хотите удалить Hysteria 2? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        systemctl stop hihy
        systemctl disable hihy
        rm /etc/systemd/system/hihy.service
        systemctl daemon-reload
        rm -rf "$HY_DIR"
        rm -f "/usr/bin/hihy"
        echo -e "${GREEN}Hysteria 2 полностью удалена.${Font}"
    else
        echo "Отмена."
    fi
}

show_config() {
    if [ -f "$SERVER_CONF" ]; then
        echo -e "${BLUE}Текущий конфиг ($SERVER_CONF):${Font}"
        cat "$SERVER_CONF"
    else
        echo -e "${RED}Конфиг не найден!${Font}"
    fi
}

# Алиас для перенастройки (просто запускает установку заново)
re_config() {
    install_hy2
}