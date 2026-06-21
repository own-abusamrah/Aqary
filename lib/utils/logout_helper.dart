import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../services/services.dart';
import '../screens/auth/welcome_screen.dart';

/// Shows a confirmation dialog then logs the user out and clears the nav stack.
/// Call from any home screen's logout button.
Future<void> confirmAndLogout(BuildContext context) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Log Out?'),
      content: const Text('Are you sure you want to log out?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Log Out',
              style: TextStyle(
                  color: AppTheme.error, fontWeight: FontWeight.w600))),
      ],
    ),
  );

  if (confirm == true) {
    await AuthService.instance.logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }
}

/// Reusable badge widget used on notification/request icons across all screens.
class NotificationBadge extends StatelessWidget {
  final Widget child;
  final int count;

  const NotificationBadge({
    super.key,
    required this.child,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) return child;
    return Stack(children: [
      child,
      Positioned(
        right: 4,
        top: 4,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
              color: AppTheme.error, shape: BoxShape.circle),
          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
          child: Text(
            count > 99 ? '99+' : '$count',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ]);
  }
}
