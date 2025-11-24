#!/bin/bash

# Главное меню
show_menu() {
    echo -e "
${GREEN}Tips: введите ${RED}hihy${GREEN} для повторного запуска этого меню.${Font}
.............................................
${GREEN}###############################${Font}
.....................
${GREEN}1)${Font}  Установить Hysteria 2
${GREEN}2)${Font}  Удалить Hysteria
.....................
${GREEN}3)${Font}  Запустить сервер
${GREEN}4)${Font}  Остановить сервер
${GREEN}5)${Font}  Перезагрузить сервер
${GREEN}6)${Font}  Статус службы
.....................
${GREEN}7)${Font}  Обновить ядро (Core)
${GREEN}8)${Font}  Посмотреть конфигурацию
${GREEN}9)${Font}  Перенастроить (Сертификат/Порты/Пароль)
${GREEN}10)${Font} Приоритет IPv4/IPv6
${GREEN}11)${Font} Обновить скрипт hihy
${GREEN}12)${Font} Настройка ACL (Блокировка доменов)
${GREEN}13)${Font} Статистика сервера (Трафик/Юзеры)
${GREEN}14)${Font} Логи в реальном времени
${GREEN}15)${Font} Добавить Socks5 выход (для Warp/Netflix)
${GREEN}###############################${Font}
${GREEN}0)${Font} Выход
.............................................
"
    read -p "Пожалуйста, выберите действие: " num
    run_command "$num"
}

# Обработчик команд (чтобы работало и через меню, и через аргументы hihy 1)
run_command() {
    case "$1" in
    1)
        check_uninstall && install_hy2
        ;;
    2)
        check_install && uninstall
        ;;
    3)
        check_install && start_service
        ;;
    4)
        check_install && stop_service
        ;;
    5)
        check_install && restart_service
        ;;
    6)
        check_install && show_status
        ;;
    7)
        check_install && update_core
        ;;
    8)
        check_install && show_config
        ;;
    9)
        check_install && re_config
        ;;
    10)
        check_install && switch_ipv4_ipv6
        ;;
    11)
        update_hihy
        ;;
    12)
        check_install && manage_acl
        ;;
    13)
        check_install && check_stats
        ;;
    14)
        check_install && show_log
        ;;
    15)
        check_install && add_socks5_outbound
        ;;
    0)
        exit 0
        ;;
    *)
        echo -e "${RED}Ошибка: введите правильную цифру [0-15]${Font}"
        ;;
    esac
}