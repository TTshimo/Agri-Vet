import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'diagnosis_screen.dart';
import 'community_screen.dart';
import 'learn_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import '../services/notification_service.dart';
import '../services/profile_service.dart';
import '../theme/palette.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Signed in from here on: register this phone for push notifications.
    // A tapped notification opens the in-app notification list.
    NotificationService.instance.openNotifications = () {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      );
    };
    NotificationService.instance.start();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      ProfileService.ensureProfile(user).catchError((Object e) {
        debugPrint('Profile check failed: $e');
      });
    }
  }

  final List<Widget> _screens = const [
    HomeScreen(),
    DiagnosisScreen(),
    CommunityScreen(),
    LearnScreen(),
    ProfileScreen(),
  ];

  final List<_NavItem> _navItems = const [
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _NavItem(
      icon: Icons.biotech_outlined,
      activeIcon: Icons.biotech_rounded,
      label: 'Diagnose',
    ),
    _NavItem(
      icon: Icons.people_outline_rounded,
      activeIcon: Icons.people_rounded,
      label: 'Community',
    ),
    _NavItem(
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book_rounded,
      label: 'Learn',
    ),
    _NavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _AgroLensNavBar(
        currentIndex: _currentIndex,
        items: _navItems,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

class _AgroLensNavBar extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;

  const _AgroLensNavBar({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Container(
      decoration: BoxDecoration(
        color: Bg.surface,
        border: Border(
          top: BorderSide(color: Bg.hairline, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            top: 10,
            bottom: bottomPad > 0 ? 4 : 12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final active = i == currentIndex;
              final item = items[i];
              final isProfileTab = item.label == 'Profile';

              // Profile tab watches for unread notifications and shows a
              // small badge dot — mirrors the unread query used on the
              // Notifications item inside ProfileSocialMenu.
              if (isProfileTab && uid != null) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('notifications')
                      .doc(uid)
                      .collection('items')
                      .where('read', isEqualTo: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final hasUnread = (snapshot.data?.docs.length ?? 0) > 0;
                    return _NavTile(
                      item: item,
                      active: active,
                      showBadge: hasUnread,
                      onTap: () => onTap(i),
                    );
                  },
                );
              }

              return _NavTile(
                item: item,
                active: active,
                onTap: () => onTap(i),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool active;
  final bool showBadge;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.active,
    this.showBadge = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Bg.rust.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    active ? item.activeIcon : item.icon,
                    key: ValueKey(active),
                    size: 24,
                    color: active ? Fg.rust : Fg.inkSoft,
                  ),
                ),
                if (showBadge)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Bg.danger,
                        shape: BoxShape.circle,
                        border: Border.all(color: Bg.surface, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? Fg.rust : Fg.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}