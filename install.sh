#!/bin/bash

# ==========================================
# Hi Hysteria (RU) - Bootstrap Installer
# ==========================================

# 1. Проверка прав root
if [[ $EUID -ne 0 ]]; then
    echo -e "\033[31mError: Запустите скрипт от имени root!\033[0m"
    exit 1
fi

# 2. Установка Git (если нет)
if ! command -v git &> /dev/null; then
    echo -e "\033[36m>>> Установка Git...\033[0m"
    if [[ -f /etc/redhat-release ]]; then
        yum install -y git
    else
        apt-get update && apt-get install -y git
    fi
fi

# 3. Скачивание репозитория
echo -e "\033[36m>>> Скачивание Hi Hysteria RU...\033[0m"
TMP_DIR="/tmp/hihy_install"
REPO_URL="https://github.com/Rewixx-png/Hi_Hysteria_RU.git"

rm -rf "$TMP_DIR"
git clone --depth=1 "$REPO_URL" "$TMP_DIR"

if [ ! -d "$TMP_DIR/server" ]; then
    echo -e "\033[31mError: Не удалось скачать репозиторий или структура папок неверна.\033[0m"
    echo "Ожидалась папка: server/"
    exit 1
fi

# 4. Установка файлов
INSTALL_DIR="/etc/hihy"
mkdir -p "$INSTALL_DIR"

# Копируем server внутрь /etc/hihy (получится /etc/hihy/server)
# Используем cp -r, чтобы перезаписать старые скрипты, но не трогать конфиги (если они в conf/)
echo -e "\033[36m>>> Обновление файлов...\033[0m"
cp -rf "$TMP_DIR/server" "$INSTALL_DIR/"

# Выдаем права на исполнение
chmod +x "$INSTALL_DIR/server/hihy"
chmod +x "$INSTALL_DIR/server/lib/"*.sh

# 5. Создание симлинка (чтобы работала команда hihy)
ln -sf "$INSTALL_DIR/server/hihy" /usr/bin/hihy

# 6. Очистка мусора
rm -rf "$TMP_DIR"

# 7. Запуск
echo -e "\033[32m>>> Установка загрузчика завершена.\033[0m"
echo -e "Запускаем меню..."
sleep 1
hihy