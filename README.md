# Aas Paas app (Flutter, Android first)

Native Android app for the Aas Paas directory. It talks to your WordPress site through the plugin's REST API (plugin 0.9.0 or newer).

Screens in this first version: area picker, directory list (news and alerts, search, Open now, Deals today, Nearest, category and options), business details (call, WhatsApp, directions, deals, more numbers, jobs, reviews), jobs list and details, favorites, sign up and login, account (area, location, logout, delete account).
Offline: every screen shows its last saved copy when there is no internet, with a yellow "showing saved results" note.

## Option 1: get an installable APK (no software to install on your computer)

1. Make a free account at github.com and create a new repository called `aaspaas-app` (private is fine).
2. Unzip this package and upload everything to the repository (Add file, then Upload files, drag all files and folders in, including the `.github` folder). If the `.github` folder does not upload, use Add file, Create new file, type `.github/workflows/build-apk.yml` as the name and paste the contents of that file.
3. Open the **Actions** tab, choose **Build Android APK**, press **Run workflow**. It takes about 10 to 15 minutes the first time.
4. When it turns green, open the run and download **aaspaas-apk** from the Artifacts section at the bottom. Unzip it, send `app-release.apk` to your phone and open it (Android will ask to allow installing from this source).

### Point it at your site
By default the app uses `https://zomo.pk/wp-json/aaspaas/v1`. To change it (for example when you move to aaspaas.app): repository **Settings, Secrets and variables, Actions, Variables tab, New repository variable**, name `API_BASE`, value `https://aaspaas.app/wp-json/aaspaas/v1`, then run the workflow again.

### If the build fails
Open the failed run, click the red step, copy the last 30 or so lines and send them to me. First builds of a new app often need one or two small fixes.

## Work on it in VS Code

### One-time installs (Windows)
1. **VS Code** (code.visualstudio.com) and **Git** (git-scm.com).
2. **Android Studio** (developer.android.com/studio). Open it once and let it install the Android SDK. It also gives you the phone emulator. Then in a terminal run `flutter doctor --android-licenses` and accept everything.
3. **Flutter 3.47.8** (the exact version this code was checked against). In a terminal:
   ```
   git clone https://github.com/flutter/flutter.git -b 3.47.8 C:\src\flutter
   ```
   Add `C:\src\flutter\bin` to your PATH (Windows search, "Edit environment variables", Path, New). Close and reopen the terminal, then run `flutter doctor`. Fix anything with a red cross (the Android toolchain line matters, Chrome and Visual Studio lines do not).
4. In VS Code open Extensions and install **Flutter** (it also installs Dart).

### Open the project
1. Unzip `aaspaas-app.zip`, then VS Code, File, **Open Folder**, choose the `aaspaas-app` folder. Accept "Install recommended extensions" if it asks.
2. Open a terminal inside VS Code (Terminal, New Terminal) and run the one-time setup:
   - Windows: `powershell -ExecutionPolicy Bypass -File tool\setup_dev.ps1`
   - Mac or Linux: `bash tool/setup_dev.sh`

   It creates the `android` folder, adds the permissions and downloads the packages. It is safe to run again.

### Run it
1. Choose a device in the **bottom-right corner** of VS Code: an emulator (create one in Android Studio, Device Manager) or your real phone (Settings, About phone, tap Build number 7 times, then Developer options, turn on **USB debugging**, plug in the cable and allow the prompt).
2. Press **F5** (Run and Debug, "Aas Paas (debug, zomo.pk)"). The first run takes a few minutes. Later runs are fast.
3. Edit a file and **save**: the app updates in about a second (hot reload). If something looks stuck, press **Shift+F5**, then F5 again, or in the debug toolbar press the green restart button.
4. Click in the margin next to a line to set a **breakpoint**, and read errors and `print` output in the **Debug Console**.

The run options in the dropdown use zomo.pk. Use the aaspaas.app option once that site is live, or edit `.vscode/launch.json`.

