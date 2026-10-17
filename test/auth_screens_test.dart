import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/router/app_routes.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/features/auth/data/app_user.dart';
import 'package:libria/features/auth/data/auth_repository.dart';
import 'package:libria/features/auth/data/user_repository.dart';
import 'package:libria/features/auth/presentation/forgot_password_screen.dart';
import 'package:libria/features/auth/presentation/register_screen.dart';

void main() {
  late GoRouter router;
  late _FakeAuthRepository authRepository;
  late _FakeUserRepository userRepository;

  setUp(() {
    router = GoRouter(
      initialLocation: AppRoutes.register,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.register,
          builder: (BuildContext context, GoRouterState state) =>
              const RegisterScreen(),
        ),
        GoRoute(
          path: AppRoutes.forgotPassword,
          builder: (BuildContext context, GoRouterState state) =>
              const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('login-screen')),
        ),
        GoRoute(
          path: AppRoutes.home,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('home-screen')),
        ),
        GoRoute(
          path: AppRoutes.admin,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('admin-screen')),
        ),
      ],
    );
    authRepository = _FakeAuthRepository();
    userRepository = _FakeUserRepository();
  });

  tearDown(() => router.dispose());

  Future<void> pumpScreen(
    WidgetTester tester,
    String location, {
    ThemeData? theme,
  }) async {
    router.go(location);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWith((Ref ref) => authRepository),
          userRepositoryProvider.overrideWith((Ref ref) => userRepository),
        ],
        child: MaterialApp.router(
          theme: theme ?? AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> fillRegistration(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), 'Siti Nurhaliza');
    await tester.enterText(
      find.byType(TextField).at(1),
      'siti.nurhaliza@libria.id',
    );
    await tester.enterText(find.byType(TextField).at(2), 'BukuRefleksi2024');
    await tester.enterText(find.byType(TextField).at(3), 'BukuRefleksi2024');
    await tester.pump();
  }

  testWidgets('Layar daftar menampilkan elemen desain utama', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, AppRoutes.register);

    expect(find.text(AppStrings.registerHeroTitle), findsOneWidget);
    expect(find.text(AppStrings.registerHeroSubtitle), findsOneWidget);
    expect(find.text(AppStrings.registerCommunityStat), findsOneWidget);
    expect(find.text(AppStrings.registerFullNameLabel), findsOneWidget);
    expect(find.text(AppStrings.registerEmailLabel), findsOneWidget);
    expect(find.text(AppStrings.registerPasswordLabel), findsOneWidget);
    expect(find.text(AppStrings.registerConfirmPasswordLabel), findsOneWidget);
    expect(find.text(AppStrings.registerFullNameHelper), findsOneWidget);
    expect(find.text(AppStrings.registerPasswordHelper), findsOneWidget);
    expect(find.text(AppStrings.registerSubmit), findsOneWidget);
    expect(find.text(AppStrings.registerOr), findsOneWidget);
    expect(find.text(AppStrings.registerGoogle), findsOneWidget);
    expect(find.text(AppStrings.registerHaveAccount), findsOneWidget);
    expect(find.text(AppStrings.registerSignIn), findsOneWidget);
    expect(
      find.textContaining(
        AppStrings.registerAgreementTerms,
        findRichText: true,
      ),
      findsOneWidget,
    );

    final Checkbox checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isFalse);
    expect(find.byTooltip(AppStrings.showPassword), findsNWidgets(2));
  });

  testWidgets(
    'Layar daftar dan lupa kata sandi muat pada lebar 390 mode gelap',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await pumpScreen(tester, AppRoutes.register, theme: AppTheme.dark);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text(AppStrings.registerGoogle));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.registerGoogle), findsOneWidget);
      expect(tester.takeException(), isNull);

      await pumpScreen(tester, AppRoutes.forgotPassword, theme: AppTheme.dark);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.text(AppStrings.forgotPasswordBackToLogin),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.forgotPasswordSubmit), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Kolom kosong menampilkan pesan validasi dan tidak mendaftar', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, AppRoutes.register);

    await tapVisible(tester, find.text(AppStrings.registerSubmit));

    expect(find.text(AppStrings.registerFullNameRequired), findsOneWidget);
    expect(find.text(AppStrings.registerEmailRequired), findsOneWidget);
    expect(find.text(AppStrings.registerPasswordRequired), findsOneWidget);
    expect(
      find.text(AppStrings.registerConfirmPasswordRequired),
      findsOneWidget,
    );
    expect(find.text(AppStrings.registerAgreementRequired), findsOneWidget);
    expect(authRepository.registerCalls, 0);
    expect(find.byType(RegisterScreen), findsOneWidget);
  });

  testWidgets('Kata sandi pendek dan konfirmasi berbeda ditolak', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, AppRoutes.register);

    await tester.enterText(find.byType(TextField).at(0), 'Siti Nurhaliza');
    await tester.enterText(
      find.byType(TextField).at(1),
      'siti.nurhaliza@libria.id',
    );
    await tester.enterText(find.byType(TextField).at(2), 'pendek');
    await tester.enterText(find.byType(TextField).at(3), 'berbeda');
    await tester.pump();
    await tapVisible(tester, find.byType(Checkbox));
    await tapVisible(tester, find.text(AppStrings.registerSubmit));

    expect(find.text(AppStrings.registerPasswordTooShort), findsOneWidget);
    expect(find.text(AppStrings.registerPasswordMismatch), findsOneWidget);
    expect(authRepository.registerCalls, 0);
  });

  testWidgets('Persetujuan wajib dicentang sebelum mendaftar', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, AppRoutes.register);

    await fillRegistration(tester);
    await tapVisible(tester, find.text(AppStrings.registerSubmit));

    expect(find.text(AppStrings.registerAgreementRequired), findsOneWidget);
    expect(authRepository.registerCalls, 0);
  });

  testWidgets('Pendaftaran email membuat dokumen user dan meminta verifikasi', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, AppRoutes.register);

    await fillRegistration(tester);
    await tapVisible(tester, find.byType(Checkbox));
    await tapVisible(tester, find.text(AppStrings.registerSubmit));

    expect(authRepository.registerCalls, 1);
    expect(authRepository.registeredFullName, 'Siti Nurhaliza');
    expect(authRepository.registeredEmail, 'siti.nurhaliza@libria.id');
    expect(authRepository.registeredPassword, 'BukuRefleksi2024');
    expect(userRepository.ensureCalls, 1);
    expect(authRepository.signOutCalls, 1);
    expect(find.text(AppStrings.registerSuccessTitle), findsOneWidget);
    expect(
      find.text(AppStrings.registerSuccessMessage('siti.nurhaliza@libria.id')),
      findsOneWidget,
    );
    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.text(AppStrings.registerSubmit), findsNothing);
  });

  testWidgets('Kegagalan pendaftaran menampilkan pesan dan tetap di layar', (
    WidgetTester tester,
  ) async {
    authRepository.registerFailure = const AuthFailure(
      AppStrings.authErrorEmailInUse,
    );
    await pumpScreen(tester, AppRoutes.register);

    await fillRegistration(tester);
    await tapVisible(tester, find.byType(Checkbox));
    await tapVisible(tester, find.text(AppStrings.registerSubmit));

    expect(find.text(AppStrings.authErrorEmailInUse), findsOneWidget);
    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.text(AppStrings.registerSuccessTitle), findsNothing);
    expect(userRepository.ensureCalls, 0);
  });

  testWidgets('Daftar dengan Google membuka beranda untuk role user', (
    WidgetTester tester,
  ) async {
    userRepository.appUser = _appUser(AppUser.roleUser);
    await pumpScreen(tester, AppRoutes.register);

    await tapVisible(tester, find.text(AppStrings.registerGoogle));

    expect(authRepository.googleSignInCalls, 1);
    expect(userRepository.ensureCalls, 1);
    expect(find.text('home-screen'), findsOneWidget);
  });

  testWidgets('Daftar dengan Google admin membuka dashboard admin', (
    WidgetTester tester,
  ) async {
    userRepository.appUser = _appUser(AppUser.roleAdmin);
    await pumpScreen(tester, AppRoutes.register);

    await tapVisible(tester, find.text(AppStrings.registerGoogle));

    expect(find.text('admin-screen'), findsOneWidget);
  });

  testWidgets('Tautan Masuk di sini membuka layar masuk', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, AppRoutes.register);

    await tapVisible(tester, find.text(AppStrings.registerSignIn));

    expect(find.text('login-screen'), findsOneWidget);
  });

  testWidgets('Layar lupa kata sandi menampilkan kolom email dan tombol', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, AppRoutes.forgotPassword);

    expect(find.text(AppStrings.forgotPasswordTitle), findsOneWidget);
    expect(find.text(AppStrings.forgotPasswordSubtitle), findsOneWidget);
    expect(find.text(AppStrings.forgotPasswordEmailLabel), findsOneWidget);
    expect(find.text(AppStrings.forgotPasswordSubmit), findsOneWidget);
    expect(find.text(AppStrings.forgotPasswordBackToLogin), findsOneWidget);
  });

  testWidgets('Email kosong ditolak sebelum meminta tautan reset', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, AppRoutes.forgotPassword);

    await tapVisible(tester, find.text(AppStrings.forgotPasswordSubmit));

    expect(find.text(AppStrings.forgotPasswordEmailRequired), findsOneWidget);
    expect(authRepository.passwordResetCalls, 0);
  });

  testWidgets('Format email salah ditolak sebelum meminta tautan reset', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, AppRoutes.forgotPassword);

    await tester.enterText(find.byType(TextField), 'bukan-email');
    await tapVisible(tester, find.text(AppStrings.forgotPasswordSubmit));

    expect(find.text(AppStrings.authErrorInvalidEmail), findsOneWidget);
    expect(authRepository.passwordResetCalls, 0);
  });

  testWidgets('Tautan reset terkirim dan pesan hasil ditampilkan', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, AppRoutes.forgotPassword);

    await tester.enterText(find.byType(TextField), 'siti.nurhaliza@libria.id');
    await tapVisible(tester, find.text(AppStrings.forgotPasswordSubmit));

    expect(authRepository.passwordResetCalls, 1);
    expect(authRepository.passwordResetEmail, 'siti.nurhaliza@libria.id');
    expect(
      find.text(
        AppStrings.forgotPasswordSuccessMessage('siti.nurhaliza@libria.id'),
      ),
      findsOneWidget,
    );
    expect(find.text(AppStrings.forgotPasswordSubmit), findsNothing);
  });

  testWidgets('Kegagalan kirim tautan menampilkan pesan dan tetap di layar', (
    WidgetTester tester,
  ) async {
    authRepository.passwordResetFailure = const AuthFailure(
      AppStrings.authErrorNetwork,
    );
    await pumpScreen(tester, AppRoutes.forgotPassword);

    await tester.enterText(find.byType(TextField), 'siti.nurhaliza@libria.id');
    await tapVisible(tester, find.text(AppStrings.forgotPasswordSubmit));

    expect(find.text(AppStrings.authErrorNetwork), findsOneWidget);
    expect(find.text(AppStrings.forgotPasswordSubmit), findsOneWidget);
    expect(find.text(AppStrings.forgotPasswordSuccessTitle), findsNothing);
  });

  testWidgets('Tautan kembali di layar reset membuka layar masuk', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, AppRoutes.forgotPassword);

    await tapVisible(tester, find.text(AppStrings.forgotPasswordBackToLogin));

    expect(find.text('login-screen'), findsOneWidget);
  });
}

