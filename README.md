# vibration

Нативное iOS-приложение на SwiftUI: телефон вибрирует в такт басам музыки, а вторая вкладка превращает iPhone
в 3D-сканер глубины с тактильным «парктроником».

**Неподписанная сборка (unsigned IPA)** — ставится через AltStore / SideStore / Sideloadly.
Минимальная версия iOS 15.0, arm64, iPhone XS Max и все более новые модели.

## Что внутри

### 1. Музыка
- импорт локальных файлов (`.mp3`, `.wav`, `.m4a`, `.flac`, `.aiff`, …) через системный `fileImporter`;
  файл копируется в приватную папку приложения, поэтому доступ не теряется;
- плеер в стиле Apple Music: обложка с анимированным градиентом, пульсирующим в такт басам,
  таймлайн с текущим/общим временем, play/pause и перемотка ±15 с;
- **движок вибрации**: `AVAudioEngine` → tap → 2048-точечный real FFT на `vDSP` (`Accelerate`);
  суммируется энергия полосы 30–150 Гц, сравнивается с адаптивным уровнем низа трека;
  при ударе баса вызывается `CHHapticEngine` (`hapticTransient`), сила зависит от громкости удара
  и множителя из настроек; защита от захлёбывания мотора — cooldown 80 мс.

### 2. Лидар
- **задний LiDAR** (`ARWorldTrackingConfiguration` + `sceneReconstruction(.mesh)`) на iPhone 12 Pro и новее:
  расстояние до стены/предмета по перекрестию в центре экрана, проводная визуализация меша;
- **фронтальный TrueDepth** (`ARFaceTrackingConfiguration`) на XS Max, 11, 12, 13, 14, 15, 16 и др.:
  расстояние от экрана до лица в сантиметрах по `ARFaceAnchor`;
- если доступны оба датчика — переключатель «Задний LiDAR / Фронтальный»;
- **тактильный парктроник**: чем ближе объект, тем чаще лёгкие тики через Taptic Engine;
- сессия ARKit останавливается при уходе с вкладки, камера и CPU не греются.

### 3. Настройки
- «Сила вибрации» 10–100 %, «Резкость отклика» 0–1, «Чувствительность к басу» 0–1;
- кнопка «Протестировать Taptic Engine» с текущими параметрами;
- карточка «О приложении»: `vibration`, версия `1.0.0`, подпись **by homik**.

## Установка IPA

1. Скачайте `vibration.ipa` из [Releases](../../releases/latest).
2. Установите через **AltStore**, **SideStore** или **Sideloadly** (подпись вашим Apple ID).
3. На iPhone: `Настройки → Основные → VPN и управление устройством` → доверьтесь профилю разработчика.

Камера запрашивается при первом открытии вкладки «Лидар».
Музыку можно импортировать кнопкой «+» или через приложение «Файлы» → `На моём iPhone` → `vibration`.

## Сборка

Проект описан в `project.yml` (XcodeGen) — `.xcodeproj` не хранится в репозитории, он генерируется на CI.

```bash
brew install xcodegen
xcodegen generate
xcodebuild archive \
  -project vibration.xcodeproj -scheme vibration -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/vibration.xcarchive \
  CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

CI: `.github/workflows/build_ipa.yml` собирает на `macos-latest`, упаковывает `Payload/vibration.app`
в `vibration.ipa` и прикрепляет файл к GitHub Release.

## Структура

```
vibration/
├── project.yml                  # XcodeGen spec
├── Support/Info.plist           # NSCameraUsageDescription, LSSupportsOpeningDocumentsInPlace…
├── vibration/
│   ├── App/                     # точка входа, TabView, тема
│   ├── Audio/                   # AVAudioEngine, FFT-анализатор, Core Haptics, библиотека
│   ├── Scanner/                 # ARKit-контроллер и мост в SwiftUI
│   ├── Settings/                # UserDefaults-настройки
│   └── Views/                   # экраны трёх вкладок и компоненты
└── .github/workflows/build_ipa.yml
```
