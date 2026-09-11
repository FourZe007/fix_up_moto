import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/helpers/google_password.dart';
import 'package:fix_up_moto/core/helpers/phone_number.dart';
import 'package:fix_up_moto/core/network/samp_envelope.dart';
import 'package:fix_up_moto/features/auth/data/models/user_model.dart';
import 'package:fix_up_moto/features/auth/domain/entities/google_account_identity.dart';

/// Contract for all authentication HTTP calls.
/// Having an abstract interface makes it trivially mockable in unit tests.
abstract class AuthRemoteDataSource {
  /// Sends login credentials to the API.
  ///
  /// [phone] is accepted as the member typed it and normalised here.
  /// Returns a [UserModel] parsed from the response on success.
  /// Throws [UnauthorizedException] on 401, [AccountInactiveException] when the
  /// membership is barred, [ServerException] on other errors.
  Future<UserModel> login(String phone, String password);

  /// Registers a new account and returns the created [UserModel].
  ///
  /// [name], [phone], and [password] are mandatory; [email] is optional.
  /// Uses the same real contract as [submitGoogleAccount]'s registration
  /// phase — [ApiConstants.modify] with [ModifyMode.create] — since this is
  /// the identical action (create a new member), just reached from the
  /// manual form instead of the Google flow. Unlike a Google account, the
  /// password here is exactly what the user typed, never a derived one.
  ///
  /// Throws [ServerException] on failure.
  Future<UserModel> register({
    required String name,
    required String phone,
    String? email,
    required String password,
  });

  /// Opens the Google account sheet and returns the chosen account's identity.
  ///
  /// Makes no backend call — the phone/password endpoints below are still what
  /// establish a session. This only exists to prefill the complete-profile
  /// form with a name and a verified email.
  ///
  /// Throws [GoogleSignInCancelledException] when the user dismisses the sheet,
  /// [ServerException] for any other Google-side failure (including a missing
  /// OAuth client configuration).
  Future<GoogleAccountIdentity> getGoogleIdentity();

  /// Turns a Google identity plus a phone number into a real SAMP session.
  ///
  /// The backend has no Google-specific endpoint and no way to ask "does this
  /// phone already have an account" directly, so this does it the only way
  /// available: try logging in with a password deterministically derived from
  /// [name] (see [GooglePassword]), and only register a new member
  /// ([ApiConstants.modify], [ModifyMode.create]) if that fails.
  ///
  /// Throws [AccountInactiveException] when a matching membership exists but
  /// is barred, [ServerException] on other failures.
  Future<UserModel> submitGoogleAccount({
    required String name,
    required String phone,
    required String email,
  });

  // No logout() here — there is no logout endpoint on this backend. See
  // AuthRepositoryImpl.logout(), which ends the session by clearing the
  // local cache alone; the cached member record IS the session.
}