AppUser _appUser(String role) {
  return AppUser(
    uid: 'u1',
    displayName: 'Siti Nurhaliza',
    email: 'siti.nurhaliza@libria.id',
    role: role,
  );
}

class _FakeAuthRepository implements AuthRepository {
  User? emailUser;
  User? googleUser;
  AuthFailure? registerFailure;
  AuthFailure? googleFailure;
  AuthFailure? passwordResetFailure;

  int registerCalls = 0;
  int googleSignInCalls = 0;
  int passwordResetCalls = 0;
  int signOutCalls = 0;
  String? registeredFullName;
  String? registeredEmail;
  String? registeredPassword;
  String? passwordResetEmail;

  @override
  User? currentUser;

  @override
  Stream<User?> get authStateChanges => const Stream<User?>.empty();

  @override
  Future<UserCredential> registerWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async {
    registerCalls++;
    registeredFullName = fullName;
    registeredEmail = email;
    registeredPassword = password;
    if (registerFailure != null) {
      throw registerFailure!;
    }
    final User user = emailUser ?? _FakeUser(email: email);
    currentUser = user;
    return _FakeUserCredential(user);
  }

  @override
  Future<UserCredential> signInWithGoogle() async {
    googleSignInCalls++;
    if (googleFailure != null) {
      throw googleFailure!;
    }
    final User user = googleUser ?? _FakeUser();
    currentUser = user;
    return _FakeUserCredential(user);
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    passwordResetCalls++;
    passwordResetEmail = email;
    if (passwordResetFailure != null) {
      throw passwordResetFailure!;
    }
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    currentUser = null;
  }

  @override
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> sendEmailVerification() async {}
}

class _FakeUserRepository implements UserRepository {
  AppUser? appUser;
  int ensureCalls = 0;

  @override
  Future<void> ensureUserDocument(User firebaseUser) async {
    ensureCalls++;
  }

  @override
  Stream<AppUser?> watchUser(String uid) => Stream<AppUser?>.value(appUser);
}

class _FakeUserCredential implements UserCredential {
  _FakeUserCredential(this.user);

  @override
  final User? user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements User {
  _FakeUser({this.email = 'siti.nurhaliza@libria.id'});

  @override
  final String uid = 'u1';

  @override
  final String? email;

  @override
  bool get emailVerified => true;

  @override
  String? get displayName => 'Siti Nurhaliza';

  @override
  String? get photoURL => null;

  @override
  Future<void> reload() async {}

  @override
  Future<void> sendEmailVerification([ActionCodeSettings? settings]) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
