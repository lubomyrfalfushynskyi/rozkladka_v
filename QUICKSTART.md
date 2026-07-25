# 🚀 Quick Start — РозкладкаВ

## ⚡ Середовище (вже налаштовано в WSL)

- Flutter SDK: `~/development/flutter`
- Android SDK: `~/Android/sdk`
- JDK 21 (Temurin, portable): `~/development/jdk/jdk-21.0.12+8`
  (системний `openjdk-21-jre` без `javac` не годиться для Gradle-збірки)

Усе прописано в `~/.bashrc` (`PATH`, `ANDROID_HOME`, `JAVA_HOME`) — новий
термінал підхоплює автоматично.

## 📱 Збірка APK

```bash
cd ~/rozkladka_v
flutter build apk --debug     # для тестування
flutter build apk --release   # для реального розгортання (потребує підпису)
```

Готовий файл: `build/app/outputs/flutter-apk/app-debug.apk` (або `app-release.apk`).

## 📥 Встановлення на телефон

Найпростіше — скопіювати APK на телефон (через файловий менеджер/хмару/USB)
і встановити напряму (дозволити "встановлення з невідомих джерел").

Якщо телефон підключено по USB і видно в `adb devices`:

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

## 🧪 Тести та аналіз

```bash
flutter analyze
flutter test
```

## 🐛 Проблеми?

### `flutter doctor` скаржиться на Chrome / Linux desktop toolchain
Ігнорувати — застосунок лише під Android, ці платформи не потрібні.

### Gradle не бачить компілятор Java
Переконайтесь, що `JAVA_HOME` вказує на `~/development/jdk/jdk-21.0.12+8`
(повний JDK), а не на системний `openjdk-21-jre` (лише runtime, без `javac`).

---

**Версія:** 1.0.0
**Платформа:** Flutter (Android), WSL2 (Ubuntu 24.04 LTS)

**Автор:** Фальфушинський Ярослав
**Розробник:** Фальфушинський Любомир · © 2026
