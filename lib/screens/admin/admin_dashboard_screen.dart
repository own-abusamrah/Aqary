//import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../utils/logout_helper.dart';
import '../../services/services.dart';
import 'admin_users_screen.dart';
import 'admin_listings_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_premium_requests_screen.dart';
import 'admin_inbox_screen.dart';
import '../buyer/notifications_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String? get _uid => Firebase.auth.currentUser?.uid;
  int _totalUsers = 0;
  int _totalListings = 0;
  int _totalProviders = 0;
  int _blockedUsers = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final db = Firebase.firestore;
      final results = await Future.wait([
        db.collection('users').count().get(),
        db
            .collection('listings')
            .where('status', isEqualTo: 'active')
            .count()
            .get(),
        db
            .collection('providers')
            .where('isHidden', isEqualTo: false)
            .count()
            .get(),
        db
            .collection('users')
            .where('isBlocked', isEqualTo: true)
            .count()
            .get(),
      ]);
      if (mounted) {
        setState(() {
          _totalUsers = results[0].count ?? 0;
          _totalListings = results[1].count ?? 0;
          _totalProviders = results[2].count ?? 0;
          _blockedUsers = results[3].count ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadStats,
            tooltip: 'Refresh stats',
          ),
          // Notifications with unread badge
          StreamBuilder<int>(
            stream: _uid != null
                ? NotificationService.instance.watchUnreadCount(_uid!)
                : const Stream.empty(),
            builder: (context, snapshot) {
              final unread = snapshot.data ?? 0;
              return NotificationBadge(
                count: unread,
                child: IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    tooltip: 'Notifications',
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const AdminInboxScreen()))),
              );
            },
          ),
          // Logout
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Log Out',
            onPressed: () => confirmAndLogout(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Stats ────────────────────────────────────────────────
            const Text('Overview',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark)),
            const SizedBox(height: 12),
            _isLoading
                ? const Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator()))
                : Column(children: [
                    Row(children: [
                      Expanded(
                          child: _StatCard(
                              label: 'Total Users',
                              value: '$_totalUsers',
                              icon: Icons.people_outline,
                              color: AppTheme.primary)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _StatCard(
                              label: 'Active Listings',
                              value: '$_totalListings',
                              icon: Icons.location_on_outlined,
                              color: const Color(0xFF10B981))),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: _StatCard(
                              label: 'Providers',
                              value: '$_totalProviders',
                              icon: Icons.engineering_outlined,
                              color: const Color(0xFFF59E0B))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _StatCard(
                              label: 'Blocked',
                              value: '$_blockedUsers',
                              icon: Icons.block_outlined,
                              color: AppTheme.error)),
                    ]),
                  ]),
            const SizedBox(height: 28),

            // ── Actions ───────────────────────────────────────────────
            const Text('Management',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark)),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.people_alt_rounded,
              title: 'Manage Users',
              subtitle: 'View, block, or delete accounts',
              color: AppTheme.primary,
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminUsersScreen())),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.location_on_rounded,
              title: 'Manage Listings',
              subtitle: 'Hide or remove inappropriate listings',
              color: const Color(0xFF10B981),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const AdminListingsScreen())),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.workspace_premium_rounded,
              title: 'Premium Requests',
              subtitle: 'Manage premium subscriptions',
              color: const Color(0xFF8B5CF6),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const AdminPremiumRequestsScreen())),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.campaign_rounded,
              title: 'Send Notifications',
              subtitle: 'Broadcast messages to all or specific users',
              color: const Color(0xFFF59E0B),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const AdminNotificationsScreen())),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(value,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark)),
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        ]));
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: onTap,
        child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8)
                ]),
            child: Row(children: [
              Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 24)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textMuted)),
                  ])),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textMuted),
            ])));
  }
}
