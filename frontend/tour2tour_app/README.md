# Tour2Tour Flutter App

Flutter-клиент поддерживает:
- Web
- Android
- iOS

## Локальный запуск

Все команды выполняются из:
`C:\Users\Valeria\tour2tour\frontend\tour2tour_app`

### Web против локального backend
```bash
flutter pub get
flutter run -d chrome
```

По умолчанию web использует:
- `http://127.0.0.1:8888`

### Android emulator против локального backend
```bash
flutter pub get
flutter run -d emulator-5554
```

По умолчанию emulator использует:
- `http://10.0.2.2:8888`

### Запуск против production API
```bash
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=https://api.24tour2tour.ru
```

## Production build

```bash
flutter build web --release --dart-define=API_BASE_URL=https://api.24tour2tour.ru
```

## Очистка

```bash
flutter clean
flutter pub get
```

## Где задается API base URL

Файл:
- [config.dart](c:/Users/Valeria/tour2tour/frontend/tour2tour_app/lib/config.dart)

Локальные значения:
- web: `http://127.0.0.1:8888`
- emulator: `http://10.0.2.2:8888`

Production задается через:
- `--dart-define=API_BASE_URL=...`
