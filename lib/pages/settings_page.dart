import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// Settings page — now uses AuthService instead of UserRepository.
///
/// The key difference: we get user info from Firebase Auth (currentUser)
/// instead of reading from SharedPreferences. Logout calls
/// authService.signOut() which signs out of both Firebase and Google.
class SettingsPage extends StatefulWidget {
  final AuthService authService;

  const SettingsPage({super.key, required this.authService});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final currentUser = widget.authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        centerTitle: true,
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // User Profile Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User Profile',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currentUser?.displayName ?? 'No user logged in',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (currentUser?.email != null && currentUser!.email.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            currentUser.email,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Settings Options
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.edit, color: Colors.grey.shade600),
                        title: Text('Edit Profile', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                        subtitle: Text('Update your account information', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
                        onTap: () {},
                      ),
                      Divider(height: 1, color: Colors.grey.shade200),
                      ListTile(
                        leading: Icon(Icons.notifications, color: Colors.grey.shade600),
                        title: Text('Notifications', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                        subtitle: Text('Manage notification settings', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
                        onTap: () {},
                      ),
                      Divider(height: 1, color: Colors.grey.shade200),
                      ListTile(
                        leading: Icon(Icons.privacy_tip, color: Colors.grey.shade600),
                        title: Text('Privacy & Security', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                        subtitle: Text('Review privacy settings', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Logout Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: ListTile(
                    leading: Icon(Icons.logout, color: Colors.red.shade600),
                    title: Text('Logout', style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.w600)),
                    trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
                    onTap: () async {
                      // Sign out of Firebase + Google
                      await widget.authService.signOut();
                      // No manual navigation needed!
                      // The StreamBuilder in main.dart detects the auth state
                      // change (user becomes null) and automatically shows LoginPage.
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
