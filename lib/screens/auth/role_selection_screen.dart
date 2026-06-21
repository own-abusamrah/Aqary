import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../buyer/buyer_home_screen.dart';
import '../seller/seller_home_screen.dart';
import '../provider/provider_profile_screen.dart';
import '../admin/admin_dashboard_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  void _navigate(BuildContext context, String role) {
    Widget screen;
    switch (role) {
      case 'buyer':
        screen = const BuyerHomeScreen();
        break;
      case 'seller':
        screen = const SellerHomeScreen();
        break;
      case 'provider':
        screen = const ProviderProfileScreen(isEditing: false);
        break;
      case 'admin':
        screen = const AdminDashboardScreen();
        break;
      default:
        return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text(
                'Choose Your Role',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'How will you use Aqary?',
                style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _RoleCard(
                      icon: Icons.search_rounded,
                      label: 'Buyer',
                      description: 'Browse & find land',
                      color: const Color(0xFF3B82F6),
                      onTap: () => _navigate(context, 'buyer'),
                    ),
                    _RoleCard(
                      icon: Icons.sell_rounded,
                      label: 'Seller',
                      description: 'List your land',
                      color: const Color(0xFF10B981),
                      onTap: () => _navigate(context, 'seller'),
                    ),
                    _RoleCard(
                      icon: Icons.engineering_rounded,
                      label: 'Provider',
                      description: 'Offer your services',
                      color: const Color(0xFFF59E0B),
                      onTap: () => _navigate(context, 'provider'),
                    ),
                    _RoleCard(
                      icon: Icons.admin_panel_settings_rounded,
                      label: 'Admin',
                      description: 'Manage the platform',
                      color: const Color(0xFF8B5CF6),
                      onTap: () => _navigate(context, 'admin'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
