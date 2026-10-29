# moonlight-mobile

Patient app for Moonlight, a dentist reservation platform. Flutter with Riverpod, go_router, Dio and fpdart, organised as `lib/features/<feature>/{data,domain,presentation}`. The product spec lives in [moonlight-backend/docs/SPEC.md](https://github.com/AhmedElemey/moonlight-backend/blob/main/docs/SPEC.md).

## Run

```bash
flutter pub get
flutter run --flavor dev -t lib/main_dev.dart     # com.moonlight.app.dev
flutter run -d chrome -t lib/main_dev.dart --dart-define=API_BASE_URL=http://localhost:5267   # web against a local API
flutter run --flavor prod -t lib/main_prod.dart   # com.moonlight.app
```

Demo mode needs no backend: every API call is answered by fixtures (a Cairo clinic, three doctors, a week of open slots, a patient with appointments). Log in with any phone number and code `123456` (`01000000000` signs up a new patient).

```bash
flutter run -d chrome -t lib/main_mock.dart
flutter build web -t lib/main_mock.dart     # then serve build/web
```

Dev and prod are separate Android flavors, so both installs can coexist. iOS schemes for the two flavors are added with Firebase in M4.

## Check

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

## Layout

- `lib/main.dart`: `bootstrap(Env)`, shared by `main_dev.dart` and `main_prod.dart`
- `lib/core/`: env config, router, localization (`l10n/` ARB files generate `lib/core/l10n/generated/` on `pub get`)
- `lib/features/`: one folder per feature

The app starts in Arabic (RTL). Use `EdgeInsetsDirectional` and `AlignmentDirectional` so layouts flip correctly.

## Auth and networking

`core/network` holds the Dio client: the auth interceptor adds the bearer token and `Accept-Language`, and on a `401` refreshes the token pair once (single-flight, however many requests failed together) and replays the request. Tokens live in `flutter_secure_storage`. API errors become a `Failure` keyed by the spec's `code` and are shown through localized messages (`core/l10n/failure_messages.dart`). Guests can browse up to the confirm step; the router redirects other protected routes to login and back.

## Push notifications and deep links

Firebase projects do not exist yet, so push sits behind `PushService` (`core/push/push_service.dart`) with a no-op default and no Firebase config files in the repo. To wire FCM once the projects exist:

1. Add `firebase_core` and `firebase_messaging`, the per-flavor `google-services.json` / `GoogleService-Info.plist`, and call `Firebase.initializeApp` in `bootstrap` (use the dev and prod projects per flavor).
2. Implement `PushService` on `FirebaseMessaging`: `currentToken` is `getToken()`, `tokenRefreshes` is `onTokenRefresh`, `openedAppointmentIds` merges `onMessageOpenedApp` and `getInitialMessage()` and emits `message.data['appointmentId']`.
3. Override `pushServiceProvider` with it in `main_dev.dart` / `main_prod.dart`.

`PushRegistrar` already registers the token with `PUT /me/device-tokens` after login and on rotation, and unregisters before logout. The router already opens `/appointments/{id}` when `openedAppointmentIds` emits (guests are sent to login first), which is how a tapped notification lands on the appointment.
