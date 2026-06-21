import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../screens/seller/seller_home_screen.dart';
import '../screens/seller/seller_contact_requests_screen.dart';
import '../screens/seller/seller_notifications_screen.dart';
import '../screens/seller/premium_membership_screen.dart';
import '../screens/seller/add_land_screen.dart';

class SellerNavBar extends StatelessWidget {
  final int currentIndex;

  const SellerNavBar({
    super.key,
    required this.currentIndex,
  });
  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;

    switch (index) {
      case 0:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const SellerHomeScreen(),
          ),
        );
        break;

      case 1:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const SellerContactRequestsScreen(),
          ),
        );
        break;

      case 3:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const SellerPremiumScreen(),
          ),
        );
        break;

      case 4:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const SellerNotificationsScreen(),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: bottomInset + 10,
        ),
        child: SizedBox(
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _navItem(
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home_rounded,
                        selected: currentIndex == 0,
                        onTap: () => _onTap(context, 0),
                      ),
                    ),
                    Expanded(
                      child: _navItem(
                        icon: Icons.contact_phone_outlined,
                        activeIcon: Icons.contact_phone_rounded,
                        selected: currentIndex == 1,
                        onTap: () => _onTap(context, 1),
                      ),
                    ),
                    const SizedBox(width: 72),
                    Expanded(
                      child: _navItem(
                        icon: Icons.workspace_premium_outlined,
                        activeIcon: Icons.workspace_premium_rounded,
                        selected: currentIndex == 3,
                        onTap: () => _onTap(context, 3),
                      ),
                    ),
                    Expanded(
                      child: _navItem(
                        icon: Icons.notifications_outlined,
                        activeIcon: Icons.notifications_rounded,
                        selected: currentIndex == 4,
                        onTap: () => _onTap(context, 4),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: -6,
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AddLandScreen(),
                      ),
                    );
                  },
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required IconData activeIcon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Icon(
          selected ? activeIcon : icon,
          color: selected ? AppTheme.primary : AppTheme.textMuted,
          size: 26,
        ),
      ),
    );
  }
}
