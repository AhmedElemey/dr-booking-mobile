import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/appointments/presentation/appointment_details_screen.dart';
import '../../features/appointments/presentation/appointments_screen.dart';
import '../../features/appointments/presentation/reschedule_screen.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/complete_profile_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/phone_screen.dart';
import '../../features/booking/presentation/booking_providers.dart';
import '../../features/booking/presentation/booking_success_screen.dart';
import '../../features/booking/presentation/confirm_booking_screen.dart';
import '../../features/booking/presentation/pick_slot_screen.dart';
import '../../features/clinic_config/presentation/feature_unavailable_screen.dart';
import '../../features/clinic_config/presentation/features_controller.dart';
import '../../features/doctor/presentation/doctor_profile_screen.dart';
import '../../features/family/presentation/family_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/payments/presentation/payment_flow.dart';
import '../../features/payments/presentation/payment_return_screen.dart';
import '../../features/records/presentation/records_screen.dart';
import '../../features/reviews/presentation/doctor_reviews_screen.dart';
import '../../features/waiting_list/presentation/waiting_list_screen.dart';
import '../../features/profile/presentation/language_select_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';
import '../../features/search/domain/doctor_query.dart';
import '../../features/search/presentation/doctor_list_screen.dart';
import '../config/clinic_features.dart';
import '../push/push_service.dart';
import '../storage/local_settings.dart';
import 'app_shell.dart';

/// Whether a location is only for signed-in patients. Everything up to the
/// confirm step is open to guests; the confirm screen asks for login itself.
/// When the clinic turns guest browsing off, only the login pages are open.
bool requiresAuth(String location, {bool guestBrowsing = true}) =>
    location.startsWith('/appointments') ||
    _patientOnly.any(location.startsWith) ||
    (!guestBrowsing && !_isLogin(location));

/// Pages of the signed-in patient's own data.
const _patientOnly = [
  '/family',
  '/waiting-list',
  '/records',
  '/payment-return',
];

/// The feature switch each phase 2 page depends on; a page whose feature is off
/// is not reachable (not even through a deep link).
bool _routeEnabled(String location, ClinicFeatures features) {
  if (location.startsWith('/family')) return features.familyAccounts;
  if (location.startsWith('/waiting-list')) return features.waitingList;
  if (location.startsWith('/records')) return features.patientRecords;
  if (location.startsWith('/payment-return')) return features.onlinePayments;
  if (RegExp(r'^/doctors/[^/]+/reviews$').hasMatch(location)) {
    return features.reviews;
  }
  return true;
}

bool _isLogin(String location) =>
    location == '/login' || location == '/login/otp';

/// Accepts only in-app paths as a post-login destination.
String? _safeFrom(String? from) =>
    from != null && from.startsWith('/') && !from.startsWith('//')
    ? from
    : null;

