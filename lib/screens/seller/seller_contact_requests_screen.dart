//import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/seller_nav_bar.dart';

class SellerContactRequestsScreen extends StatefulWidget {
  const SellerContactRequestsScreen({super.key});
  @override
  State<SellerContactRequestsScreen> createState() =>
      _SellerContactRequestsScreenState();
}

class _SellerContactRequestsScreenState
    extends State<SellerContactRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? get _uid => Firebase.auth.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('Contact Requests'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      body: StreamBuilder<List<ContactRequest>>(
        stream: ContactRequestService.instance.watchAllSellerRequests(_uid!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final all = snapshot.data ?? [];
          final pending = all.where((r) => r.status == 'pending').toList();
          final approved = all.where((r) => r.status == 'approved').toList();
          final rejected = all.where((r) => r.status == 'rejected').toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _RequestList(
                  requests: pending, emptyLabel: 'No pending requests'),
              _RequestList(
                  requests: approved, emptyLabel: 'No approved requests'),
              _RequestList(
                  requests: rejected, emptyLabel: 'No rejected requests'),
            ],
          );
        },
      ),
      bottomNavigationBar: const SellerNavBar(
        currentIndex: 1,
      ),
    );
  }
}

// ─── Request list ─────────────────────────────────────────────────────────────

class _RequestList extends StatelessWidget {
  final List<ContactRequest> requests;
  final String emptyLabel;
  const _RequestList({required this.requests, required this.emptyLabel});

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined,
              size: 64, color: AppTheme.textMuted.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(emptyLabel,
              style: const TextStyle(fontSize: 16, color: AppTheme.textMuted)),
        ],
      ));
    }
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(context).padding.bottom,
            ),
        itemCount: requests.length,
        itemBuilder: (context, i) => _RequestCard(request: requests[i]),
      ),
    );
  }
}

// ─── Request card ─────────────────────────────────────────────────────────────

