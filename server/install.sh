#!/bin/bash

# === УСТАНОВЩИК HIHY (MODULAR) ===
# URL твоего репозитория
REPO_URL="https://github.com/Rewixx-png/Hi_Hysteria_RU.git"
INSTALL_DIR="/etc/hihy"
BIN_LINK="/usr/bin/hihy"

RED="\033[31m"
GREEN="\033[32m"
Font="\033[0m"

echo -e "${GREEN}>>> Установка Hysteria 2 Manager (RU)...${Font}"

# 1. Проверка Git
if ! command -v git &> /dev/null; then
    echo "Git не найден. Устанавливаем..."
    if [ -f /etc/debian_version ]; then
        apt update && apt install -y git
    elif [ -f /etc/redhat-release ]; then
        yum install -y git
    fi
fi

# 2. Очистка старой установки
if [ -d "$INSTALL_DIR" ]; then
    echo "Обнаружена старая версия. Обновляем..."
    rm -rf "$INSTALL_DIR"
fi

# 3. Клонирование
echo "Клонирование репозитория..."
git clone "$REPO_URL" "$INSTALL_DIR"

if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${RED}Ошибка: Не удалось клонировать репозиторий!${Font}"
    exit 1
fi

# 4. Настройка прав
chmod +x "$INSTALL_DIR/server/hihy"
chmod +x "$INSTALL_DIR/server/lib/"*.sh

# 5. Создание симлинка
rm -f "$BIN_LINK"
ln -s "$INSTALL_DIR/server/hihy" "$BIN_LINK"

echo -e "${GREEN}>>> Установка завершена!${Font}"
echo -e "Запустите меню командой: ${GREEN}hihy${Font}"
