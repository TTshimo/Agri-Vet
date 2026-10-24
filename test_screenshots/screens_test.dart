// Renders the main screens as PNGs so layout and colours can be reviewed
// without a phone. Not part of `flutter test` (it lives outside test/);
// the Screenshots workflow runs it and publishes the images to the
// `screenshots` branch.
//
//   flutter test test_screenshots --update-goldens
//
// Firebase is stubbed, so screens show their empty/loading states.

import 'dart:io';

import 'package:agrivet/providers/language_provider.dart';
import 'package:agrivet/providers/theme_provider.dart';
import 'package:agrivet/screens/diagnosis_screen.dart';
import 'package:agrivet/screens/forgot_password_screen.dart';
import 'package:agrivet/screens/home_screen.dart';
import 'package:agrivet/screens/learn_screen.dart';
import 'package:agrivet/screens/login_screen.dart';
import 'package:agrivet/screens/notifications_screen.dart';
import 'package:agrivet/screens/profile_screen.dart';
import 'package:agrivet/screens/register_screen.dart';
import 'package:agrivet/screens/settings_screen.dart';
import 'package:agrivet/screens/community_screen.dart';
import 'package:agrivet/screens/messaging_screen.dart';
import 'package:agrivet/theme/palette.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Real fonts instead of the test font (which draws every letter as a box).
Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  final roboto = FontLoader('Roboto');
  final icons = FontLoader('MaterialIcons');
  for (final f in dir.listSync().whereType<File>()) {
    final name = f.uri.pathSegments.last;
    final bytes = f.readAsBytes().then((b) => ByteData.view(b.buffer));
    if (name.startsWith('Roboto-') && !name.contains('Mono') && !name.contains('Condensed')) {
      roboto.addFont(bytes);
    } else if (name.startsWith('MaterialIcons-Regular')) {
      icons.addFont(bytes);
    }
  }
  await roboto.load();
  await icons.load();
}

class _Shot {
  final String name;
  final Widget Function() build;
  final String language;
  const _Shot(this.name, this.build, {this.language = 'en'});
}

final _shots = <_Shot>[
  _Shot('login', () => const LoginScreen()),
  _Shot('register', () => const RegisterScreen()),
  _Shot('forgot_password', () => const ForgotPasswordScreen()),
  _Shot('home', () => const HomeScreen()),
  _Shot('diagnose_pick', () => const DiagnosisScreen()),
  _Shot('diagnose_animal', () => const DiagnosisScreen(initialType: DiagnosisType.animal)),
  _Shot('diagnose_animal_sesotho',
      () => const DiagnosisScreen(initialType: DiagnosisType.animal),
      language: 'st'),
  _Shot('diagnose_plant_shona',
      () => const DiagnosisScreen(initialType: DiagnosisType.plant),
      language: 'sn'),
  _Shot('result_animal',
      () => const DiagnosisScreen(
          initialType: DiagnosisType.animal, previewDisease: 'foot and mouth')),
  _Shot('result_animal_shona',
      () => const DiagnosisScreen(
          initialType: DiagnosisType.animal, previewDisease: 'foot and mouth'),
      language: 'sn'),
  _Shot('result_plant_spanish',
      () => const DiagnosisScreen(
          initialType: DiagnosisType.plant, previewDisease: 'tomato late blight'),
      language: 'es'),
  _Shot('community', () => const CommunityScreen()),
  _Shot('learn', () => const LearnScreen()),
  _Shot('messaging', () => const MessagingScreen()),
  _Shot('notifications', () => const NotificationsScreen()),
  _Shot('profile', () => const ProfileScreen()),
  _Shot('settings', () => const SettingsScreen()),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await _loadFonts();
    await Firebase.initializeApp();
  });

  for (final dark in [false, true]) {
    for (final shot in _shots) {
      final mode = dark ? 'dark' : 'light';
      testWidgets('${shot.name} ($mode)', (tester) async {
        SharedPreferences.setMockInitialValues({'language': shot.language, 'isDark': dark});
        Palette.dark = dark;
        tester.view.physicalSize = const Size(720, 1560); // 360 x 780 phone
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        final lang = await tester.runAsync(() async {
          final l = LanguageProvider();
          await l.ready;
          return l;
        });

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => ThemeProvider()),
              ChangeNotifierProvider.value(value: lang!),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto'),
              darkTheme: ThemeData(
                  useMaterial3: true, brightness: Brightness.dark, fontFamily: 'Roboto'),
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              home: RepaintBoundary(key: const ValueKey('shot'), child: shot.build()),
            ),
          ),
        );
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
          await tester.pump(const Duration(milliseconds: 200));
        }

        await expectLater(
          find.byKey(const ValueKey('shot')),
          matchesGoldenFile('shots/${shot.name}_$mode.png'),
        );
      });
    }
  }
}
