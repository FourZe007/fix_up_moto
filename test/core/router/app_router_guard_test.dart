import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/router/app_router.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/features/auth/domain/entities/google_account_identity.dart';
import 'package:fix_up_moto/features/auth/domain/entities/user_entity.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_state.dart';
import 'package:fix_up_moto/features/otp/domain/entities/otp_channel.dart';
import 'package:fix_up_moto/features/otp/domain/entities/otp_purpose.dart';
import 'package:fix_up_moto/features/otp/domain/entities/otp_request.dart';
import 'package:fix_up_moto/features/password_reset/domain/entities/password_reset_member.dart';

void main() {
  const user = UserEntity(
    id: '1',
    name: 'Test User',
    status: 'Active',
    isActive: true,
  );
  const identity = GoogleAccountIdentity(email: 'a@b.c');

  String? guard(
    AuthState state,
    String location, {
    Object? extra,
    bool welcomeSeen = false,
  }) => AppRouter.guard(
    authState: state,
    location: location,
    extra: extra,
    welcomeSeen: welcomeSeen,
  );

  /// Where a logged-in member can be: the tabs and the pages pushed from them.
  const appLocations = [
    RouteNames.home,
    RouteNames.bookings,
    RouteNames.membership,
    RouteNames.createBooking,
    RouteNames.profile,
    RouteNames.editProfile,
    RouteNames.changePassword,
  ];

  /// Where a logged-out person can be.
  const authLocations = [
    RouteNames.welcome,
    RouteNames.login,
    RouteNames.register,
  ];

  // Every state that is not a session: no session, a failed attempt, and a
  // Google account picked but not yet turned into one.
  final loggedOutStates = <String, AuthState>{
    'unauthenticated': const AuthUnauthenticated(),
    'error': const AuthError('Wrong password'),
    'google identity obtained': const AuthGoogleIdentityObtained(
      email: 'a@b.c',
    ),
  };

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
    for (final MapEntry(key: name, value: state) in loggedOutStates.entries) {
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

  group('logged out, after the welcome screen has been seen', () {
    for (final MapEntry(key: name, value: state) in loggedOutStates.entries) {
      group(name, () {
        test('starts at login, from the splash', () {
          expect(
            guard(state, RouteNames.splash, welcomeSeen: true),
            RouteNames.login,
          );
        });

        for (final location in appLocations) {
          test('sends $location to login, not the welcome screen', () {
            expect(guard(state, location, welcomeSeen: true), RouteNames.login);
          });
        }

        // Seen once does not wall Welcome off: it is still a place to be.
        for (final location in authLocations) {
          test('still lets $location through', () {
            expect(guard(state, location, welcomeSeen: true), isNull);
          });
        }
      });
    }

    test('changes nothing for a cold start, a live session or a request in '
        'flight', () {
      expect(
        guard(const AuthInitial(), RouteNames.login, welcomeSeen: true),
        RouteNames.splash,
      );
      expect(
        guard(
          const AuthAuthenticated(user),
          RouteNames.welcome,
          welcomeSeen: true,
        ),
        RouteNames.home,
      );
      expect(
        guard(const AuthLoading(), RouteNames.login, welcomeSeen: true),
        isNull,
      );
    });
  });

  group('the code page (/otp)', () {
    const request = OtpRequest(
      purpose: OtpPurpose.register,
      channel: OtpChannel.whatsapp,
      destination: '81234567890',
    );

    test('is open to a logged-out member, who registers through it', () {
      for (final state in loggedOutStates.values) {
        expect(guard(state, RouteNames.otp, extra: request), isNull);
      }
    });

    test('is open to a logged-in member, who changes a password or edits '
        'a contact through it: not bounced home like an auth route', () {
      expect(
        guard(const AuthAuthenticated(user), RouteNames.otp, extra: request),
        isNull,
      );
    });

    test('is left alone while an operation is in flight', () {
      expect(
        guard(const AuthLoading(), RouteNames.otp, extra: request),
        isNull,
      );
    });

    test('is held back on the splash during a cold start', () {
      expect(
        guard(const AuthInitial(), RouteNames.otp, extra: request),
        RouteNames.splash,
      );
    });

    test('still opens for a logged-out member who has seen Welcome', () {
      expect(
        guard(
          const AuthUnauthenticated(),
          RouteNames.otp,
          extra: request,
          welcomeSeen: true,
        ),
        isNull,
      );
    });

    test('sends a logged-out member to login when it has lost its request, '
        'instead of crashing on the missing extra', () {
      for (final state in loggedOutStates.values) {
        expect(guard(state, RouteNames.otp), RouteNames.login);
      }
      // A request of some other type is as good as none.
      expect(
        guard(const AuthUnauthenticated(), RouteNames.otp, extra: 'nope'),
        RouteNames.login,
      );
    });

    test('sends a logged-in member home when it has lost its request', () {
      expect(
        guard(const AuthAuthenticated(user), RouteNames.otp),
        RouteNames.home,
      );
    });
  });

  group('the forgotten-password pages', () {
    const member = PasswordResetMember(
      memberId: '0101202400000014',
      phone: '81234567890',
    );

    group('the phone page (/forgot-password)', () {
      test('is open to a logged-out member, whether or not they have seen '
          'Welcome', () {
        for (final state in loggedOutStates.values) {
          expect(guard(state, RouteNames.forgotPassword), isNull);
          expect(
            guard(state, RouteNames.forgotPassword, welcomeSeen: true),
            isNull,
          );
        }
      });

      test('bounces a logged-in member home, like any auth route', () {
        expect(
          guard(const AuthAuthenticated(user), RouteNames.forgotPassword),
          RouteNames.home,
        );
      });

      test('is held back on the splash during a cold start, and left alone '
          'while an operation is in flight', () {
        expect(
          guard(const AuthInitial(), RouteNames.forgotPassword),
          RouteNames.splash,
        );
        expect(guard(const AuthLoading(), RouteNames.forgotPassword), isNull);
      });
    });

    group('the new-password page (/reset-password)', () {
      test('is open to a logged-out member who has the member to reset', () {
        for (final state in loggedOutStates.values) {
          expect(guard(state, RouteNames.resetPassword, extra: member), isNull);
          expect(
            guard(
              state,
              RouteNames.resetPassword,
              extra: member,
              welcomeSeen: true,
            ),
            isNull,
          );
        }
      });

      test('sends a logged-out member to login when it has lost its member, '
          'instead of crashing on the missing extra', () {
        for (final state in loggedOutStates.values) {
          expect(guard(state, RouteNames.resetPassword), RouteNames.login);
        }
        // A member of some other type is as good as none.
        expect(
          guard(
            const AuthUnauthenticated(),
            RouteNames.resetPassword,
            extra: 'nope',
          ),
          RouteNames.login,
        );
      });

      test('bounces a logged-in member home, like any auth route', () {
        expect(
          guard(
            const AuthAuthenticated(user),
            RouteNames.resetPassword,
            extra: member,
          ),
          RouteNames.home,
        );
      });

      test('is left alone while an operation is in flight', () {
        expect(
          guard(const AuthLoading(), RouteNames.resetPassword, extra: member),
          isNull,
        );
      });
    });

    test('the routes are /forgot-password and /reset-password', () {
      expect(RouteNames.forgotPassword, '/forgot-password');
      expect(RouteNames.resetPassword, '/reset-password');
    });
  });

  test('the OTP route is /otp', () {
    expect(RouteNames.otp, '/otp');
  });

  test('the welcome route is /welcome', () {
    expect(RouteNames.welcome, '/welcome');
  });
}
