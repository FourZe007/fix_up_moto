import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/router/app_router.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/features/auth/domain/entities/google_account_identity.dart';
import 'package:fix_up_moto/features/auth/domain/entities/user_entity.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_state.dart';

void main() {
  const user = UserEntity(
    id: '1',
    name: 'Test User',
    status: 'Active',
    isActive: true,
  );
  const identity = GoogleAccountIdentity(email: 'a@b.c');

  String? guard(AuthState state, String location, {Object? extra}) =>
      AppRouter.guard(authState: state, location: location, extra: extra);

  /// Where a logged-in member can be: the tabs and the pages pushed from them.
  const appLocations = [
    RouteNames.home,
    RouteNames.bookings,
    RouteNames.membership,
    RouteNames.createBooking,
    RouteNames.profile,
    RouteNames.editProfile,
  ];

  /// Where a logged-out person can be.
  const authLocations = [
    RouteNames.welcome,
    RouteNames.login,
    RouteNames.register,
  ];

  group('while the session is still being checked (cold start)', () {
    test('stays on the splash', () {
      expect(guard(const AuthInitial(), RouteNames.splash), isNull);
    });

    for (final location in [...authLocations, ...appLocations]) {
      test('holds $location back on the splash', () {
        expect(guard(const AuthInitial(), location), RouteNames.splash);
      });
    }
  });

  group('with a live session', () {
    const state = AuthAuthenticated(user);

    for (final location in [
      RouteNames.splash,
      ...authLocations,
      RouteNames.completeGoogleProfile,
    ]) {
      test('bounces $location to Home', () {
        expect(guard(state, location, extra: identity), RouteNames.home);
      });
    }

    for (final location in appLocations) {
      test('lets $location through', () {
        expect(guard(state, location), isNull);
      });
    }
  });

  group('while an operation is in flight', () {
    for (final location in [
      ...authLocations,
      ...appLocations,
      RouteNames.splash,
    ]) {
      test('leaves the user on $location', () {
        expect(guard(const AuthLoading(), location), isNull);
      });
    }
  });

  group('logged out', () {
    // Every state that is not a session: no session, a failed attempt, and a
    // Google account picked but not yet turned into one.
    final states = <String, AuthState>{
      'unauthenticated': const AuthUnauthenticated(),
      'error': const AuthError('Wrong password'),
      'google identity obtained': const AuthGoogleIdentityObtained(
        email: 'a@b.c',
      ),
    };

    for (final MapEntry(key: name, value: state) in states.entries) {
      group(name, () {
        test('starts at the welcome screen, from the splash', () {
          expect(guard(state, RouteNames.splash), RouteNames.welcome);
        });

        for (final location in appLocations) {
          test('sends $location to the welcome screen', () {
            expect(guard(state, location), RouteNames.welcome);
          });
        }

        for (final location in authLocations) {
          test('lets $location through', () {
            expect(guard(state, location), isNull);
          });
        }

        test(
          'lets the Google profile page through when it has its identity',
          () {
            expect(
              guard(state, RouteNames.completeGoogleProfile, extra: identity),
              isNull,
            );
          },
        );
      });
    }

    test('sends the Google profile page back to login when it has lost its '
        'identity, instead of crashing on the missing extra', () {
      expect(
        guard(const AuthUnauthenticated(), RouteNames.completeGoogleProfile),
        RouteNames.login,
      );
    });
  });

  test('the welcome route is /welcome', () {
    expect(RouteNames.welcome, '/welcome');
  });
}
