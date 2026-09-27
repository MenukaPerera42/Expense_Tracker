import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../routing/app_router.dart';
import '../providers/auth_providers.dart';
import 'analytics_screen.dart';
import 'dashboard_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    ref.listen(authActionProvider, (previous, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authErrorMessage(next.error))),
        );
      }
    });
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _selectedIndex,
          children: const [
            DashboardView(),
            AnalyticsScreen(),
          ],
        ),
      ),
      // Always-pinned floating pill bottom nav
      bottomNavigationBar: _BottomNav(
        selectedIndex: _selectedIndex,
        onTap: (index) {
          // The "Add" button (index 2) pushes a route instead of switching tabs
          if (index == 2) {
            context.push(AppRouter.addExpensePath);
            return;
          }
          // History (index 3) pushes the full history screen
          if (index == 3) {
            context.push(AppRouter.expenseHistoryPath);
            return;
          }
          // Settings (index 4) pushes settings
          if (index == 4) {
            context.push(AppRouter.settingsPath);
            return;
          }
          setState(() => _selectedIndex = index);
        },
      ),
    );
  }
}

// ─── Pinned floating nav bar ─────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selectedIndex, required this.onTap});

  final int selectedIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    _NavItemData(icon: Icons.home_rounded, label: 'Home'),
    _NavItemData(icon: Icons.bar_chart_rounded, label: 'Analytics'),
    _NavItemData(icon: Icons.add_circle_rounded, label: 'Add', isAdd: true),
    _NavItemData(icon: Icons.receipt_long_rounded, label: 'History'),
    _NavItemData(icon: Icons.settings_rounded, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const navBg = Color(0xFF0D1B2A);
    const navBgDark = Color(0xFF091422);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: isDark ? navBgDark : navBg,
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1565C0).withOpacity(0.30),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < _items.length; i++)
                _NavTile(
                  data: _items[i],
                  active: i == selectedIndex && !_items[i].isAdd,
                  onTap: () => onTap(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({required this.icon, required this.label, this.isAdd = false});
  final IconData icon;
  final String label;
  final bool isAdd;
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.data, required this.active, required this.onTap});

  final _NavItemData data;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFF64B5F6); // light-blue highlight
    final inactiveColor = Colors.white38;

    if (data.isAdd) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF1976D2),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1565C0).withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1565C0).withOpacity(0.30) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              data.icon,
              color: active ? activeColor : inactiveColor,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              data.label,
              style: TextStyle(
                color: active ? activeColor : inactiveColor,
                fontSize: 9,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
