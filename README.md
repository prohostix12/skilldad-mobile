# SkillDad Mobile

SkillDad mobile application built with Flutter, providing seamless access to courses, video lectures, exams, live sessions, career journeys, and student dashboard.

---

## 🚀 Features

- **Authentication & User Management**: Secure register/login with session persistence (`AuthService`).
- **Course Catalog & Details**: Browse courses, explore curriculum, instructor details, and enrollment.
- **In-App Video & Session Player**: Video playback for course modules and live session streams.
- **Student Dashboard & Analytics**: Track progress, performance donuts, sparklines, and recent activity.
- **Examinations**: Interactive exam taking, real-time submission, and result scorecards.
- **Study Abroad Portal**: Explore international universities and degree programs.
- **Discussion Hub**: Course discussions and community Q&A.

---

## 🛠 Tech Stack & Dependencies

- **Framework**: [Flutter](https://flutter.dev) (SDK `^3.13.4`, Dart 3+)
- **State & Networking**: `http`, `shared_preferences`
- **UI & Media**: `google_fonts`, `youtube_player_flutter`, `webview_flutter`, `image_picker`, `share_plus`
- **Target Platforms**: Android (minSdk 21+, targetSdk 34+), Web

---

## 💻 Getting Started

### 1. Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed and added to PATH.
- Android Studio / Android SDK with command-line tools.
- JDK 17 (recommended for Gradle builds).

Run `flutter doctor` to ensure your local environment is configured:
```bash
flutter doctor
```

### 2. Clone & Install Dependencies
```bash
git clone https://github.com/prohostix12/skilldad-mobile.git
cd skilldad-mobile
flutter pub get
```

### 3. Run the App in Debug Mode
Connect an Android device or start an Android emulator, then run:
```bash
flutter run
```

---

## 📦 Building for Production

### Android Release Signing Setup
Production release signing requires `android/key.properties` and the release keystore.
1. Refer to `android/key.properties.example` for the required configuration template.
2. Obtain the production keystore and credentials from the secure team handover vault.
3. Place the keystore in `android/app/` and configure `android/key.properties`.

> **Note:** Keystores and `key.properties` are strictly gitignored and must never be committed to version control.

#### Build Release APK:
```bash
flutter build apk --release
```

#### Build Release App Bundle (Google Play):
```bash
flutter build appbundle --release
```

---

## 📂 Project Structure

```text
skilldad_mobile/
├── android/            # Native Android project, Gradle build scripts, manifest
├── assets/             # Brand icons, director photos, illustrations
├── lib/
│   ├── data/           # Content models & static data (country codes, home content)
│   ├── screens/        # UI screens (Home, Dashboard, CourseDetail, Exam, etc.)
│   ├── services/       # API clients (Auth, Dashboard, CoursePlayer, Exam, etc.)
│   ├── theme/          # App design tokens, colors, typography, themes
│   ├── widgets/        # Reusable UI components & custom widgets
│   └── main.dart       # App entry point & routing configuration
├── test/               # Unit and widget tests
└── pubspec.yaml        # Flutter dependencies & asset declarations
```
