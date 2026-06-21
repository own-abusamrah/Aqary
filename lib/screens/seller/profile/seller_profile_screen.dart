import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../premium_membership_screen.dart';
import 'seller_edit_profile_screen.dart';
import '../seller_hidden_listings_screen.dart';
import '../seller_contact_requests_screen.dart';
import '../seller_notifications_screen.dart';
import '../seller_broadcast_screen.dart';
import '../premium_membership_screen.dart';
import '../../auth/login_screen.dart';

class SellerProfileScreen extends StatelessWidget {
  const SellerProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: currentUser == null
          ? const Center(
              child: Text(
                'Please sign in first',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1E5670)),
                  );
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Error fetching data'),
                  );
                }

                String userName = 'Unnamed User';
                String userEmail = currentUser.email ?? 'No email provided';
                String profileImage =
                    'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png';

                if (snapshot.hasData && snapshot.data!.exists) {
                  final userData =
                      snapshot.data!.data() as Map<String, dynamic>;
                  userName =
                      userData['name'] ?? userData['fullName'] ?? userName;
                  userEmail = userData['email'] ?? userEmail;
                  profileImage = userData['profileImageUrl'] ?? profileImage;
                }

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildProfileHeader(
                        context,
                        userName: userName,
                        userEmail: userEmail,
                        profileImage: profileImage,
                      ),
                      const SizedBox(height: 30),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 20,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // 1. Contact Requests
                              _buildListTile(
                                icon: Icons.chat_bubble_outline_rounded,
                                title: 'Contact Requests',
                                onTap: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              SellerContactRequestsScreen()));
                                },
                              ),
                              _buildDivider(),

                              // 2. Hidden Listings
                              _buildListTile(
                                icon: Icons.visibility_off_outlined,
                                title: 'Hidden Listings',
                                onTap: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const SellerHiddenListingsScreen()));
                                },
                              ),
                              _buildDivider(),

                              // 3. Broadcast
                              _buildListTile(
                                icon: Icons.campaign_outlined,
                                title: 'Broadcast',
                                onTap: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const SellerBroadcastScreen()));
                                },
                              ),
                              _buildDivider(),

                              // 4. Notifications
                              _buildListTile(
                                icon: Icons.notifications_none_rounded,
                                title: 'Notifications',
                                onTap: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const SellerNotificationsScreen()));
                                },
                              ),
                              _buildDivider(),

                              // 5. Premium Membership
                              _buildListTile(
                                icon: Icons.star_border_rounded,
                                title: 'Premium Membership',
                                iconColor: Colors.amber[600],
                                onTap: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => const SellerPremiumScreen()));
                                },
                              ),
                              _buildDivider(),

                              // 6. Log Out
                              _buildListTile(
                                icon: Icons.logout_rounded,
                                title: 'Log Out',
                                isDestructive: true,
                                onTap: () async {
                                  await FirebaseAuth.instance.signOut();
                                  if (context.mounted) {
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const LoginScreen()),
                                      (Route<dynamic> route) => false,
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildProfileHeader(BuildContext context,
      {required String userName,
      required String userEmail,
      required String profileImage}) {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFF1E5670).withOpacity(0.2), width: 3),
            ),
            child: CircleAvatar(
              radius: 55,
              backgroundColor: Colors.grey[200],
              backgroundImage: NetworkImage(profileImage),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            userName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            userEmail,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E5670).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Seller', // تم تغيير الشارة هنا إلى Seller
              style: TextStyle(
                color: Color(0xFF1E5670),
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 180,
            height: 45,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const SellerEditProfileScreen(), // التوجيه لشاشة تعديل البائع
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E5670),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Edit Profile',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 60,
      endIndent: 20,
      color: Colors.grey.withOpacity(0.15),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    bool isDestructive = false,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    final defaultColor = const Color(0xFF1E5670);
    final activeColor =
        isDestructive ? Colors.redAccent : (iconColor ?? defaultColor);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: activeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: activeColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDestructive ? Colors.redAccent : Colors.black87,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