### Before you commit or send me a change
- Terminal, Run Task, **Aas Paas: analyze** (or `flutter analyze`). It should print no errors.
- Task **Aas Paas: text helper tests** (19 quick checks).
- Push to GitHub and the **Build Android APK** workflow makes a fresh APK for your phone.
- Do not commit the `android` folder or `build`: they are created again by the setup script and the workflow (the `.gitignore` already skips them).

### Where to change things
| I want to change... | File |
|---|---|
| How a business card looks | `lib/app/widgets/listing_card.dart` |
| The deal banner | `lib/app/widgets/deal_banner.dart` |
| Call, WhatsApp and other round icon buttons, badges, empty and error screens | `lib/app/widgets/common.dart` |
| Colours and overall theme | `lib/app/theme.dart` (`brand` is the main green) |
| Home list, search, filters | `lib/app/screens/home_tab.dart` and `filters_sheet.dart` |
| Business details page | `lib/app/screens/listing_detail.dart` |
| Reviews form | `lib/app/screens/review_sheet.dart` |
| Jobs list and details | `lib/app/screens/jobs_tab.dart`, `job_detail.dart` |
| Login, sign up | `lib/app/screens/auth_screen.dart` |
| Account tab | `lib/app/screens/account_tab.dart` |
| Bottom tabs | `lib/app/screens/home_shell.dart` |
| Server address, app name, version | `lib/config.dart` |
| What the server sends (new fields) | `lib/core/models.dart`, then use it in a screen |
| New server call | `lib/core/repository.dart` (reads and caches) or `lib/core/session.dart` (accounts) |
| App name under the icon, permissions | `tool/prepare_android.dart` |

### Typical problems
- **"flutter is not recognized"**: PATH was not saved. Reopen VS Code after adding it.
- **Gradle or SDK errors on the first run**: run `flutter doctor -v` and fix the Android lines. Licences: `flutter doctor --android-licenses`.
- **The emulator is slow**: use your real phone with USB debugging instead.
- **Red errors after changing `pubspec.yaml`**: run the task "Aas Paas: get packages".
- **The app opens but the list is empty**: check the area you chose has listings, and open `https://zomo.pk/wp-json/aaspaas/v1/config` in the phone browser.

## Before you try it
Open `https://YOUR-SITE/wp-json/aaspaas/v1/config` in your phone browser. You should see your areas and categories as text. If you see an error or a blank page, a security plugin is probably blocking the REST API, and the app cannot work until it is allowed.

## What has been checked, and what has not
Checked here:
- The networking, offline cache, sign-in and account logic ran against a real WordPress with the 0.9.0 plugin: 63 live checks (browsing, filters, paging, offline fallback, register, verify, login, favorites, reviews, deal taps, logout, account deletion, bad server answers).
- The text helpers: 19 checks.
- All screens were analysed against the real Flutter 3.47.8 source with no errors or warnings. This found and fixed one real bug (a widget named `Thumb` clashed with a Flutter class).
- The Android permission script was run on Flutter's own Android templates.

Not checked yet (I cannot run Flutter or a phone here):
- The APK build itself, and how the screens look and feel on a real phone.
- The four add-on packages (shared_preferences, flutter_secure_storage, url_launcher, geolocator) were checked against their documented signatures, not their real code.

## Coming next
Push notifications for alerts by area (Firebase, free), business tools inside the app (post deals and jobs, edit listing), WhatsApp brand icon, app icon and splash, Play Store release (signing key, privacy policy page, screenshots).

## Layout
- `lib/core/` plain Dart: models, HTTP client, offline cache, repository, session. No Flutter inside, so it is testable.
- `lib/app/` Flutter screens and widgets.
- `tool/live_test.dart` the live test against a running server: `dart tool/live_test.dart http://127.0.0.1:8099/wp-json/aaspaas/v1 seed.json`.
- `tool/prepare_android.dart` adds internet, location and link permissions to the generated Android project.
- `tool/setup_dev.ps1` (Windows) and `tool/setup_dev.sh` (Mac/Linux) one-time setup for working on your own computer.
- `.vscode/` run buttons (F5), recommended extensions, formatting and tasks for VS Code.
