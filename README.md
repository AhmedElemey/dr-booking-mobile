# moonlight-mobile

Patient app for Moonlight, a dentist reservation platform. Flutter with Riverpod, go_router, Dio and fpdart, organised as `lib/features/<feature>/{data,domain,presentation}`. The product spec lives in [moonlight-backend/docs/SPEC.md](https://github.com/AhmedElemey/moonlight-backend/blob/main/docs/SPEC.md).

## Run

```bash
flutter pub get
flutter run --flavor dev -t lib/main_dev.dart     # com.moonlight.app.dev
flutter run --flavor prod -t lib/main_prod.dart   # com.moonlight.app
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
