# Keep Pixel

Магазин и библиотека игр с единым аккаунтом Necsoura. Flutter-клиент для ПК и телефонов; web для просмотра каталога и управления библиотекой.

```sh
flutter pub get
flutter run -d windows
```

Бэкенд находится в `savva643/Necsoura`, `source/services/keeppixel/backend`. Перед запуском новой версии обновите сервер: [инструкция, возможности и ограничения](docs/UPDATE.md).

Клиент использует настоящие Necsoura-сессии. Фото, шапка, имя и описание наследуются из общего профиля либо меняются только для Keep Pixel; ID, логин и username остаются общими.

```sh
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn
```