class _RequestCard extends StatefulWidget {
  final ContactRequest request;
  const _RequestCard({required this.request});
  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  Map<String, String>? _buyerInfo;
  Map<String, String>? _listingInfo;
  bool _isActing = false;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final buyer = await ContactRequestService.instance
        .getBuyerInfo(widget.request.buyerId);
    final listing = await ContactRequestService.instance
        .getListingInfo(widget.request.listingId);
    if (mounted)
      setState(() {
        _buyerInfo = buyer;
        _listingInfo = listing;
      });
  }

  Future<void> _approve() async {
    final confirm = await _confirmDialog(
      title: 'Approve Request?',
      content: 'The buyer will receive your contact information and '
          'be notified that their request was approved.',
      actionLabel: 'Approve',
      actionColor: AppTheme.success,
    );
    if (confirm != true) return;
    setState(() => _isActing = true);
    try {
      await ContactRequestService.instance.approveRequest(widget.request.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Request approved — buyer has been notified.'),
            backgroundColor: AppTheme.success));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed: $e'), backgroundColor: AppTheme.error));
      }
    }
  }

  Future<void> _reject() async {
    final confirm = await _confirmDialog(
      title: 'Reject Request?',
      content: 'The buyer will be notified that their request was declined. '
          'Your contact information will remain hidden.',
      actionLabel: 'Reject',
      actionColor: AppTheme.error,
    );
    if (confirm != true) return;
    setState(() => _isActing = true);
    try {
      await ContactRequestService.instance.rejectRequest(widget.request.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Request rejected — buyer has been notified.'),
            backgroundColor: AppTheme.accent));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed: $e'), backgroundColor: AppTheme.error));
      }
    }
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String content,
    required String actionLabel,
    required Color actionColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(actionLabel,
                  style: TextStyle(
                      color: actionColor, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Color get _statusColor => switch (widget.request.status) {
        'approved' => AppTheme.success,
        'rejected' => AppTheme.error,
        _ => AppTheme.accent,
      };

  IconData get _statusIcon => switch (widget.request.status) {
        'approved' => Icons.check_circle_outline,
        'rejected' => Icons.cancel_outlined,
        _ => Icons.hourglass_top_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final isPending = widget.request.status == 'pending';
    final name = _buyerInfo?['name'] ?? '';

    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending
              ? AppTheme.accent.withValues(alpha: 0.4)
              : const Color(0xFFE5E7EB),
          width: isPending ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header: status badge + timestamp ─────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16))),
          child: Row(children: [
            Icon(_statusIcon, color: _statusColor, size: 16),
            const SizedBox(width: 6),
            Text(widget.request.status.toUpperCase(),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _statusColor)),
            const Spacer(),
            Text(_timeAgo(widget.request.createdAt),
                style:
                    const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Buyer info ──────────────────────────────────────────────
            Row(children: [
              Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle),
                  child: Center(
                      child: Text(
                          // (_buyerInfo?['name'] ?? '?').isNotEmpty
                          //     ? (_buyerInfo!['name']![0]).toUpperCase()
                          //     : '?',
                          initial,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary)))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        //_buyerInfo == null ? 'Loading...' : (_buyerInfo!['name']!.isNotEmpty ? _buyerInfo!['name']! : 'Unknown buyer'),
                        name.isEmpty ? 'Loading...' : name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark)),
                    // if (_buyerInfo?['phone']?.isNotEmpty == true)
                    //   Text('+962 ${_buyerInfo!['phone']}',
                    if ((_buyerInfo?['phone'] ?? '').isNotEmpty)
                      Text('+962 ${_buyerInfo?['phone']}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textMuted)),
                    // if (_buyerInfo?['email']?.isNotEmpty == true)
                    //   Text(_buyerInfo!['email']!,
                    if ((_buyerInfo?['email'] ?? '').isNotEmpty)
                      Text(_buyerInfo!['email']!,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textMuted)),
                  ])),
            ]),
            const SizedBox(height: 12),

            // ── Listing info ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.location_on_outlined,
                    size: 16, color: AppTheme.textMuted),
                const SizedBox(width: 8),
                Expanded(
                    child: _listingInfo == null
                        ? const Text('Loading listing...',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textMuted))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text(_listingInfo!['title'] ?? '',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textDark)),
                                if ((_listingInfo!['area'] ?? '').isNotEmpty)
                                  Text(
                                      '${_listingInfo!['area']} · ${_listingInfo!['size']}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textMuted)),
                              ])),
              ]),
            ),

            // ── Approve / Reject buttons (pending only) ─────────────────
            if (isPending) ...[
              const SizedBox(height: 16),
              _isActing
                  ? const Center(child: CircularProgressIndicator())
                  : Row(children: [
                      Expanded(
                          child: OutlinedButton.icon(
                        onPressed: _reject,
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.error,
                            side: const BorderSide(color: AppTheme.error),
                            padding: const EdgeInsets.symmetric(vertical: 10)),
                      )),
                      const SizedBox(width: 12),
                      Expanded(
                          child: ElevatedButton.icon(
                        onPressed: _approve,
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10)),
                      )),
                    ]),
            ],

            // ── Approved: show that contact info is now visible ─────────
            if (widget.request.status == 'approved') ...[
              const SizedBox(height: 12),
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.success.withValues(alpha: 0.3))),
                  child: const Row(children: [
                    Icon(Icons.visibility_outlined,
                        color: AppTheme.success, size: 14),
                    SizedBox(width: 6),
                    Text('Your contact info is visible to this buyer.',
                        style:
                            TextStyle(fontSize: 12, color: AppTheme.success)),
                  ])),
            ],

            // ── Rejected: show that contact info remains hidden ─────────
            if (widget.request.status == 'rejected') ...[
              const SizedBox(height: 12),
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.error.withValues(alpha: 0.2))),
                  child: const Row(children: [
                    Icon(Icons.visibility_off_outlined,
                        color: AppTheme.error, size: 14),
                    SizedBox(width: 6),
                    Text('Your contact info remains hidden.',
                        style: TextStyle(fontSize: 12, color: AppTheme.error)),
                  ])),
            ],
          ]),
        ),
      ]),
    );
  }
}
