# Keep Pixel 1.1: обновление клиента и сервера

Канонический клиент — `savva643/Keep-Pixel`. В Necsoura синхронизирована копия `source/services/keeppixel/frontend-mobile`. Бэкенд — `source/services/keeppixel/backend`.

## Что работает

- Каталог и подробности без входа, поиск, фильтры, постраничная загрузка, состояния ошибок и повторная загрузка.
- Настоящий вход Necsoura: `prelogin` → Argon2id + HKDF → `login`, второй фактор и резервный код, обновление и завершение сеанса. Сеансы хранятся в защищённом хранилище платформы. На web требуется HTTPS или localhost.
- Общий профиль берётся из **того же Kompot-профиля, который используют сайт Necsoura и Blast**. ID, приватный логин и публичный username не меняются через Keep Pixel. Они видны владельцу профиля; публичного endpoint с логином нет.
- Имя, фото, шапка и описание по умолчанию общие. Для каждого поля можно включить своё значение только в Keep Pixel, очистить картинку/описание либо вернуть наследование. Изменения общего профиля не затирают местные настройки.
- Бесплатные опубликованные игры добавляются в библиотеку через сервер. Платные и ещё не выпущенные игры бесплатно не выдаются.
- Windows: загрузка опубликованного ZIP, проверка точного размера и SHA-256, отмена, проверка путей при распаковке, установка в папку приложения, запуск после проверки лицензии. Старые папки установок автоматически не импортируются.
- Шрифты включены в приложение; для запуска интерфейса не требуется Google Fonts.
- Адаптивный интерфейс: боковая панель на ПК, нижняя навигация на телефоне, скруглённые карточки, реальная информация вместо выдуманных рейтингов/достижений.

## Порядок обновления сервера

Сначала объедините PR бэкенда в Necsoura и обновите серверный checkout. Команды из корня **Necsoura**:

```sh
git pull --ff-only
mkdir -p backups
docker compose -f infra/docker/docker-compose.yml exec -T keeppixel-postgres pg_dump -U keeppixel -d keeppixel -Fc > "backups/keeppixel-$(date +%Y%m%d-%H%M%S).dump"
docker compose -f infra/docker/docker-compose.yml up -d --build keeppixel-backend
docker compose -f infra/docker/docker-compose.yml logs --tail=80 keeppixel-backend
docker compose -f infra/docker/docker-compose.yml exec -T keeppixel-backend node scripts/import-catalog.js
docker compose -f infra/docker/docker-compose.yml exec -T nginx nginx -t
docker compose -f infra/docker/docker-compose.yml exec -T nginx nginx -s reload
curl --fail https://necsoura.ru/api/keeppixel/health
```

Миграции выполняются при старте контейнера и записываются в `schema_migrations`. Старую `001_init.sql` не меняли. `002` создаёт отсутствующие таблицы на новой базе, `003` сохраняет существующие местные имя/аватар/описание как overrides. Том PostgreSQL сохраняется. **Не выполняйте `down -v`.** При ошибке остановитесь и сохраните лог; не удаляйте запись миграции вручную.

Для профиля нужен доступ контейнера к `PROFILE_SERVICE_URL=http://kompot-backend:3000/api`; compose уже настроен. Auth и Kompot не требуют изменения схемы. Nginx добавляет только маршрут `/api/keeppixel/` на существующем сайте Necsoura. Внешний прокси должен сохранять этот маршрут и HTTPS.

В `infra/docker/.env` для отдельного web-клиента при необходимости задайте `KEEP_PIXEL_CORS_ORIGINS=https://ВАШ-ДОМЕН-КЛИЕНТА` (точные origin через запятую). Для приложения Windows/Android/macOS CORS не нужен. Авторизационный сервис должен также разрешать origin web-клиента; существующие настройки auth здесь не расширяются автоматически.

## Сборка клиента

После обновления сервера, из **Keep-Pixel**:

```sh
git pull --ff-only
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

Windows собирайте на Windows с Flutter и Visual Studio C++ tools: `flutter build windows --release`. Android: `flutter build apk --release` (для распространения настройте свою подпись; прежняя debug-подпись в проекте не заменена). Linux для защищённого хранилища требует `libsecret-1-dev` и рабочую keyring-службу; macOS — Xcode и Keychain Sharing (entitlements добавлены).

При других доменах используйте:

```sh
flutter run -d windows --dart-define=KEEP_PIXEL_API_URL=https://ВАШ-ДОМЕН/api/keeppixel --dart-define=NECSOURA_AUTH_URL=https://ВАШ-AUTH/api/auth
flutter build web --release --no-web-resources-cdn
```

По умолчанию API: `https://necsoura.ru/api/keeppixel`, auth: `https://auth.keep-pixel.ru/api/auth`. В параметры не передаются секреты. Устанавливать игры из браузера нельзя: используйте клиент Windows.

## Каталог и границы версии

Проверенный по исходникам проект **Keep Pixel Platform** добавлен в импорт как «В разработке», без выдуманного установщика или обложки. Импорт не меняет существующие игры и цены. Остальные названия и релизы должен подтвердить владелец; старый PHP API `keeppixel.store/api.php` на момент проверки отвечал HTTP 403, поэтому его содержимое не выдаётся за перенесённое.

Формат карточек и Windows-сборок описан в `Necsoura/source/services/keeppixel/backend/catalog/README.md`. До публикации действующего манифеста кнопка установки не появляется. Оплата, запуск iOS/Android-приложений из магазина, OAuth/QR-вход непосредственно в клиенте и отдельная система достижений не реализованы. Регистрация и восстановление аккаунта открываются на сайте Necsoura.

## Что проверить после обновления

Войти своим аккаунтом, сверить фото/шапку/имя/описание и username с сайтом, изменить одно поле только для Keep Pixel, вернуть наследование. Добавить опубликованную бесплатную игру и открыть библиотеку. После публикации Windows ZIP проверить установку, отмену, обновление и запуск. Завершить сеанс на сайте Necsoura и убедиться, что клиент просит войти снова.

Локально проверяются Node API с настоящим PostgreSQL-движком PGlite и тестовыми upstream-ответами, Flutter API/виджеты/распаковка и release web-сборка. Производственный сервер и запуск Windows EXE на этом Linux-хосте не проверялись.
