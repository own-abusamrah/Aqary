import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchController = TextEditingController();
  String _roleFilter = 'All';
  String _searchQuery = '';
  List<AppUser> _users = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final users = await AdminService.instance.getUsers(
        role: _roleFilter == 'All' ? null : _roleFilter,
      );
      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load users: ${e.toString().replaceAll("Exception: ", "")}';
        });
      }
    }
  }

  List<AppUser> get _filtered => _users.where((u) {
        final q = _searchQuery.toLowerCase();
        return q.isEmpty ||
            u.name.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q) ||
            u.phone.contains(q);
      }).toList();

  Future<void> _toggleBlock(AppUser user) async {
    final isBlocked = user.isBlocked;
    final action = isBlocked ? 'Unblock' : 'Block';
    final displayName = user.name.isNotEmpty ? user.name : user.email;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action User?'),
        content: Text(
          isBlocked
              ? 'Unblocking "$displayName" will restore their access.'
              : 'Blocking "$displayName" will prevent them from logging in and revoke their current session.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              action,
              style: TextStyle(
                color: isBlocked ? AppTheme.success : AppTheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    _updateUserInList(
      user.uid,
      (u) => AppUser(
        uid: u.uid,
        name: u.name,
        email: u.email,
        phone: u.phone,
        role: u.role,
        isBlocked: !isBlocked,
        subscriptionPlan: u.subscriptionPlan,
        subscriptionStatus: u.subscriptionStatus,
        subscriptionRequestedAt: u.subscriptionRequestedAt,
        subscriptionApprovedAt: u.subscriptionApprovedAt,
        subscriptionApprovedBy: u.subscriptionApprovedBy,
        subscriptionRejectReason: u.subscriptionRejectReason,
      ),
    );

    try {
      if (isBlocked) {
        await AdminService.instance.unblockUser(user.uid);
      } else {
        await AdminService.instance.blockUser(user.uid);
      }
      if (mounted) {
        _showSuccess(
          isBlocked
              ? '"$displayName" has been unblocked.'
              : '"$displayName" has been blocked.',
        );
      }
    } catch (e) {
      _updateUserInList(
        user.uid,
        (u) => AppUser(
          uid: u.uid,
          name: u.name,
          email: u.email,
          phone: u.phone,
          role: u.role,
          isBlocked: isBlocked,
          subscriptionPlan: u.subscriptionPlan,
          subscriptionStatus: u.subscriptionStatus,
          subscriptionRequestedAt: u.subscriptionRequestedAt,
          subscriptionApprovedAt: u.subscriptionApprovedAt,
          subscriptionApprovedBy: u.subscriptionApprovedBy,
          subscriptionRejectReason: u.subscriptionRejectReason,
        ),
      );
      if (mounted) _showError('Failed to $action user: $e');
    }
  }

  Future<void> _deleteUser(AppUser user) async {
    final displayName = user.name.isNotEmpty ? user.name : user.email;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Permanently delete account for "$displayName"?'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'User must have no active listings. This action cannot be undone.',
                      style: TextStyle(fontSize: 12, color: AppTheme.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final removed = _users.firstWhere((u) => u.uid == user.uid);
    setState(() => _users.removeWhere((u) => u.uid == user.uid));

    try {
      await AdminService.instance.deleteUser(user.uid);
      if (mounted) _showSuccess('"$displayName" has been deleted.');
    } catch (e) {
      setState(() => _users.insert(0, removed));
      if (mounted) {
        _showError('Failed to delete user: ${e.toString().replaceAll("Exception: ", "")}');
      }
    }
  }

  Future<void> _viewUserDetail(AppUser user) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _UserDetailSheet(
        user: user,
        onBlock: () {
          Navigator.pop(context);
          _toggleBlock(user);
        },
        onDelete: () {
          Navigator.pop(context);
          _deleteUser(user);
        },
      ),
    );
  }

  void _updateUserInList(String uid, AppUser Function(AppUser) transform) {
    setState(() {
      final idx = _users.indexWhere((u) => u.uid == uid);
      if (idx != -1) _users[idx] = transform(_users[idx]);
    });
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.success),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadUsers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search name, email or phone...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: ['All', 'buyer', 'seller', 'provider', 'admin'].map((role) {
                final sel = _roleFilter == role;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _roleFilter = role);
                      _loadUsers();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? AppTheme.primary : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel ? AppTheme.primary : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Text(
                        role[0].toUpperCase() + role.substring(1),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                          color: sel ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Text(
                  _isLoading
                      ? 'Loading...'
                      : '${_filtered.length} user${_filtered.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadUsers, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: AppTheme.textMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No users match "$_searchQuery"'
                  : 'No ${_roleFilter == "All" ? "" : _roleFilter} users found',
              style: const TextStyle(fontSize: 16, color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filtered.length,
        itemBuilder: (context, i) => _UserCard(
          user: _filtered[i],
          onTap: () => _viewUserDetail(_filtered[i]),
          onBlock: () => _toggleBlock(_filtered[i]),
          onDelete: () => _deleteUser(_filtered[i]),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final AppUser user;
  final VoidCallback onTap;
  final VoidCallback onBlock;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.onTap,
    required this.onBlock,
    required this.onDelete,
  });

  Color get _roleColor => switch (user.role) {
        'seller' => const Color(0xFF10B981),
        'provider' => const Color(0xFFF59E0B),
        'admin' => const Color(0xFF8B5CF6),
        _ => const Color(0xFF3B82F6),
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: user.isBlocked ? AppTheme.error.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: user.isBlocked
                ? AppTheme.error.withValues(alpha: 0.2)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _roleColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _roleColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.name.isNotEmpty ? user.name : '-',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ),
                      _Badge(
                        label: user.role,
                        color: _roleColor,
                      ),
                      const SizedBox(width: 6),
                      _Badge(
                        label: user.isPremiumActive ? 'PREMIUM' : 'FREE',
                        color: user.isPremiumActive ? AppTheme.success : AppTheme.textMuted,
                      ),
                    ],
                  ),
                  if (user.email.isNotEmpty)
                    Text(
                      user.email,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  if (user.phone.isNotEmpty)
                    Text(
                      user.phone,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  if (user.isBlocked)
                    const Text(
                      'BLOCKED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.error,
                      ),
                    ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textMuted),
              onSelected: (v) {
                if (v == 'block') onBlock();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(
                        user.isBlocked ? Icons.check_circle_outline : Icons.block_outlined,
                        color: user.isBlocked ? AppTheme.success : AppTheme.error,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(user.isBlocked ? 'Unblock' : 'Block'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: AppTheme.error, size: 18),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UserDetailSheet extends StatelessWidget {
  final AppUser user;
  final VoidCallback onBlock;
  final VoidCallback onDelete;

  const _UserDetailSheet({
    required this.user,
    required this.onBlock,
    required this.onDelete,
  });

  Color get _roleColor => switch (user.role) {
        'seller' => const Color(0xFF10B981),
        'provider' => const Color(0xFFF59E0B),
        'admin' => const Color(0xFF8B5CF6),
        _ => const Color(0xFF3B82F6),
      };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _roleColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _roleColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              user.name.isNotEmpty ? user.name : '-',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                _Badge(label: user.role.toUpperCase(), color: _roleColor),
                _Badge(
                  label: user.isPremiumActive ? 'PREMIUM' : 'FREE',
                  color: user.isPremiumActive ? AppTheme.success : AppTheme.textMuted,
                ),
                if (user.isBlocked)
                  const _Badge(label: 'BLOCKED', color: AppTheme.error),
              ],
            ),
            const SizedBox(height: 20),
            _DetailRow(Icons.email_outlined, 'Email', user.email.isNotEmpty ? user.email : '-'),
            _DetailRow(Icons.phone_outlined, 'Phone', user.phone.isNotEmpty ? user.phone : '-'),
            _DetailRow(Icons.fingerprint_rounded, 'UID', user.uid),
            _DetailRow(
              Icons.workspace_premium_outlined,
              'Premium Status',
              user.subscriptionStatus,
            ),
            if (user.subscriptionStatus == 'rejected' &&
                (user.subscriptionRejectReason?.isNotEmpty ?? false))
              _DetailRow(
                Icons.info_outline,
                'Reject Reason',
                user.subscriptionRejectReason!,
              ),
            if (user.subscriptionStatus == 'disabled' &&
                (user.subscriptionDisableReason?.isNotEmpty ?? false))
              _DetailRow(
                Icons.pause_circle_outline,
                'Disable Reason',
                user.subscriptionDisableReason!,
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onBlock,
                    icon: Icon(
                      user.isBlocked ? Icons.check_circle_outline : Icons.block_outlined,
                      size: 18,
                    ),
                    label: Text(user.isBlocked ? 'Unblock' : 'Block'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: user.isBlocked ? AppTheme.success : AppTheme.error,
                      side: BorderSide(
                        color: user.isBlocked ? AppTheme.success : AppTheme.error,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: const BorderSide(color: AppTheme.error),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textDark,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
