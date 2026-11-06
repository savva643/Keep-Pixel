# Проверка присланного KeepPixelPlugin.zip

Исходный архив — ранний прототип с шестью API-методами и ShowOverlay, а не готовая
система интеграции уровня Steamworks. В архиве есть исходники и сгенерированные
Intermediate-файлы, но нет готовой DLL SDK или KeepPixelOverlay.exe.

| В исходнике | Проблема | Что изменено |
| --- | --- | --- |
| BASE_URL=https://keep-pixel.ru/api.php | старый action/PHP протокол несовместим с нынешним Node API | единый локальный HTTP SDK v1 через лаунчер |
| REQUEST_TOKEN на фиксированном localhost:27060 | синхронное ожидание и выдача аккаунтного токена игре | случайный порт и отдельный ключ на игру в окружении |
| UE_LOG с Received token | секрет попадает в игровые логи | логирование ключа удалено; игра не получает JWT аккаунта |
| UTF8_TO_TCHAR(Buffer) без длины/нулевого конца | возможен выход за принятые данные | сырой TCP буфер полностью удалён |
| UserID=int32 | общий UUID не помещается в int32 | строковый GlobalID во всех адаптерах |
| GetStringField/GetBoolField без проверки, редкие callbacks при ошибках | ошибки JSON/сети оставляли Blueprints без результата | проверяем envelope и поля; явные Success/Error callbacks |
| ShowOverlay запускает Overlay/KeepPixelOverlay.exe | такого EXE в архиве нет; Shift+Tab не подключён | панель в Flutter-клиенте, Windows method channel и hotkey |
| UTF-16 .uplugin, Intermediate/Build с абсолютными путями | непереносимый дистрибутив и лишние результаты чужой сборки | чистый UTF-8 descriptor и только исходники |

Проверен современный backend: Keep Pixel проксирует список/заявки/блокировки в общий
friends-service; профили и presence обогащаются отдельно. Полный жизненный цикл заявок
и блокировок тестируется через реальные Express-маршруты двух сервисов и PGlite.
Для SDK добавлены game_id/game_title в списке друзей и строгий boolean license/check,
с отказом на некорректный ID. Временные ошибки не превращаются в выдуманные данные.

Новая интеграция и честная матрица возможностей: [SDK](../sdk/README.md).
Проверки этой поставки проводились локально, без GitHub Actions. Кросс-компиляция
Windows runner подтверждает синтаксис Win32/method channel с заголовками текущего
Flutter; она не заменяет проверку фокуса/Shift+Tab в Windows и сборку UHT/UBT в UE.
