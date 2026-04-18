# GEMINI.md - Project Context: AMV Hotel App

## Project Overview
AMV Hotel App is a Flutter-based mobile application designed for hotel management and guest services. It provides features such as room booking, event management, news updates, and user profile management. The app integrates with Firebase for authentication and syncs user data to a custom MySQL backend via a PHP API.

### Main Technologies
- **Frontend:** Flutter (Dart)
- **Authentication:** Firebase Auth (Google & Facebook Sign-in)
- **Local Storage:** `shared_preferences` for session management.
- **Backend Sync:** Custom PHP API (`AMV_Project_exp/API`) communicating with a MySQL database.
- **State Management:** `provider` and `theme_provider.dart`.
- **UI Components:** `google_fonts`, `font_awesome_flutter`, `flutter_spinkit`, `table_calendar`, `flutter_svg`.
- **Machine Learning:** `google_mlkit_text_recognition` (likely for ID or receipt scanning).

### Key Architecture & Files
- `lib/main.dart`: Entry point. Initializes Firebase and launches `PreloaderScreen`.
- `lib/preloader_screen.dart`: Handles the splash screen and routes users to either `HomeScreen` or `LoginScreen` based on their `isLoggedIn` status in `SharedPreferences`.
- `lib/auth_service.dart`: Manages Firebase authentication logic for Google and Facebook.
- `lib/user_sync_service.dart`: Handles HTTP POST requests to sync Firebase user data with the custom MySQL backend.
- `lib/api_config.dart`: Configuration file for the backend API IP address and base URL.
- `lib/home_screen.dart`: The main dashboard for authenticated users.

## Building and Running
To build and run the project, ensure you have the Flutter SDK installed and configured.

1.  **Install Dependencies:**
    ```bash
    flutter pub get
    ```

2.  **Configuration:**
    - Ensure `lib/api_config.dart` has the correct `serverIp` for your local environment.
    - Ensure `android/app/google-services.json` (and corresponding iOS files) are correctly configured for Firebase.

3.  **Run the App:**
    ```bash
    flutter run
    ```

4.  **Test the App:**
    ```bash
    flutter test
    ```

## Development Conventions
- **Naming Conventions:** Standard Dart/Flutter naming conventions (PascalCase for classes, camelCase for variables/functions, snake_case for file names).
- **API Communication:** Use `UserSyncService` for all MySQL synchronization tasks. Update `ApiConfig` when the server environment changes.
- **State Management:** Use `Provider` for cross-widget state (e.g., `ThemeProvider`).
- **UI/UX:** The app follows a custom design language with a primary color palette of "AMV Violet" (`0xFF2D0F35`) and "AMV Gold" (`0xFFD4AF37`).
- **Screens:** Most UI logic is contained within the `lib/` directory as individual screen files (e.g., `booking_summary_screen.dart`, `profile_screen.dart`).

## Project Structure (High-Level)
- `lib/`: Main source code.
- `assets/images/`: Images and SVGs used in the application.
- `android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/`: Platform-specific configurations and entry points.
- `test/`: Unit and widget tests.
