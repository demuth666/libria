import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/features/auth/data/auth_repository.dart';

void main() {
  group('AuthRepository.mapFirebaseAuthError', () {
    final Map<String, String> casesByCode = <String, String>{
      'invalid-email': AppStrings.authErrorInvalidEmail,
      'user-disabled': AppStrings.authErrorUserDisabled,
      'user-not-found': AppStrings.authErrorInvalidCredential,
      'wrong-password': AppStrings.authErrorInvalidCredential,
      'invalid-credential': AppStrings.authErrorInvalidCredential,
      'email-already-in-use': AppStrings.authErrorEmailInUse,
      'weak-password': AppStrings.authErrorWeakPassword,
      'operation-not-allowed': AppStrings.authErrorOperationNotAllowed,
      'too-many-requests': AppStrings.authErrorTooManyRequests,
      'network-request-failed': AppStrings.authErrorNetwork,
      'requires-recent-login': AppStrings.authErrorRequiresRecentLogin,
      'kode-tidak-dikenal': AppStrings.genericError,
    };

    casesByCode.forEach((String code, String expectedMessage) {
      test('kode "$code" menghasilkan pesan bahasa Indonesia yang tepat', () {
        final String message = AuthRepository.mapFirebaseAuthError(
          FirebaseAuthException(code: code),
        );

        expect(message, expectedMessage);
      });
    });
  });

  group('AuthRepository.mapGoogleSignInError', () {
    test('pembatalan pengguna menghasilkan pesan pembatalan', () {
      final String message = AuthRepository.mapGoogleSignInError(
        const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
      );

      expect(message, AppStrings.authErrorGoogleCancelled);
    });

    test('kode lain menghasilkan pesan kegagalan umum Google', () {
      final String message = AuthRepository.mapGoogleSignInError(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.interrupted,
        ),
      );

      expect(message, AppStrings.authErrorGoogleFailed);
    });
  });

  group('AuthFailure', () {
    test('toString mengembalikan pesan apa adanya', () {
      const AuthFailure failure = AuthFailure('Pesan uji.');

      expect(failure.toString(), 'Pesan uji.');
    });
  });
}
