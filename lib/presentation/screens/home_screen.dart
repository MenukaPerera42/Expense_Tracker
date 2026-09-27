import 'package:flutter/material.dart';

/// HomeScreen is now a thin pass-through.
/// The router's ShellRoute (_AppShell in app_router.dart) owns the
/// persistent bottom navigation bar. This widget is kept for clarity
/// but simply renders the SafeArea + DashboardView via the shell.
///
/// Note: The shell wraps ALL authenticated pages, so HomeScreen is
/// no longer needed as a navigation container. The router's _DashboardPage
/// handles the / route directly inside the shell.
/// This file is intentionally left minimal and can be removed in a later
/// clean-up pass if the router's inline _DashboardPage is preferred.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // This widget is not used by the router any more.
    // Kept to avoid breaking any test references.
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
