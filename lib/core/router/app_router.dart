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
import '../../features/doctor/presentation/doctor_profile_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/profile/presentation/language_select_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';
import '../../features/search/domain/doctor_query.dart';
import '../../features/search/presentation/doctor_list_screen.dart';
import '../push/push_service.dart';
import '../storage/local_settings.dart';
import 'app_shell.dart';

/// Whether a location is only for signed-in patients. Everything up to the
/// confirm step is open to guests; the confirm screen asks for login itself.
bool requiresAuth(String location) => location.startsWith('/appointments');

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

  String? redirect(BuildContext context, GoRouterState state) {
    final location = state.matchedLocation;
    if (ref.read(localSettingsProvider).languageCode == null) {
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
      if (requiresAuth(location)) {
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
            ],
          ),
        ],
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
