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

# === УПРАВЛЕНИЕ СЛУЖБОЙ ===
start_service() { systemctl start hihy; echo -e "${GREEN}Служба запущена.${Font}"; }
stop_service() { systemctl stop hihy; echo -e "${RED}Служба остановлена.${Font}"; }
restart_service() { systemctl restart hihy; echo -e "${GREEN}Служба перезагружена.${Font}"; }
show_status() { systemctl status hihy --no-pager; }

# === УДАЛЕНИЕ ===
uninstall() {
    echo -e "${RED}!!! ВНИМАНИЕ !!!${Font}"
    read -p "Вы действительно хотите удалить Hysteria 2? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        systemctl stop hihy
        systemctl disable hihy
        rm -f /etc/systemd/system/hihy.service
        systemctl daemon-reload
        rm -rf "$HY_DIR"
        # Не удаляем /usr/bin/hihy если это симлинк на репо, но конфиг чистим
        echo -e "${GREEN}Hysteria 2 удалена. (Скрипт управления остался)${Font}"
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

re_config() { install_hy2; }

# === УСТАНОВКА (MAIN LOGIC) ===
install_hy2() {
    check_root
    check_sys
    install_dependencies

    ARCH=$(get_arch)
    if [ "$ARCH" == "unknown" ]; then
        echo -e "${RED}Ошибка: Архитектура $(uname -m) не поддерживается!${Font}"
        exit 1
    fi

    echo -e "${BLUE}>>> Скачивание ядра Hysteria 2 ($ARCH)...${Font}"
    # Используем --max-redirect для надежности
    DOWNLOAD_URL="https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-${ARCH}"
    wget -q --show-progress --max-redirect 5 -O "$APP_BIN" "$DOWNLOAD_URL"
    
    if [ ! -s "$APP_BIN" ]; then
        echo -e "${RED}Ошибка: Скачивание не удалось (файл пуст). Проверьте интернет.${Font}"
        rm -f "$APP_BIN"
        exit 1
    fi
    chmod +x "$APP_BIN"

    # --- WIZARD ---
    echo -e "${GREEN}>>> Настройка Hysteria 2${Font}"

    # 1. Сертификат
    echo -e "\n${YELLOW}(1/6) Сертификат:${Font}"
    echo -e "${GREEN}1)${Font} ACME (Let's Encrypt) - Нужен домен + 80 порт"
    echo -e "${GREEN}2)${Font} Self-signed (Bing) - Для IP (включите Allow Insecure в клиенте)"
    echo -e "${GREEN}3)${Font} Свои файлы"
    read -p "Выбор [1]: " cert_choice
    cert_choice=${cert_choice:-1}

    tls_config=""
    domain=""
    
    if [[ "$cert_choice" == "1" ]]; then
        read -p "Введите ваш домен: " domain
        if [[ -z "$domain" ]]; then echo -e "${RED}Домен обязателен!${Font}"; exit 1; fi
        tls_config="acme:
  domains:
    - $domain
  email: admin@$domain"
    elif [[ "$cert_choice" == "2" ]]; then
        echo -e "${BLUE}Генерируем самоподписанный сертификат...${Font}"
        domain="www.bing.com"
        openssl req -x509 -newkey rsa:2048 -nodes -sha256 -keyout "$CERT_DIR/self.key" -out "$CERT_DIR/self.crt" -days 3650 -subj "/CN=$domain" 2>/dev/null
        tls_config="tls:
  cert: $CERT_DIR/self.crt
  key: $CERT_DIR/self.key"
    elif [[ "$cert_choice" == "3" ]]; then
        read -p "Путь к .crt: " user_crt
        read -p "Путь к .key: " user_key
        if [ ! -f "$user_crt" ] || [ ! -f "$user_key" ]; then echo -e "${RED}Файлы не найдены!${Font}"; exit 1; fi
        cp "$user_crt" "$CERT_DIR/custom.crt"
        cp "$user_key" "$CERT_DIR/custom.key"
        tls_config="tls:
  cert: $CERT_DIR/custom.crt
  key: $CERT_DIR/custom.key"
    fi

    # 2. Порты
    echo -e "\n${YELLOW}(2/6) Порт сервера:${Font}"
    read -p "Основной порт [443]: " main_port
    main_port=${main_port:-443}
    
    # Проверка занятости порта
    if lsof -i :$main_port >/dev/null 2>&1; then
        echo -e "${RED}Внимание: Порт $main_port уже занят!${Font}"
        read -p "Все равно использовать? [y/N]: " force_port
        if [[ ! "$force_port" =~ ^[Yy]$ ]]; then exit 1; fi
    fi

    listen_str=":$main_port"
    hopping_range=""

    echo -e "\n${YELLOW}(3/6) Port Hopping (Диапазон портов):${Font}"
    read -p "Включить? [Y/n]: " hop_yn
    hop_yn=${hop_yn:-Y}

    if [[ "$hop_yn" =~ ^[Yy]$ ]]; then
        read -p "Диапазон [20000-50000]: " hop_range
        hop_range=${hop_range:-"20000-50000"}
        listen_str=":$main_port,$hop_range"
        hopping_range="$hop_range"
    fi

    # 3. Скорость (Bandwidth) - ВАЖНО для Hysteria
    echo -e "\n${YELLOW}(4/6) Скорость (Bandwidth):${Font}"
    echo "Укажите РЕАЛЬНУЮ скорость (или чуть меньше). Не ставьте 1Gbps на 100Mbps канале!"
    read -p "Скорость загрузки (Download) [100 mbps]: " bw_down
    bw_down=${bw_down:-"100 mbps"}
    read -p "Скорость отдачи (Upload) [100 mbps]: " bw_up
    bw_up=${bw_up:-"100 mbps"}

    # 4. Пароль
    echo -e "\n${YELLOW}(5/6) Аутентификация:${Font}"
    read -p "Пароль (Enter для автогенерации): " password
    if [[ -z "$password" ]]; then
        password=$(cat /proc/sys/kernel/random/uuid)
    fi

    # 5. Маскировка
    echo -e "\n${YELLOW}(6/6) Маскировка:${Font}"
    read -p "Сайт-жертва [https://www.bing.com]: " masq_site
    masq_site=${masq_site:-"https://www.bing.com"}

    # --- GENERATE CONFIG ---
    echo -e "${BLUE}>>> Запись конфига...${Font}"
    API_PORT=$(get_random_port)

    cat > "$SERVER_CONF" <<EOF
server: $listen_str

$tls_config

auth:
  type: password
  password: $password

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
  up: $bw_up
  down: $bw_down
EOF

    # --- SYSTEMD ---
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
# Отключаем лимиты для QUIC
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable hihy
    systemctl restart hihy

    # --- REPORT ---
    public_ip=$(get_ip)
    
    # Формируем V2RayN/NekoBox URL
    # Формат: hysteria2://password@host:port/?sni=sni&insecure=1&mport=range#Name
    share_link="hysteria2://$password@$public_ip:$main_port/?sni=$domain&insecure=1"
    if [[ -n "$hopping_range" ]]; then
        share_link="${share_link}&mport=$hopping_range"
    fi
    share_link="${share_link}#Hysteria-RU-Node"

    echo -e "\n${GREEN}=== УСТАНОВКА ЗАВЕРШЕНА ===${Font}"
    echo -e "IP: ${YELLOW}$public_ip${Font}"
    echo -e "Port: ${YELLOW}$main_port${Font}"
    echo -e "Password: ${YELLOW}$password${Font}"
    echo -e "Bandwidth: ${YELLOW}$bw_down / $bw_up${Font}"
    echo -e "\nСсылка для клиента:"
    echo -e "${BLUE}$share_link${Font}"
    
    echo "installed" > "$CONF_FILE"
}