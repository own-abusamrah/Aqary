import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../services/services.dart';
import '../buyer/notifications_screen.dart' show AppNotification;
import 'admin_premium_requests_screen.dart';

class AdminInboxScreen extends StatefulWidget {
  const AdminInboxScreen({super.key});

  @override
  State<AdminInboxScreen> createState() => _AdminInboxScreenState();
}

class _AdminInboxScreenState extends State<AdminInboxScreen> {
  String? get _uid => Firebase.auth.currentUser?.uid;

  Future<void> _onNotificationTap(AppNotification n) async {
    // Mark as read (best-effort)
    try {
      await NotificationService.instance.markAsRead(n.id);
    } catch (e) {
      debugPrint('markAsRead failed: $e');
    }

    if (!mounted) return;

    switch (n.type) {
      case 'premium_request':
        // Navigate to premium requests screen and show pending tab
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AdminPremiumRequestsScreen()),
        );
        break;

      case 'subscription_update':
        // Also relevant to premium — open premium requests
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AdminPremiumRequestsScreen()),
        );
        break;

      default:
        // broadcast / other types — no deep navigation needed
        break;
    }
  }

  IconData _iconForType(String type) => switch (type) {
        'premium_request' => Icons.workspace_premium_rounded,
        'subscription_update' => Icons.verified_rounded,
        'broadcast' => Icons.campaign_rounded,
        _ => Icons.notifications_outlined,
      };

  Color _colorForType(String type) => switch (type) {
        'premium_request' => const Color(0xFF8B5CF6),
        'subscription_update' => AppTheme.success,
        'broadcast' => const Color(0xFFF59E0B),
        _ => AppTheme.primary,
      };

  String _labelForType(String type) => switch (type) {
        'premium_request' => 'Premium Request',
        'subscription_update' => 'Subscription Update',
        'broadcast' => 'Broadcast',
        _ => 'Notification',
      };

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        actions: [
          TextButton.icon(
            onPressed: () => NotificationService.instance.markAllAsRead(_uid!),
            icon: const Icon(Icons.done_all_rounded,
                color: Colors.white, size: 16),
            label: const Text('Mark all read',
                style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Delete all',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete all notifications?'),
                  content: const Text(
                      'This will permanently remove all inbox notifications.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete',
                            style: TextStyle(color: AppTheme.error))),
                  ],
                ),
              );
              if (confirmed == true && _uid != null) {
                await NotificationService.instance
                    .deleteAllNotifications(_uid!);
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: NotificationService.instance.watchNotifications(_uid!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: AppTheme.error, fontSize: 14)),
              ),
            );
          }

          // Exclude senderCopy broadcasts (those belong to the broadcast history page)
          final notifications = (snapshot.data ?? [])
              .where((n) => !(n.type == 'broadcast' && n.senderCopy))
              .toList();

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.07),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.inbox_outlined,
                        size: 56,
                        color: AppTheme.primary.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 24),
                  const Text('No notifications yet',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark)),
                  const SizedBox(height: 8),
                  const Text(
                      'Premium requests & system alerts will appear here.',
                      style:
                          TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final n = notifications[index];
              final typeColor = _colorForType(n.type);

              return Dismissible(
                key: ValueKey(n.id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) =>
                    NotificationService.instance.deleteNotification(n.id),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.error,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                child: GestureDetector(
                  onTap: () => _onNotificationTap(n),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: n.isRead
                          ? Colors.white
                          : typeColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: n.isRead
                            ? const Color(0xFFE5E7EB)
                            : typeColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon bubble
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_iconForType(n.type),
                              color: typeColor, size: 22),
                        ),
                        const SizedBox(width: 12),

                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Type chip
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: typeColor.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _labelForType(n.type),
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: typeColor),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(_timeAgo(n.createdAt),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textMuted)),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 18, color: AppTheme.textMuted),
                                    tooltip: 'Delete',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => NotificationService
                                        .instance
                                        .deleteNotification(n.id),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                n.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: n.isRead
                                      ? FontWeight.w500
                                      : FontWeight.bold,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                n.body,
                                style: const TextStyle(
                                    fontSize: 13, color: AppTheme.textMuted),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),

                              // Action hint for premium requests
                              if (n.type == 'premium_request' ||
                                  n.type == 'subscription_update') ...[
                                const SizedBox(height: 6),
                                Row(children: [
                                  Text(
                                    n.type == 'premium_request'
                                        ? 'Tap to review request →'
                                        : 'Tap to view subscriptions →',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: typeColor,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ]),
                              ],
                            ],
                          ),
                        ),

                        // Unread dot
                        if (!n.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8, top: 4),
                            decoration: BoxDecoration(
                                color: typeColor, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
