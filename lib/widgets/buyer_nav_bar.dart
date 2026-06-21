import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../screens/buyer/buyer_home_screen.dart';
import '../screens/buyer/favorites_screen.dart';
import '../screens/buyer/notifications_screen.dart';
import '../screens/provider/providers_list_screen.dart';
// إضافة استدعاء شاشة الـ Premium
import '../screens/buyer/premium_pins_screen.dart';

/// Shared floating nav bar for all buyer screens.
/// [currentIndex]: 0=Favorites, 1=Premium, 2=Browse(Center), 3=Providers, 4=Notifications
class BuyerNavBar extends StatelessWidget {
  final int currentIndex;
  final int unreadCount;

  const BuyerNavBar({
    super.key,
    required this.currentIndex,
    this.unreadCount = 0,
  });

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;

    switch (index) {
      case 0:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const FavoritesScreen()),
        );
        break;
      case 1:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PremiumPinsScreen()),
        );
        break;
      case 2:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const BuyerHomeScreen()),
        );
        break;
      case 3:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ProvidersListScreen()),
        );
        break;
      case 4:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(
        bottom: bottomInset + 16, // تم رفعها قليلاً لإعطاء مساحة للزر البارز
        left: 20, // تم تقليل الـ padding الجانبي ليتسع لـ 5 أزرار براحة
        right: 20,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // 1. الخلفية البيضاء (Pill Shape)
          Container(
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _navItem(context, 0, Icons.favorite_outline,
                    Icons.favorite), // المفضلة
                _navItem(context, 1, Icons.workspace_premium_outlined,
                    Icons.workspace_premium), // المميزة

                // مساحة فارغة في المنتصف ليجلس فوقها الزر البارز
                const SizedBox(width: 56),

                _navItem(context, 3, Icons.engineering_outlined,
                    Icons.engineering), // المزودين

                // الإشعارات (مع الـ Badge)
                GestureDetector(
                  onTap: () => _onTap(context, 4),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: currentIndex == 4
                        ? BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          )
                        : const BoxDecoration(color: Colors.transparent),
                    child: Center(
                      child: NotificationBadge(
                        count: unreadCount,
                        child: Icon(
                          currentIndex == 4
                              ? Icons.notifications
                              : Icons.notifications_outlined,
                          color: currentIndex == 4
                              ? AppTheme.primary
                              : AppTheme.textMuted,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. الزر الأوسط البارز (Browse / Home)
          Positioned(
            top: -24, // بروز الزر خارج الإطار الأبيض للأعلى
            child: GestureDetector(
              onTap: () => _onTap(context, 2),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.primary, // اللون الأزرق الأساسي
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    // يمكنك تغيير الأيقونة هنا إلى Icons.home_rounded أو أي أيقونة تفضلها
                    Icons.explore_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(
      BuildContext context, int index, IconData icon, IconData activeIcon) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => _onTap(context, index),
      child: Container(
        width: 48,
        height: 48,
        decoration: isSelected
            ? BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              )
            : const BoxDecoration(
                color: Colors.transparent), // مهم للحفاظ على مساحة النقر
        child: Center(
          child: Icon(
            isSelected ? activeIcon : icon,
            color: isSelected ? AppTheme.primary : AppTheme.textMuted,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class NotificationBadge extends StatelessWidget {
  final int count;
  final Widget child;
  const NotificationBadge(
      {super.key, required this.count, required this.child});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -4,
          top: -4,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
