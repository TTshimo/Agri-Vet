import 'package:agrivet/screens/community_screen.dart';
import 'package:agrivet/screens/home_screen.dart';
import 'package:agrivet/screens/learn_screen.dart';
import 'package:agrivet/screens/messaging_screen.dart';
import 'package:agrivet/screens/news_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const AgriVetApp());
}

class AgriVetApp extends StatelessWidget {
  const AgriVetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgriVet',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const SplashScreen(),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.greenDark,
        secondary: AppColors.greenMid,
        surface: AppColors.background,
        error: AppColors.red,
      ),
      textTheme: GoogleFonts.interTextTheme(),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.greenDark,
        foregroundColor: AppColors.greenLight,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.greenDark,
          foregroundColor: AppColors.greenLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.greenDark, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }
}

// ── App shell with bottom nav ─────────────────────────────────────────────────

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  final _screens = const [
    HomeScreen(),
    NewsScreen(),
    CommunityScreen(),
    MessagingScreen(),
    LearnScreen(),

    // ChatScreen(conversationId: conversationId, currentUid: currentUid, otherUid: otherUid, otherName: otherName),
    // ForgotPasswordScreen(),
    // DiagnosisScreen(),
    // LoginScreen(),
    // MessagingScreen(),
    // ProfileScreen(),
    // RegisterScreen(),
    // SettingsScreen(),
    // TwoStepVerificationScreen(phoneNumber: phoneNumber),

  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        uid: _uid,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ── Bottom nav with unread badge on Messages ──────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final String uid;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.currentIndex,
    required this.uid,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
                active: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.newspaper_outlined,
                activeIcon: Icons.newspaper_rounded,
                label: 'News',
                active: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.people_outline_rounded,
                activeIcon: Icons.people_rounded,
                label: 'Community',
                active: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              // Messages tab with live unread badge
              StreamBuilder<QuerySnapshot>(
                stream: uid.isEmpty
                    ? const Stream.empty()
                    : FirebaseFirestore.instance
                        .collection('conversations')
                        .where('participants', arrayContains: uid)
                        .snapshots(),
                builder: (context, snapshot) {
                  int totalUnread = 0;
                  for (final doc in snapshot.data?.docs ?? []) {
                    final data = doc.data() as Map<String, dynamic>;
                    final counts =
                        data['unreadCounts'] as Map<String, dynamic>?;
                    totalUnread += ((counts?[uid] ?? 0) as num).toInt();
                  }
                  return _NavItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    activeIcon: Icons.chat_bubble_rounded,
                    label: 'Messages',
                    active: currentIndex == 3,
                    badge: totalUnread,
                    onTap: () => onTap(3),
                  );
                },
              ),
              _NavItem(
                icon: Icons.menu_book_outlined,
                activeIcon: Icons.menu_book_rounded,
                label: 'Learn',
                active: currentIndex == 4,
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final int badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.greenDark : AppColors.textSecondary;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(active ? activeIcon : icon, color: color, size: 24),
                if (badge > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight:
                    active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── App colors / spacing / radius (unchanged) ─────────────────────────────────

class AppColors {
  AppColors._();

  static const greenDark = Color(0xFF1A3A2A);
  static const greenMid = Color(0xFF1D9E75);
  static const greenLight = Color(0xFFE1F5EE);
  static const greenText = Color(0xFF0F6E56);
  static const greenDeep = Color(0xFF085041);
  static const greenHint = Color(0xFF9FE1CB);

  static const amber = Color(0xFFC8873A);
  static const amberLight = Color(0xFFFAEEDA);
  static const amberText = Color(0xFF854F0B);
  static const amberDark = Color(0xFF633806);

  static const red = Color(0xFFA32D2D);
  static const redLight = Color(0xFFFCEBEB);

  static const brown = Color(0xFF8B5A2B);

  static const background = Color(0xFFF7F5F0);
  static const background2 = Color(0xFFEEEBE4);
  static const border = Color(0xFFE0DDD6);
  static const textPrimary = Color(0xFF2C2C2C);
  static const textSecondary = Color(0xFF7A776F);

  static const white = Colors.white;
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double screenPad = 16;
}

class AppRadius {
  AppRadius._();

  static const double card = 14;
  static const double button = 12;
  static const double chip = 20;
  static const double avatar = 100;
}