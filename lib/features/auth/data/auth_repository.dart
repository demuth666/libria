import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/constants/app_strings.dart';

/// Galat autentikasi dengan pesan yang sudah ramah pengguna dalam bahasa
/// Indonesia, siap ditampilkan langsung ke layar tanpa diterjemahkan lagi.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Akses ke Firebase Auth dan Google Sign-In untuk fitur autentikasi.
///
/// Widget tidak memanggil `FirebaseAuth` atau `GoogleSignIn` secara langsung;
/// semua akses lewat kelas ini (lihat [authRepositoryProvider]). Setiap
/// metode memetakan galat platform, termasuk pembatalan pengguna pada proses
/// masuk dengan Google dan kegagalan jaringan, menjadi [AuthFailure] berpesan
/// bahasa Indonesia.
class AuthRepository {
  AuthRepository({FirebaseAuth? firebaseAuth, GoogleSignIn? googleSignIn})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  Future<void>? _googleSignInInit;

  /// Status login saat ini, lalu setiap perubahannya (FR-A6).
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Pengguna yang sedang masuk, atau `null` bila belum masuk.
  User? get currentUser => _firebaseAuth.currentUser;

  /// Masuk dengan akun Google lewat Firebase Auth (FR-A1).
  Future<UserCredential> signInWithGoogle() async {
    try {
      await _ensureGoogleSignInReady();
      final GoogleSignInAccount account = await _googleSignIn.authenticate();
      final GoogleSignInAuthentication auth = account.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
      );
      return await _firebaseAuth.signInWithCredential(credential);
    } on GoogleSignInException catch (error) {
      throw AuthFailure(mapGoogleSignInError(error));
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(mapFirebaseAuthError(error));
    } catch (_) {
      throw const AuthFailure(AppStrings.authErrorNetwork);
    }
  }

  /// Masuk dengan email dan kata sandi (FR-A1).
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(mapFirebaseAuthError(error));
    } catch (_) {
      throw const AuthFailure(AppStrings.authErrorNetwork);
    }
  }

  /// Daftar akun baru dengan email dan kata sandi, lalu kirim email
  /// verifikasi (FR-A2, FR-A4).
  Future<UserCredential> registerWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential = await _firebaseAuth
          .createUserWithEmailAndPassword(email: email, password: password);
      await credential.user?.updateDisplayName(fullName);
      await credential.user?.sendEmailVerification();
      return credential;
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(mapFirebaseAuthError(error));
    } catch (_) {
      throw const AuthFailure(AppStrings.authErrorNetwork);
    }
  }

  /// Kirim ulang email verifikasi ke pengguna yang sedang masuk (FR-A4).
  Future<void> sendEmailVerification() async {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AuthFailure(AppStrings.authErrorNoCurrentUser);
    }
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(mapFirebaseAuthError(error));
    } catch (_) {
      throw const AuthFailure(AppStrings.authErrorNetwork);
    }
  }

  /// Kirim tautan reset kata sandi (FR-A5).
  ///
  /// Galat `user-not-found` sengaja diabaikan agar hasil yang terlihat
  /// pengguna selalu sama, baik email terdaftar maupun tidak.
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found') {
        return;
      }
      throw AuthFailure(mapFirebaseAuthError(error));
    } catch (_) {
      throw const AuthFailure(AppStrings.authErrorNetwork);
    }
  }

  /// Keluar dari Firebase Auth dan Google Sign-In (FR-A6).
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(mapFirebaseAuthError(error));
    }
    try {
      await _googleSignIn.signOut();
    } on Exception {
      // Keluar dari Google bersifat tambahan; kegagalannya tidak boleh
      // menghalangi keluarnya pengguna dari Firebase Auth.
    }
  }

  Future<void> _ensureGoogleSignInReady() {
    return _googleSignInInit ??= _googleSignIn.initialize();
  }

  /// Memetakan galat `google_sign_in` menjadi pesan bahasa Indonesia.
  ///
  /// Dipakai sebagai `static` agar pemetaan dapat diuji tanpa memerlukan
  /// instance `FirebaseAuth`/`GoogleSignIn` yang hidup.
  static String mapGoogleSignInError(GoogleSignInException error) {
    if (error.code == GoogleSignInExceptionCode.canceled) {
      return AppStrings.authErrorGoogleCancelled;
    }
    return AppStrings.authErrorGoogleFailed;
  }

  /// Memetakan kode galat `FirebaseAuthException` menjadi pesan bahasa
  /// Indonesia yang ramah pengguna.
  static String mapFirebaseAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return AppStrings.authErrorInvalidEmail;
      case 'user-disabled':
        return AppStrings.authErrorUserDisabled;
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return AppStrings.authErrorInvalidCredential;
      case 'email-already-in-use':
        return AppStrings.authErrorEmailInUse;
      case 'weak-password':
        return AppStrings.authErrorWeakPassword;
      case 'operation-not-allowed':
        return AppStrings.authErrorOperationNotAllowed;
      case 'too-many-requests':
        return AppStrings.authErrorTooManyRequests;
      case 'network-request-failed':
        return AppStrings.authErrorNetwork;
      case 'requires-recent-login':
        return AppStrings.authErrorRequiresRecentLogin;
      default:
        return AppStrings.genericError;
    }
  }
}

/// Akses [AuthRepository] bersama lewat Riverpod.
final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) => AuthRepository());
