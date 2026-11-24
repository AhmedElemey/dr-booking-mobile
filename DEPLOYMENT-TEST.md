# Connected Flutter web test

This repo can produce a hosted browser build, not an App Store/Play Store release. Do not replace the connected test with main_mock.dart.

Use the CI-pinned Flutter3.47.8 / Dart3.13.7 toolchain:

```
flutter pub get
flutter analyze
flutter test
flutter build web --no-wasm-dry-run --optimization-level=1 -t lib/main_prod.dart --dart-define=API_BASE_URL=THE_ACTUAL_HTTPS_BACKEND_ORIGIN
```

Publish only build/web on a free static host with HTTPS and an SPA fallback to index.html. Add the exact mobile-web origin to Backend CORS. API_BASE_URL is public, never a credential. Do not ship a localhost or example URL.

The lower optimization level was used for a bounded local compile check. Default optimization was interrupted by execution time limits, not established as a product failure. Local analyze is clean and147 tests pass. Production now reads API_BASE_URL and refuses missing or non-HTTPS origins at startup. Run the production-config test both without a define and with the real intended HTTPS origin before building. A compile alone does not establish connection to the backend. Browser runtime behavior for file opening, secure storage, mobile deep links and video still needs testing; native-app success cannot be inferred from a web compile.

Payments, real messaging, patient records and uploads remain disabled. This file alone does not create a deployment.

## Demo-environment banner (hosted test only)

The hosted test build shows a "Demo environment" banner on the login screen, gated on Env.hostedTest. The prod build reads it from --dart-define=HOSTED_TEST=1. The moonlight-mobile-test Render service sets HOSTED_TEST=1, and its build command passes the define only when that variable is set:

```
if [ "${HOSTED_TEST:-}" = "1" ]; then EXTRA="--dart-define=HOSTED_TEST=1"; else EXTRA=""; fi
flutter build web --release --no-wasm-dry-run --dart2js-optimization O1 -t lib/main_prod.dart --dart-define=API_BASE_URL=<test backend origin> $EXTRA
```

HOSTED_TEST is forbidden in clinic builds: apps generated for a clinic from this template must never define it. It exists only for the Moonlight hosted test deployment, which serves synthetic data.
