//import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../services/services.dart';
import '../buyer/notifications_screen.dart' show AppNotification;
import 'admin_dashboard_screen.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});
  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _targetRole = 'all';
  bool _isSending = false;
  String? _lastResult;

  String? get _uid => Firebase.auth.currentUser?.uid;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSending = true;
      _lastResult = null;
    });

    try {
      final result = await NotificationService.instance.sendBroadcast(
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        targetRole: _targetRole,
      );

      if (mounted) {
        setState(() {
          _isSending = false;
          _lastResult = 'Sent to ${result.sent} of ${result.total} users.';
          _titleController.clear();
          _bodyController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _lastResult = 'Failed: $e';
        });
      }
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _deleteAllBroadcasts() async {
    if (_uid == null) return;
    await NotificationService.instance.deleteNotificationsByType(
      userId: _uid!,
      types: const ['broadcast'],
      senderCopyOnly: true,
    );
  }

  String _audienceLabel(String? targetRole) {
    switch (targetRole) {
      case 'buyer':
        return 'Buyer';
      case 'seller':
        return 'Seller';
      case 'provider':
        return 'Provider';
      case 'admin':
        return 'Admin';
      default:
        return 'All';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacement(MaterialPageRoute(
                  builder: (_) => const AdminDashboardScreen()));
            }
          },
        ),
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        // ── Compose card ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)
              ]),
          child: Form(
              key: _formKey,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Compose Broadcast',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark)),
                    const SizedBox(height: 16),

                    // Target group
                    const Text('Send To',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMuted)),
                    const SizedBox(height: 8),
                    Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          {'label': 'All Users', 'value': 'all'},
                          {'label': 'Buyers Only', 'value': 'buyer'},
                          {'label': 'Sellers Only', 'value': 'seller'},
                          {'label': 'Providers Only', 'value': 'provider'},
                          {'label': 'Admins Only', 'value': 'admin'},
                        ].map((opt) {
                          final sel = _targetRole == opt['value'];
                          return GestureDetector(
                              onTap: () =>
                                  setState(() => _targetRole = opt['value']!),
                              child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                      color: sel
                                          ? AppTheme.primary
                                          : AppTheme.background,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: sel
                                              ? AppTheme.primary
                                              : const Color(0xFFE5E7EB))),
                                  child: Text(opt['label']!,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: sel
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: sel
                                              ? Colors.white
                                              : AppTheme.textMuted))));
                        }).toList()),
                    const SizedBox(height: 16),

                    // Title
                    TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                            labelText: 'Notification Title',
                            prefixIcon: Icon(Icons.title_rounded)),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Title is required'
                            : null),
                    const SizedBox(height: 12),

                    // Body
                    TextFormField(
                        controller: _bodyController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                            labelText: 'Message',
                            alignLabelWithHint: true,
                            prefixIcon: Padding(
                                padding: EdgeInsets.only(bottom: 40),
                                child: Icon(Icons.message_outlined)),
                            hintText: 'Write your message...'),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Message is required'
                            : null),
                    const SizedBox(height: 16),

                    ElevatedButton.icon(
                        onPressed: _isSending ? null : _send,
                        icon: _isSending
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded),
                        label:
                            Text(_isSending ? 'Sending...' : 'Send Broadcast')),

                    if (_lastResult != null) ...[
                      const SizedBox(height: 12),
                      Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: (_lastResult!.startsWith('Failed')
                                    ? AppTheme.error
                                    : AppTheme.success)
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(_lastResult!,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _lastResult!.startsWith('Failed')
                                      ? AppTheme.error
                                      : AppTheme.success))),
                    ],
                  ])),
        ),
        const SizedBox(height: 24),

        // ── Broadcast history from Firestore ──────────────────────────
        const Text('Sent History',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark)),
        const SizedBox(height: 12),
        if (_uid != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _deleteAllBroadcasts,
              child: const Text('Delete all history'),
            ),
          ),

        if (_uid != null)
          StreamBuilder<List<AppNotification>>(
              // Show admin's own broadcast notifications as history
              stream: NotificationService.instance.watchNotifications(_uid!),
              //stream: NotificationService.instance.watchAdminNotifications(_uid!),//'broadcast'),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator()));
                }
                //print("broadcasts: $snapshot.data");
                // Filter to broadcast type only
                final broadcasts = (snapshot.data ?? [])
                    .where((n) => n.type == 'broadcast' && n.senderCopy)
                    .toList();

                if (broadcasts.isEmpty) {
                  return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(12)),
                      child: const Center(
                          child: Text('No broadcasts sent yet.',
                              style: TextStyle(
                                  color: AppTheme.textMuted, fontSize: 13))));
                }

                return Column(
                    children: broadcasts
                        .map((n) => Dismissible(
                              key: ValueKey(n.id),
                              direction: DismissDirection.endToStart,
                              onDismissed: (_) => NotificationService.instance
                                  .deleteNotification(n.id),
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.error,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.delete_outline,
                                    color: Colors.white),
                              ),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: const Color(0xFFE5E7EB))),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Expanded(
                                            child: Text(n.title,
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.textDark))),
                                        Text(_timeAgo(n.createdAt),
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.textMuted)),
                                      ]),
                                      const SizedBox(height: 4),
                                      Text(n.body,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: AppTheme.textMuted),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primary
                                                  .withValues(alpha: 0.08),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Broadcast',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: AppTheme.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.accent
                                                  .withValues(alpha: 0.08),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              _audienceLabel(n.targetRole),
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: AppTheme.accent,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ]),
                              ),
                            ))
                        .toList());
              }),
      ]),
    );
  }
}