/// Concrete implementation that communicates with the REST API via [Dio].
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio _dio;

  /// [Dio] is injected (not created here) so the DI container controls the
  /// instance, including its auth interceptor and base URL.
  AuthRemoteDataSourceImpl(this._dio);

  @override
  Future<UserModel> login(String phone, String password) async {
    try {
      log('dio post');
      log('Phone number: ${PhoneNumber.toSubscriberNumber(phone)}');
      log('Descrypted password: $password');
      final response = await _dio.post(
        ApiConstants.login,
        data: {
          // The backend wants the bare subscriber number — '081234567890' as
          // typed becomes '81234567890'. Normalising at this boundary keeps the
          // form forgiving without the rest of the app knowing the rule.
          'PhoneNo': PhoneNumber.toSubscriberNumber(phone),
          'DecryptedPassword': password,
        },
      );
      log('Login response: $response');

      // SAMP returns the member record as the single element of `Data`.
      log('Changing JSON return data into UserModel');
      final user = UserModel.fromJson(SampEnvelope.first(response));

      // A parsed record is not yet a valid session. SAMP answers "successfully"
      // with a member whose `Active` flag is false — the same shape as SIP
      // Sales' `if (creds.flag == 1)` check. Doing it here rather than in the
      // BLoC keeps it testable without building a widget tree.
      if (!user.isActive) {
        log('User is not active');
        // throw AccountInactiveException(message: user.status);
      } else {
        log('User is active');
      }

      return user;
    } on DioException catch (e) {
      // SampEnvelope.error has return type Never — it always throws,
      // so no rethrow is needed after it.
      log('Login DioException: ${e.error.toString()}');
      SampEnvelope.error(e);
    }
  }

  @override
  Future<UserModel> register({
    required String name,
    required String phone,
    String? email,
    required String password,
  }) async {
    try {
      await _dio.post(
        ApiConstants.modify,
        data: {
          'Mode': ModifyMode.create.wireValue,
          'TransID': 'REGISTRATION',
          'Data': {
            'MemberID': '', // blank = new account, per the confirmed contract
            'MemberName': name,
            'MemberPass': password,
            'PhoneNo': PhoneNumber.toSubscriberNumber(phone),
            'EmailAddress': email ?? '',
            'OldPass': '',
          },
        },
      );
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }

    // Same reasoning as submitGoogleAccount's Phase 3: Modify's own success
    // response shape has not been confirmed, while login's has — so fetch
    // the canonical member record through the trusted path instead of
    // parsing Modify's result directly.
    return login(phone, password);
  }

  @override
  Future<GoogleAccountIdentity> getGoogleIdentity() async {
    final GoogleSignInAccount account;

    try {
      log('Waiting for user response to choose gmail account');
      // 7.x API: authenticate() replaced signIn(). Returns a non-null account
      // or throws — there is no "null means cancelled" case any more.
      account = await GoogleSignIn.instance.authenticate();
      log('$account');
    } on GoogleSignInException catch (e) {
      // Dismissing the sheet is a choice, not a failure.
      if (e.code == GoogleSignInExceptionCode.canceled) {
        log('GoogleSignInExceptionCode canceled');
        throw const GoogleSignInCancelledException();
      }

      // The platform reports a missing client id as clientConfigurationError.
      // Its own wording ("CredentialManager requires a serverClientId") says
      // nothing about where that id comes from, so replace it with the fix.
      if (e.code == GoogleSignInExceptionCode.clientConfigurationError) {
        log('GoogleSignInExceptionCode clientConfigurationError');
        throw const ServerException(
          message:
              'Google sign-in has no OAuth client. In the Firebase console '
              'enable Google under Authentication → Sign-in method, add your '
              'SHA-1 fingerprint, then re-download google-services.json.',
        );
      }

      if (e.description == null) {
        log('Google sign-in failed');
      }
      log('${e.description}');
      throw ServerException(message: e.description ?? 'Google sign-in failed');
    }

    // No backend call, and no idToken read, here on purpose — the SAMP backend
    // has no Google-specific endpoint and never sees this identity directly.
    // It only prefills the complete-profile form; submitGoogleAccount is what
    // actually reaches the backend, using the ordinary phone-login contract.
    return GoogleAccountIdentity(
      displayName: account.displayName,
      email: account.email,
    );
  }

  @override
  Future<UserModel> submitGoogleAccount({
    required String name,
    required String phone,
    required String email,
  }) async {
    // Deterministic and never shown in the UI — see GooglePassword's doc for
    // why a Google-originated account needs a password at all.
    final password = GooglePassword.forNameFromEmail(email);
    log('User Phone Number: $phone');
    log('User Google Password: $password');
    log('User Email: $email');

    // ── Phase 1: does this phone already have an account? ───────────────────
    // There is no endpoint that answers that directly, so a login attempt
    // doubles as the check: if it succeeds, the phone was already registered
    // (by a previous Google sign-up using this same derivation, or the
    // password happens to match). AccountInactiveException means the account
    // exists but is barred — surfaced as-is, never papered over by
    // registering a duplicate.
    try {
      log('Attempt 1st Login');
      await login(phone, password);
    }
    // on AccountInactiveException {
    //   log('Account Inactive Exception');
    //   rethrow;
    // }
    on ServerException {
      log('Server Exception');
      // PLACEHOLDER: the real Flag/Memo values for "phone not found" vs
      // "phone found, wrong password" are not yet confirmed (see
      // ApiConstants.login). Until they are, any server-reported login
      // failure here is read as "not registered yet" and falls through to
      // registration below. If the phone actually belongs to a different,
      // unrelated account, Phase 2's Modify call is expected to reject the
      // duplicate — at which point that failure needs a case here too.
    } on UnauthorizedException {
      log('UnauthorizedException');
      // Same placeholder reasoning as above.
    }

    // ── Phase 2: register ────────────────────────────────────────────────────
    log('Registering New Account');
    try {
      await _dio.post(
        ApiConstants.modify,
        data: {
          'Mode': ModifyMode.create.wireValue,
          'TransID': 'REGISTRATION',
          'Data': {
            'MemberID': '', // blank = new account, per the confirmed contract
            'MemberName': name,
            'MemberPass': password,
            'PhoneNo': PhoneNumber.toSubscriberNumber(phone),
            'EmailAddress': email,
            'OldPass': '',
          },
        },
      );
    } on DioException catch (e) {
      SampEnvelope.error(e);
    }

    // ── Phase 3: log in for real ─────────────────────────────────────────────
    // Deliberately a second call rather than parsing Modify's own response:
    // Modify's success shape has not been confirmed, while login's has. This
    // way the resulting UserModel goes through the exact same parsing and
    // isActive gate as every other login, manual or Google.
    return login(phone, password);
  }
}