String _withFrom(String path, String from) =>
    Uri(path: path, queryParameters: {'from': from}).toString();

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run the redirect whenever the session changes (login, logout, expiry).
  final authChanged = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => authChanged.value++);
  // ...and whenever the clinic's feature switches change.
  ref.listen(featuresProvider, (_, _) => authChanged.value++);

  String? redirect(BuildContext context, GoRouterState state) {
    final location = state.matchedLocation;
    final features = ref.read(featuresProvider);
    if (!features.mobileApp) {
      return location == '/unavailable' ? null : '/unavailable';
    }
    if (location == '/unavailable') return '/';
    // `<applicationId>://payment-return?paymentId=..&status=..` from the checkout.
    if (state.uri.hasScheme || state.uri.host.isNotEmpty) {
      final target = paymentReturnLocation(state.uri);
      if (target != null) return target;
    }
    if (!_routeEnabled(location, features)) return '/';
    if (!features.englishLanguage && location == '/language') return '/';
    // Without English there is nothing to choose: the app is Arabic.
    if (features.englishLanguage &&
        ref.read(localSettingsProvider).languageCode == null) {
      return location == '/language' ? null : '/language';
    }

    final auth = ref.read(authControllerProvider);
    if (auth.isLoading) {
      return location == '/splash'
          ? null
          : _withFrom('/splash', state.uri.toString());
    }
    if (location == '/splash') {
      return _safeFrom(state.uri.queryParameters['from']) ?? '/';
    }

    final user = auth.value;
    if (user == null) {
      if (requiresAuth(location, guestBrowsing: features.guestBrowsing)) {
        return _withFrom('/login', state.uri.toString());
      }
    } else {
      final from = _isLogin(location)
          ? _safeFrom(state.uri.queryParameters['from'])
          : null;
      if (!user.hasName) {
        if (location == '/profile/complete') return null;
        return _withFrom('/profile/complete', from ?? state.uri.toString());
      }
      if (location == '/profile/complete') {
        return _safeFrom(state.uri.queryParameters['from']) ?? '/';
      }
      if (_isLogin(location)) return from ?? '/';
    }

    if (location == '/booking/confirm' &&
        ref.read(bookingDraftProvider) == null) {
      return '/';
    }
    if (location == '/booking/success' &&
        ref.read(lastBookingProvider) == null) {
      return '/';
    }
    return null;
  }

  final router = GoRouter(
    refreshListenable: authChanged,
    redirect: redirect,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(
        path: '/unavailable',
        builder: (context, state) => const AppUnavailableScreen(),
      ),
      GoRoute(
        path: '/language',
        builder: (context, state) => const LanguageSelectScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            PhoneScreen(from: state.uri.queryParameters['from']),
        routes: [
          GoRoute(
            path: 'otp',
            builder: (context, state) => OtpScreen(
              phone: state.uri.queryParameters['phone'] ?? '',
              from: state.uri.queryParameters['from'],
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/profile/complete',
        builder: (context, state) =>
            CompleteProfileScreen(from: state.uri.queryParameters['from']),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/appointments',
                builder: (context, state) => const AppointmentsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => AppointmentDetailsScreen(
                      id: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'reschedule',
                        builder: (context, state) =>
                            RescheduleScreen(id: state.pathParameters['id']!),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/doctors',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          return DoctorListScreen(
            initialQuery: DoctorQuery(
              specialtyId: q['specialtyId'],
              city: q['city'],
              text: q['q'],
            ),
          );
        },
        routes: [
          GoRoute(
            path: ':slug',
            builder: (context, state) =>
                DoctorProfileScreen(slug: state.pathParameters['slug']!),
            routes: [
              GoRoute(
                path: 'slots',
                builder: (context, state) =>
                    PickSlotScreen(slug: state.pathParameters['slug']!),
              ),
              GoRoute(
                path: 'reviews',
                builder: (context, state) =>
                    DoctorReviewsScreen(slug: state.pathParameters['slug']!),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/family',
        builder: (context, state) => const FamilyScreen(),
      ),
      GoRoute(
        path: '/waiting-list',
        builder: (context, state) => const WaitingListScreen(),
      ),
      GoRoute(
        path: '/records',
        builder: (context, state) => const RecordsScreen(),
      ),
      GoRoute(
        path: '/payment-return',
        builder: (context, state) => PaymentReturnScreen(
          paymentId: state.uri.queryParameters['paymentId'],
        ),
      ),
      GoRoute(
        path: '/booking/confirm',
        builder: (context, state) => const ConfirmBookingScreen(),
      ),
      GoRoute(
        path: '/booking/success',
        builder: (context, state) => const BookingSuccessScreen(),
      ),
    ],
  );

  // A tapped notification opens its appointment (guests are sent to login first
  // by the redirect above).
  final taps = ref
      .read(pushServiceProvider)
      .openedAppointmentIds
      .listen((id) => router.go('/appointments/$id'));

  ref.onDispose(() {
    taps.cancel();
    authChanged.dispose();
    router.dispose();
  });
  return router;
});
