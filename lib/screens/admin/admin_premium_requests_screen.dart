import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../utils/app_theme.dart';

class AdminPremiumRequestsScreen extends StatefulWidget {
  const AdminPremiumRequestsScreen({super.key});

  @override
  State<AdminPremiumRequestsScreen> createState() => _AdminPremiumRequestsScreenState();
}

class _AdminPremiumRequestsScreenState extends State<AdminPremiumRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<AppUser> _users = [];

  final Map<String, String> _statusLabels = const {
    'pending': 'Requested',
    'active': 'Approved',
    'rejected': 'Rejected',
    'disabled': 'Disabled',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final users = await PremiumService.instance.getPremiumRequests(
        statuses: const ['pending', 'active', 'rejected', 'disabled'],
      );
      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _act(AppUser user, String action) async {
    String? reason;
    if (action == 'reject' || action == 'disable') {
      reason = await _promptReason(
        title: action == 'reject'
            ? 'Reject Premium Request'
            : 'Disable Premium Subscription',
        label: action == 'reject' ? 'Reject reason' : 'Disable reason',
        actionLabel: action == 'reject' ? 'Reject' : 'Disable',
      );
      if (reason == null) return;
    }

    await PremiumService.instance.adminSetPremiumSubscription(
      targetUid: user.uid,
      action: action,
      reason: reason,
    );
    await _load();
  }

  Future<String?> _promptReason({
    required String title,
    required String label,
    required String actionLabel,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: label,
            hintText: 'Optional message visible to the requester',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final pending = _users.where((u) => u.subscriptionStatus == 'pending').toList();
    final approved = _users.where((u) => u.subscriptionStatus == 'active').toList();
    final rejected = _users.where((u) => u.subscriptionStatus == 'rejected').toList();
    final disabled = _users.where((u) => u.subscriptionStatus == 'disabled').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium Requests'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Requested'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
            Tab(text: 'Disabled'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _PremiumRequestList(
                  users: pending,
                  emptyLabel: 'No requested premium requests',
                  onAction: _act,
                  statusLabels: _statusLabels,
                ),
                _PremiumRequestList(
                  users: approved,
                  emptyLabel: 'No approved premium requests',
                  onAction: _act,
                  statusLabels: _statusLabels,
                ),
                _PremiumRequestList(
                  users: rejected,
                  emptyLabel: 'No rejected premium requests',
                  onAction: _act,
                  statusLabels: _statusLabels,
                ),
                _PremiumRequestList(
                  users: disabled,
                  emptyLabel: 'No disabled premium subscriptions',
                  onAction: _act,
                  statusLabels: _statusLabels,
                ),
              ],
            ),
    );
  }
}

class _PremiumRequestList extends StatelessWidget {
  final List<AppUser> users;
  final String emptyLabel;
  final Future<void> Function(AppUser user, String action) onAction;
  final Map<String, String> statusLabels;

  const _PremiumRequestList({
    required this.users,
    required this.emptyLabel,
    required this.onAction,
    required this.statusLabels,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: AppTheme.textMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(emptyLabel, style: const TextStyle(fontSize: 16, color: AppTheme.textMuted)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (context, index) => _PremiumRequestCard(
        user: users[index],
        onAction: onAction,
        statusLabels: statusLabels,
      ),
    );
  }
}

class _PremiumRequestCard extends StatelessWidget {
  final AppUser user;
  final Future<void> Function(AppUser user, String action) onAction;
  final Map<String, String> statusLabels;

  const _PremiumRequestCard({
    required this.user,
    required this.onAction,
    required this.statusLabels,
  });

  Color get _statusColor => switch (user.subscriptionStatus) {
        'active' => AppTheme.success,
        'rejected' => AppTheme.error,
        'disabled' => AppTheme.textMuted,
        _ => AppTheme.accent,
      };

  IconData get _statusIcon => switch (user.subscriptionStatus) {
        'active' => Icons.check_circle_outline,
        'rejected' => Icons.cancel_outlined,
        'disabled' => Icons.pause_circle_outline,
        _ => Icons.hourglass_top_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: user.subscriptionStatus == 'pending'
              ? AppTheme.accent.withValues(alpha: 0.4)
              : const Color(0xFFE5E7EB),
          width: user.subscriptionStatus == 'pending' ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(_statusIcon, color: _statusColor, size: 16),
                const SizedBox(width: 6),
                Text(
                  statusLabels[user.subscriptionStatus]!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _statusColor,
                  ),
                ),
                const Spacer(),
                Text(
                  user.role.toUpperCase(),
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name.isEmpty ? user.email : user.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.phone.isNotEmpty ? user.phone : user.email,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                if ((user.subscriptionStatus == 'rejected' &&
                        (user.subscriptionRejectReason?.isNotEmpty ?? false)) ||
                    (user.subscriptionStatus == 'disabled' &&
                        (user.subscriptionDisableReason?.isNotEmpty ?? false))) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.error.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      user.subscriptionStatus == 'disabled'
                          ? (user.subscriptionDisableReason ?? '')
                          : (user.subscriptionRejectReason ?? ''),
                      style: const TextStyle(fontSize: 12, color: AppTheme.error),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (user.subscriptionStatus == 'pending' ||
                        user.subscriptionStatus == 'active')
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => onAction(user, 'reject'),
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.error,
                            side: const BorderSide(color: AppTheme.error),
                          ),
                        ),
                      ),
                    if (user.subscriptionStatus == 'pending' ||
                        user.subscriptionStatus == 'active') const SizedBox(width: 12),
                    if (user.subscriptionStatus == 'pending' ||
                        user.subscriptionStatus == 'rejected')
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => onAction(user, 'approve'),
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    if (user.subscriptionStatus == 'active')
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => onAction(user, 'disable'),
                          icon: const Icon(Icons.block_outlined, size: 16),
                          label: const Text('Disable'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    if (user.subscriptionStatus == 'disabled')
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => onAction(user, 'reenable'),
                          icon: const Icon(Icons.restart_alt_rounded, size: 16),
                          label: const Text('Re-enable'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
