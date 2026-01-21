# tour2tour_app

A new Flutter project.

## Структура проекта

Ниже кратко описано, где что находится, чтобы быстро ориентироваться в коде.

### Основное приложение

- `lib/main.dart` — точка входа Flutter, инициализация `MaterialApp.router`.
- `lib/router.dart` — маршрутизация на `go_router`, редиректы по авторизации.
- `lib/config.dart` — конфигурация и константы приложения.
- `lib/api/api_client.dart` — HTTP-клиент (на `dio`) и базовая работа с API.
- `lib/core/token_storage.dart` — хранение токена в защищенном хранилище.

### Фичи (feature-based структура)

- `lib/features/auth/` — авторизация.
  - `auth_repo.dart` — репозиторий и сетевые запросы.
  - `login_page.dart` — экран входа.
  - `register_page.dart` — экран регистрации.
- `lib/features/preferences/` — пользовательские предпочтения.
  - `preferences_repo.dart` — репозиторий и работа с API.
  - `preferences_page.dart` — экран предпочтений.

### Тесты

- `test/widget_test.dart` — базовый виджет-тест (шаблон Flutter).

### Платформенные папки Flutter (стандарт)

- `android/`, `ios/`, `macos/`, `windows/`, `linux/`, `web/` — нативные оболочки и сборка под каждую платформу.

### Конфигурация

- `pubspec.yaml` — зависимости, метаданные и ассеты.
- `analysis_options.yaml` — правила анализа кода.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
