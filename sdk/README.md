# Keep Pixel Game SDK v0.2 / protocol v1

Общий SDK для игр, запущенных из Keep Pixel. HTTP/JSON контракт не зависит от
движка. Друзья и общий UUID берутся из Necsoura; отдельная база друзей в игре не нужна.

| Возможность | Состояние |
| --- | --- |
| Профиль: UUID, username, имя, фото, описание Keep Pixel | реализовано |
| Принятые друзья, статус, ID и название текущей игры | реализовано через общий friends-service |
| Проверка владения запущенной игрой | реализовано, ответ boolean |
| Присутствие in_game / away | реализовано, ID игры закреплён за ключом |
| Панель Flutter: друзья, заявки, поиск, блокировки, профиль | реализовано в Windows runner для оконного режима / без рамки |
| UE5 Blueprint/C++ адаптер | исходники готовы, сборка UHT/UBT и packaged-game тест ещё нужны |
| Unity 2021.3+ адаптер | исходники готовы, сборка и запуск в Unity ещё нужны |
| Godot 4.x адаптер | проверен обмен с настоящим локальным SDK, Godot 4.6.3 headless |
| Python 3.9+ адаптер | проверен обмен с настоящим локальным SDK |
| Приглашения / join-game, чат внутри игры, достижения, cloud saves | ещё не реализованы |
| Проверяемые игровым сервером auth tickets / античит / полноценный DRM | ещё не реализованы |
| Оверлей в эксклюзивном полном экране, Vulkan/DX injection | ещё не реализован |
| Установка и запуск игр лаунчером Linux/macOS | ещё не реализованы; контракт SDK переносимый |

Это первая интеграция платформы, а не полная реализация Steamworks.

## Как подключать игру

1. В каталоге должна быть опубликованная сборка с корректным SHA-256 и файлом запуска;
   игра должна находиться в библиотеке пользователя. Существующий установщик проверяет
   эти условия, размер, SHA-256 и пути архива.
2. Игру запускает лаунчер. Он поднимает HTTP сервер **только на 127.0.0.1**, на свободном
   порту, и передаёт дочернему процессу:
   - `KEEPPIXEL_SDK_URL=http://127.0.0.1:<порт>/v1`;
   - `KEEPPIXEL_SDK_TOKEN=<случайный ключ конкретной игры>`;
   - `KEEPPIXEL_GAME_ID=<числовой ID игры>`.
3. Адаптер читает эти значения из окружения. Не вписывай адрес сервера, пользовательский
   пароль, JWT или refresh token в игру. Не передавай ключ в аргументах командной строки,
   логи или публичные crash reports.
4. При завершении процесса, выходе из аккаунта, смене сервера или закрытии лаунчера
   ключ отзывается. Все ответы завершающихся запросов также проверяют поколение аккаунта.
5. Если у игры есть bootstrapper, который завершается до игрового процесса, укажи
   непосредственно игровой executable. Первая версия отслеживает PID запущенного
   процесса, а не произвольное дерево процессов. Это особенно важно для UE packaged builds.

SDK не даёт игре покупать/удалять игры, менять профиль, отправлять заявки или читать
login/email/токены. Такие действия пользователь выполняет в панели самого лаунчера.
Игра может читать принятых друзей и менять только свой игровой статус. Ключи находятся
в памяти; общий фиксированный TCP порт и сервер выдачи аккаунтного JWT не используются.

Локальный capability API не изолирует вредоносный код, запущенный от того же пользователя
ОС. Данные профиля и результат license нельзя использовать вместо серверной аутентификации
игрока в сетевом матче. Для этого нужен следующий этап: короткоживущие auth tickets с
проверкой audience и серверной верификацией. На отдельном ПК без лаунчера этот SDK не работает.

## Контракт

Все запросы: `Authorization: Bearer <KEEPPIXEL_SDK_TOKEN>`, `Accept: application/json`.
POST также требует `Content-Type: application/json`. Адрес берётся только из окружения,
а не с сайта. HTTP допустим здесь, поскольку соединение локальное; обращения лаунчера
к публичному серверу настраивай через HTTPS.

| Метод | Путь относительно SDK_URL | Результат / тело запроса |
| --- | --- | --- |
| GET | `/session` | protocol=1, game_id, title, features |
| GET | `/profile` | global_id (строка UUID), username, name, avatar, banner, bio |
| GET | `/friends` | массив global_id, username, name, avatar, presence, game_id, game_title |
| GET | `/license` | game_id, owned (boolean) |
| POST | `/presence` | `{"status":"in_game"}` либо `{"status":"away"}` |
| POST | `/overlay` | `{"visible":true}` / `{"visible":false}` |

