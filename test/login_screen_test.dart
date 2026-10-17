import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:libria/core/constants/app_strings.dart';
import 'package:libria/core/router/app_routes.dart';
import 'package:libria/core/theme/app_theme.dart';
import 'package:libria/core/widgets/google_logo.dart';
import 'package:libria/features/auth/data/app_user.dart';
import 'package:libria/features/auth/data/auth_repository.dart';
import 'package:libria/features/auth/data/user_repository.dart';
import 'package:libria/features/auth/presentation/login_screen.dart';

void main() {
  late GoRouter router;
  late _FakeAuthRepository authRepository;
  late _FakeUserRepository userRepository;

  setUp(() {
    router = GoRouter(
      initialLocation: AppRoutes.login,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.login,
          builder: (BuildContext context, GoRouterState state) =>
              const LoginScreen(),
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
        GoRoute(
          path: AppRoutes.register,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('register-screen')),
        ),
        GoRoute(
          path: AppRoutes.forgotPassword,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('forgot-password-screen')),
        ),
      ],
    );
    authRepository = _FakeAuthRepository();
    userRepository = _FakeUserRepository();
  });

  tearDown(() => router.dispose());

  Future<void> pumpLogin(WidgetTester tester, {ThemeData? theme}) async {
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

  Future<void> fillCredentials(WidgetTester tester) async {
    await tester.enterText(
      find.byType(TextField).at(0),
      'siti.nurhaliza@libria.id',
    );
    await tester.enterText(find.byType(TextField).at(1), 'BukuRefleksi2024');
    await tester.pump();
  }

  testWidgets('Layar masuk menampilkan elemen desain utama', (
    WidgetTester tester,
  ) async {
    await pumpLogin(tester);

    expect(find.text(AppStrings.loginWelcomeTitle), findsOneWidget);
    expect(find.text(AppStrings.loginSubtitle), findsOneWidget);
    expect(find.text(AppStrings.loginEmailLabel), findsOneWidget);
    expect(find.text(AppStrings.loginPasswordLabel), findsOneWidget);
    expect(find.text(AppStrings.loginForgotPassword), findsOneWidget);
    expect(find.text(AppStrings.loginSubmit), findsOneWidget);
    expect(find.text(AppStrings.loginOr), findsOneWidget);
    expect(find.text(AppStrings.loginGoogle), findsOneWidget);
    expect(find.text(AppStrings.loginNoAccount), findsOneWidget);
    expect(find.text(AppStrings.loginRegisterNow), findsOneWidget);
    expect(find.byType(GoogleLogo), findsOneWidget);

    await tester.tap(find.byTooltip(AppStrings.showPassword));
    await tester.pump();

    expect(find.byTooltip(AppStrings.hidePassword), findsOneWidget);
  });

  final List<Size> responsiveSizes = <Size>[
    const Size(360, 800),
    const Size(800, 1280),
    const Size(1280, 800),
  ];

  for (final Size size in responsiveSizes) {
    testWidgets(
      'Layar masuk muat pada ${size.width.toInt()}x${size.height.toInt()}',
      (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await pumpLogin(
          tester,
          theme: size.width >= 600 ? AppTheme.dark : AppTheme.light,
        );
        await tester.ensureVisible(find.text(AppStrings.loginSubmit));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.getCenter(find.text(AppStrings.loginWelcomeTitle)).dy,
          lessThan(tester.getCenter(find.text(AppStrings.loginEmailLabel)).dy),
        );
        expect(
          tester.getSize(find.byType(TextField).first).width,
          lessThanOrEqualTo(640),
        );

        await tester.ensureVisible(find.text(AppStrings.loginSubmit));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Kolom kosong menampilkan pesan validasi dan tidak masuk', (
    WidgetTester tester,
  ) async {
    await pumpLogin(tester);

    await tapVisible(tester, find.text(AppStrings.loginSubmit));

    expect(find.text(AppStrings.loginEmailRequired), findsOneWidget);
    expect(find.text(AppStrings.loginPasswordRequired), findsOneWidget);
    expect(authRepository.emailSignInCalls, 0);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('Format email yang salah ditolak sebelum memanggil Firebase', (
    WidgetTester tester,
  ) async {
    await pumpLogin(tester);

    await tester.enterText(find.byType(TextField).at(0), 'bukan-email');
    await tester.enterText(find.byType(TextField).at(1), 'rahasia123');
    await tapVisible(tester, find.text(AppStrings.loginSubmit));

    expect(find.text(AppStrings.authErrorInvalidEmail), findsOneWidget);
    expect(authRepository.emailSignInCalls, 0);
  });

  testWidgets('Kegagalan masuk menampilkan pesan dan tetap di layar masuk', (
    WidgetTester tester,
  ) async {
    authRepository.emailFailure = const AuthFailure(
      AppStrings.authErrorInvalidCredential,
    );
    await pumpLogin(tester);

    await fillCredentials(tester);
    await tapVisible(tester, find.text(AppStrings.loginSubmit));

    expect(find.text(AppStrings.authErrorInvalidCredential), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('home-screen'), findsNothing);
    expect(authRepository.emailSignInCalls, 1);
  });

  testWidgets('Email belum terverifikasi ditolak dan dapat dikirim ulang', (
    WidgetTester tester,
  ) async {
    authRepository.emailUser = _FakeUser(emailVerified: false);
    await pumpLogin(tester);

    await fillCredentials(tester);
    await tapVisible(tester, find.text(AppStrings.loginSubmit));

    expect(find.text(AppStrings.loginEmailNotVerified), findsOneWidget);
    expect(find.text(AppStrings.loginResendVerification), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(authRepository.emailSignInCalls, 1);
    expect(authRepository.sendVerificationCalls, 1);
    expect(authRepository.signOutCalls, 1);

    await tapVisible(tester, find.text(AppStrings.loginResendVerification));

    expect(authRepository.emailSignInCalls, 2);
    expect(authRepository.sendVerificationCalls, 2);
    expect(authRepository.signOutCalls, 2);
    expect(
      find.text(AppStrings.loginVerificationResent('siti.nurhaliza@libria.id')),
      findsOneWidget,
    );
  });

  testWidgets('Masuk email admin membuka dashboard admin', (
    WidgetTester tester,
  ) async {
    authRepository.emailUser = _FakeUser();
    userRepository.appUser = _appUser(AppUser.roleAdmin);
    await pumpLogin(tester);

    await fillCredentials(tester);
    await tapVisible(tester, find.text(AppStrings.loginSubmit));

    expect(find.text('admin-screen'), findsOneWidget);
    expect(userRepository.ensureCalls, 1);
  });

  testWidgets(
    'Masuk Google membuka beranda untuk role user tanpa cek verifikasi',
    (WidgetTester tester) async {
      authRepository.googleUser = _FakeUser(emailVerified: false);
      userRepository.appUser = _appUser(AppUser.roleUser);
      await pumpLogin(tester);

      await tapVisible(tester, find.text(AppStrings.loginGoogle));

      expect(find.text('home-screen'), findsOneWidget);
      expect(authRepository.googleSignInCalls, 1);
      expect(userRepository.ensureCalls, 1);
    },
  );

  testWidgets('Tombol masuk menampilkan status loading selama menunggu', (
    WidgetTester tester,
  ) async {
    final Completer<UserCredential> completer = Completer<UserCredential>();
    authRepository.emailCompleter = completer;
    authRepository.emailUser = _FakeUser();
    userRepository.appUser = _appUser(AppUser.roleUser);
    await pumpLogin(tester);

    await fillCredentials(tester);
    await tester.ensureVisible(find.text(AppStrings.loginSubmit));
    await tester.tap(find.text(AppStrings.loginSubmit));
    await tester.pump();

    expect(find.text(AppStrings.loginSubmitting), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    completer.complete(_FakeUserCredential(authRepository.emailUser!));
    await tester.pumpAndSettle();

    expect(find.text('home-screen'), findsOneWidget);
  });

  testWidgets('Tautan Daftar Sekarang membuka rute pendaftaran', (
    WidgetTester tester,
  ) async {
    await pumpLogin(tester);

    await tapVisible(tester, find.text(AppStrings.loginRegisterNow));

    expect(find.text('register-screen'), findsOneWidget);
  });

  testWidgets('Tautan Lupa Kata Sandi membuka rute reset', (
    WidgetTester tester,
  ) async {
    await pumpLogin(tester);

    await tapVisible(tester, find.text(AppStrings.loginForgotPassword));

    expect(find.text('forgot-password-screen'), findsOneWidget);
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
  AuthFailure? emailFailure;
  AuthFailure? googleFailure;
  Completer<UserCredential>? emailCompleter;

  int emailSignInCalls = 0;
  int googleSignInCalls = 0;
  int sendVerificationCalls = 0;
  int signOutCalls = 0;

  @override
  User? currentUser;

  @override
  Stream<User?> get authStateChanges => const Stream<User?>.empty();

  @override
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    emailSignInCalls++;
    if (emailCompleter != null) {
      final UserCredential credential = await emailCompleter!.future;
      currentUser = credential.user;
      return credential;
    }
    if (emailFailure != null) {
      throw emailFailure!;
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
  Future<void> sendEmailVerification() async {
    sendVerificationCalls++;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    currentUser = null;
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<UserCredential> registerWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }
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
  _FakeUser({
    this.email = 'siti.nurhaliza@libria.id',
    this.emailVerified = true,
  });

  @override
  final String uid = 'u1';

  @override
  final String? email;

  @override
  final bool emailVerified;

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
