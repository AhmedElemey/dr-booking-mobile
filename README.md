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

### Payment return link and the dev flavor

The checkout returns to `<androidApplicationId>://payment-return` (for example `com.moonlight.app://payment-return`), and the backend only accepts a return URL built from the clinic's configured `androidApplicationId`. The application id therefore may not contain `_` (not allowed in a URI scheme; the schema, `tool/apply_brand.dart` and the console all reject it).

The dev flavor installs as `com.moonlight.app.dev` but still registers the production scheme, because the backend allow-list is derived from the clinic config and would refuse `com.moonlight.app.dev://`. Consequences and how to deal with them:

- With dev and prod installed side by side, Android may show a chooser when the checkout returns. Pick the build you are testing, or uninstall the other one while testing online payments.
- To test payments end to end on the dev flavor alone, use a clinic config whose `androidApplicationId` is the dev id (`com.moonlight.app.dev`), run `dart run tool/apply_brand.dart`, and do not commit that config.
- The in-app demo mode (`main_mock.dart`) does not open a checkout and is not affected.

## Check

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

## Rebrand for a clinic

A clinic's identity lives in `clinic.config.json` (schema: `clinic.config.schema.json`, logo: `branding/logo.svg`): names (ar/en), tagline, colours, support phone, website domain, Android/iOS app ids and the default feature switches. To rebrand:

1. Edit `clinic.config.json`.
2. Run `dart run tool/apply_brand.dart` (add `--check` to only verify). It validates the file against the schema, regenerates `lib/core/config/brand.g.dart` (used by the theme, the visible app name and the feature defaults) and rewrites the Android `applicationId`/`namespace`/app label (moving `MainActivity.kt` into the new package), the iOS bundle identifier and display name, and the web manifest and page title. It is idempotent.
3. Commit the result. CI runs the tool and fails if it produces a diff.

Launcher icons and the Firebase files are per-clinic assets and are not generated.

## Feature switches

`GET /api/v1/features` is read at startup and whenever the app resumes. The last answer is cached locally and the defaults from `clinic.config.json` apply until then (and when the API is unreachable). `mobileApp` off shows a full-screen "not available" page; `guestBrowsing` off sends guests to sign in before anything else; `patientSelfService` off swaps cancel/reschedule for a "call the clinic" prompt; `englishLanguage` off hides the language option and forces Arabic; `multiBranch` off hides the city filter. A `403 FEATURE_DISABLED` problem shows a localized message. Demo mode serves `/features` and `/branding` (see `MockApiAdapter.features`).

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

Push is still a stub (no FCM), so the payloads of the newer message kinds are not handled yet and nothing needs to change until FCM is wired. When it is, the backend sends, besides `{type, appointmentId}`: `waitlist.slot-opened` with `{waitingListEntryId, doctorId, date}` (open `/doctors/{doctorId}/slots`; the backend accepts the id as well as the slug), `review.prompt` with `{appointmentId}` (open `/appointments/{appointmentId}` and show the rate sheet) and `recall` with `{campaignId}` (open home).

`PushRegistrar` already registers the token with `PUT /me/device-tokens` after login and on rotation, and unregisters before logout. The router already opens `/appointments/{id}` when `openedAppointmentIds` emits (guests are sent to login first), which is how a tapped notification lands on the appointment.