`game_id` друга равен 0, если игра неизвестна/не запущена; название может быть пустым.
Действия с другим ID игры не принимаются. Profile UUID всегда строка, не int32.
Успех: `{"ok":true,"data":...}`. Ошибка: `{"ok":false,"error":{"code":"...","message":"..."}}`.
401 — ключ отозван, 403 — браузер/неверный Host, 404 — операция отсутствует,
429 — превышен лимит, 501 — панель недоступна, 503 — недоступен сервис.
Лимиты: 120 запросов/минуту на игру, 4 параллельных запроса, POST не больше 4096 байт.
Не опрашивай друзей каждый кадр: достаточно раз в 15–30 секунд.
Проверяй `features` и обрабатывай отказ, особенно для отсутствующего overlay.

Браузерные Origin/Sec-Fetch запросы отклоняются, CORS для SDK не открыт; веб-страница
не должна получать этот ключ. Для WebGL/HTML5 игр потребуется отдельная схема интеграции.

## UE5

Скопируй [ue5/KeepPixelPlugin](ue5/KeepPixelPlugin) в `<Project>/Plugins/KeepPixelPlugin/`,
перегенерируй файлы проекта и собери Development Editor. Включи плагин и перезапусти UE.
`Binaries/` и `Intermediate/` из старого архива не нужны.

Blueprint GameInstance Init: `Initialize From Launcher` → проверить bool и Error.
Далее `Get User Profile`, `Get Friends List`, `Check License`, `Set Presence`,
`Set Overlay Visible`. Каждый запрос асинхронный и вызывает Completed с Success/Error,
включая ошибку сети, отсутствие окружения и неожиданный JSON.

Новые структуры: `FKeepPixelProfile` и `FKeepPixelFriend`. Переподключи старые ноды:
в старом прототипе `ReceiveToken`, `CheckTokenAndLicense(Token, GameID)` и числовой UserID
относились к другому PHP API. Игре больше не нужен аккаунтный Token; ID игры берётся
из её сеанса. Поля XP, Money, Moder/Banned не выдаются SDK и не подставляются как выдуманные данные.
В UE editor без окружения лаунчера Initialize вернёт понятную ошибку. Начальный end-to-end
сценарий — packaged Development/Shipping build, запущенный из библиотеки Keep Pixel.

Проверка компиляции в Windows:

```powershell
& "$env:UE_ROOT\Engine\Build\BatchFiles\RunUAT.bat" BuildPlugin `
  "-Plugin=$PWD\sdk\ue5\KeepPixelPlugin\KeepPixelPlugin.uplugin" `
  "-Package=$PWD\build\KeepPixelPlugin" -TargetPlatforms=Win64
```

После компиляции проверь packaged игру, UUID/друзей, потерю связи, выход из аккаунта
и отзыв ключа после завершения. Заявленная совместимость конкретных версий UE требует
такого теста; исходники здесь не равны проверенному бинарному плагину.

## Unity, Godot, собственный движок

Unity: скопируй [unity/KeepPixelClient.cs](unity/KeepPixelClient.cs) в Assets/KeepPixel.
Пример из MonoBehaviour:

```csharp
var pixel = new Necsoura.KeepPixel.KeepPixelClient();
StartCoroutine(pixel.GetFriends(
    friends => Debug.Log($"Friends: {friends.Length}"),
    error => Debug.LogWarning(error.message)));
```

Godot: добавь [godot/keep_pixel_client.gd](godot/keep_pixel_client.gd) как Node:

```gdscript
var pixel = KeepPixelClient.new()
add_child(pixel)
var response = await pixel.get_friends()
if response.ok:
    for friend in response.data:
        print(friend.name, ": ", friend.presence)
```

Python: добавь sdk/python в путь импорта; [пример игры](examples/python_game.py).
Любой другой движок использует тот же HTTP контракт без DLL под конкретный движок.

## Панель Shift+Tab

Нужна новая Windows-сборка Flutter-клиента. Во время работы запущенной игры runner
регистрирует Shift+Tab только когда игра или панель находятся на переднем плане.
Панель переиспользует Flutter окно лаунчера и общие экраны друзей/профиля; Esc и кнопка
возвращают в игру. При закрытии восстанавливаются размер, стили окна и фокус.
Если сочетание занято, лаунчер показывает ошибку. SDK также может запросить панель;
Windows может отказать в переводе фокуса фоновому процессу — обработай ошибку.

Это окно поверх игры в оконном режиме / без рамки. Оно не встраивает Flutter в
графический pipeline игры и не обещает работу поверх exclusive fullscreen или античита.
Глобальный захват клавиатуры, внедрение DLL и обход античита не используются.

## Проверки

```bash
flutter analyze
flutter test
KEEP_PIXEL_TEST_ENGINE_ADAPTERS=1 flutter test test/game_sdk_test.dart
```

Последняя команда дополнительно запускает Python 3 и Godot 4, подключая их к реальному
локальному серверу SDK во Flutter-тесте. Протестированы закрытие ключей, изоляция
аккаунта, фильтрация данных, лимиты, game-bound license/presence и недопуск браузера.
Изолированная проверка UE5 и Unity остаётся обязательной; сам Windows GUI runtime
нужно проверить на реальной Windows-сборке.
