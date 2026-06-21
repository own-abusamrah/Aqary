import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../utils/app_theme.dart';
import '../../widgets/seller_nav_bar.dart';

class SellerPremiumScreen extends StatelessWidget {
  const SellerPremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('Premium Seller'),
      ),
      body: StreamBuilder<AppUser?>(
        stream: PremiumService.instance.watchCurrentUser(),
        builder: (context, snapshot) {
          final user = snapshot.data;

          return ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(context).padding.bottom,
            ),
            children: [
              _premiumHeader(),
              const SizedBox(height: 20),
              if (user != null) _buildStatusSection(context, user),
              const SizedBox(height: 20),
              _benefitsCard(),
              const SizedBox(height: 20),
              _paymentCard(context),
              const SizedBox(height: 30),
            ],
          );
        },
      ),
      bottomNavigationBar: const SellerNavBar(
        currentIndex: 3,
      ),
    );
  }

  Widget _premiumHeader() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFE082),
            Color(0xFFFFC107),
            Color(0xFFFFA000),
          ],
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            color: Colors.white,
            size: 54,
          ),
          SizedBox(height: 12),
          Text(
            'Premium Seller',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '7 JD',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection(BuildContext context, AppUser user) {
    switch (user.subscriptionStatus) {
      case 'pending':
        return _statusCard(
          color: Colors.orange,
          icon: Icons.hourglass_top_rounded,
          title: 'Request Under Review',
          message:
              'Your premium request is currently being reviewed by the Aqary team.',
        );

      case 'active':
        return _statusCard(
          color: AppTheme.success,
          icon: Icons.verified_rounded,
          title: 'Premium Active',
          message:
              'Your premium seller subscription is active and all premium features are enabled.',
        );

      case 'rejected':
        return Column(
          children: [
            _statusCard(
              color: AppTheme.error,
              icon: Icons.cancel_rounded,
              title: 'Request Rejected',
              message: user.subscriptionRejectReason ??
                  'Your premium request was rejected.',
            ),
            const SizedBox(height: 12),
            _requestButton(),
          ],
        );

      case 'disabled':
        return Column(
          children: [
            _statusCard(
              color: AppTheme.textMuted,
              icon: Icons.block_rounded,
              title: 'Premium Disabled',
              message: user.subscriptionDisableReason ??
                  'Your premium subscription has been disabled.',
            ),
            const SizedBox(height: 12),
            _requestButton(
              text: 'Request Again',
              icon: Icons.refresh_rounded,
            ),
          ],
        );

      default:
        return _requestButton();
    }
  }

  Widget _requestButton({
    String text = 'Request Premium Subscription',
    IconData icon = Icons.workspace_premium_outlined,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          await PremiumService.instance.requestPremiumSubscription();
        },
        icon: Icon(icon),
        label: Text(text),
      ),
    );
  }

  Widget _benefitsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Premium Benefits',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 14),
          _BenefitItem(
            icon: Icons.campaign_rounded,
            text: 'Send broadcasts to nearby buyers.',
          ),
          _BenefitItem(
            icon: Icons.visibility_rounded,
            text: 'Increase exposure for your listings.',
          ),
          _BenefitItem(
            icon: Icons.speed_rounded,
            text: 'Help your land reach interested buyers faster.',
          ),
          _BenefitItem(
            icon: Icons.location_on_rounded,
            text: 'Target buyers near your land location.',
          ),
        ],
      ),
    );
  }

  Widget _paymentCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Instructions',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          _copyTile(
            context,
            title: 'Zain Cash',
            value: '0797177248',
          ),
          const SizedBox(height: 12),
          _copyTile(
            context,
            title: 'CliQ Username',
            value: '@ownraid',
          ),
          const SizedBox(height: 18),
          const Text(
            'After completing the payment, submit your premium request and wait for approval.',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _copyTile(
    BuildContext context, {
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppTheme.background,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: value),
              );

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$value copied'),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
    );
  }

  Widget _statusCard({
    required Color color,
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
