## Поддерживаемые клиенты

Для Hysteria 2 подходят только клиенты с поддержкой ядра v2. Старые клиенты (V2RayNG старых версий, Sagernet) работать не будут.

### Рекомендуемые клиенты:

1.  **Windows / Linux**:
    *   [NekoBox (Nekoray)](https://github.com/MatsuriDayo/nekoray/releases) — Топ-1 выбор. Поддерживает всё из коробки.
    *   [v2rayN](https://github.com/2dust/v2rayN/releases) — Классика. Требует скачивания ядра Hysteria 2 Core в папку bin.

2.  **Android**:
    *   [NekoBox for Android](https://github.com/MatsuriDayo/NekoBoxForAndroid/releases) — Лучший вариант.
    *   [v2rayNG](https://github.com/2dust/v2rayNG) — Нужен плагин Hysteria Plugin (но лучше сразу NekoBox).

3.  **iOS (iPhone/iPad)**:
    *   **Shadowrocket** ($2.99) — Самый стабильный.
    *   **V2Box** — Бесплатный, но может быть менее стабильным.
    *   **Streisand**.

### Советы по настройке:

*   **Port Hopping:** Если вы включили прыжки портов на сервере, убедитесь, что клиент подхватил параметр `mport` (диапазон портов) из ссылки.
*   **QUIC / HTTP3 Error:** Если в браузере не открываются сайты с HTTP/3 (YouTube, Google), попробуйте в настройках клиента (NekoBox) включить "Strict Route" или отключить экспериментальные QUIC фичи в браузере.
*   **Скорость:** Если скорость низкая, проверьте настройки `Up/Down` bandwidth в клиенте. Если они стоят `0` (безлимит), некоторые клиенты могут работать некорректно. Лучше выставить реальную скорость вашего интернета (например, 100 Mbps).
