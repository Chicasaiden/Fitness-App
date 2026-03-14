import 'package:flutter/material.dart';

/// Full in-app Privacy Policy and Terms of Service page.
///
/// Required for App Store and Google Play submission.
/// Add a hosted copy of this text to a URL (e.g. GitHub Pages / Notion)
/// and paste that URL into the Play Console Data Safety form.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Terms'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _SectionHeader(
              icon: Icons.shield_outlined,
              title: 'Privacy Policy',
              subtitle: 'Effective: March 2025',
            ),
            const SizedBox(height: 24),

            _PolicyBlock(
              title: 'Who We Are',
              body:
                  'CT Fit is a velocity-based training (VBT) application designed to help '
                  'athletes track bar velocity, estimate strength metrics, and plan workouts. '
                  'We are committed to protecting your privacy.',
            ),

            _PolicyBlock(
              title: 'Data We Collect',
              body:
                  '• Account information: your name and email address, collected via '
                  'Firebase Authentication when you create an account or sign in with Google.\n\n'
                  '• Workout data: sets, reps, velocity measurements, load (lbs/kg), '
                  'exercises, and session notes that you record during training. Stored in '
                  'Google Cloud Firestore.\n\n'
                  '• Bluetooth device data: the name and identifier of paired velocity '
                  'sensor devices. Used only to establish the BLE connection and is not '
                  'stored remotely.\n\n'
                  '• App preferences: settings such as weekly goal, units preference, '
                  'and dark mode are stored locally on your device.',
            ),

            _PolicyBlock(
              title: 'How We Use Your Data',
              body:
                  '• To provide and personalise your training experience (velocity feedback, '
                  '1RM estimates, progress charts, workout history).\n\n'
                  '• To authenticate your account securely via Firebase Authentication.\n\n'
                  '• We do NOT sell, rent, or share your data with any third-party advertisers.',
            ),

            _PolicyBlock(
              title: 'Third-Party Services',
              body:
                  'CT Fit uses the following third-party services which have their own privacy policies:\n\n'
                  '• Google Firebase (Authentication & Firestore) — '
                  'firebase.google.com/support/privacy\n\n'
                  '• Google Sign-In — policies.google.com/privacy',
            ),

            _PolicyBlock(
              title: 'Data Retention',
              body:
                  'Your workout and account data is retained for as long as your account '
                  'is active. You may delete your account and all associated data at any '
                  'time from Settings → Delete Account. Deletion is permanent and '
                  'irreversible.',
            ),

            _PolicyBlock(
              title: 'Your Rights',
              body:
                  '• Access: you can view all your workout data within the app.\n\n'
                  '• Deletion: you can permanently delete your account and all data from '
                  'Settings → Delete Account.\n\n'
                  '• GDPR / CCPA: if you are located in the EU or California, you have '
                  'the right to access, correct, or erase your personal data. Contact us '
                  'at the email below to exercise these rights.',
            ),

            _PolicyBlock(
              title: 'Data Security',
              body:
                  'All data is transmitted over HTTPS and stored with Firebase\'s built-in '
                  'security. Firebase Authentication handles password hashing — we never '
                  'see or store your password.',
            ),

            _PolicyBlock(
              title: 'Children\'s Privacy',
              body:
                  'CT Fit is not directed at children under 13. We do not knowingly collect '
                  'personal information from children.',
            ),

            _PolicyBlock(
              title: 'Contact',
              body:
                  'For any privacy questions or data requests, contact us at:\n'
                  'support@ctfit.app\n\n'
                  'We will respond within 30 days.',
            ),

            const Divider(height: 40),

            // Terms of Service
            _SectionHeader(
              icon: Icons.article_outlined,
              title: 'Terms of Service',
              subtitle: 'Effective: March 2025',
            ),
            const SizedBox(height: 24),

            _PolicyBlock(
              title: 'Acceptance',
              body:
                  'By using CT Fit you agree to these Terms. If you do not agree, do not use the app.',
            ),

            _PolicyBlock(
              title: 'App Usage',
              body:
                  'CT Fit is provided for personal, non-commercial use. You may not '
                  'reverse-engineer, redistribute, or use the app in any way that '
                  'violates applicable laws.',
            ),

            _PolicyBlock(
              title: 'Health Disclaimer',
              body:
                  'CT Fit provides training data and suggestions for informational purposes '
                  'only. It is not a substitute for professional medical or coaching advice. '
                  'Always consult a qualified professional before starting any training programme.',
            ),

            _PolicyBlock(
              title: 'Limitation of Liability',
              body:
                  'CT Fit is provided "as is". We are not liable for any injury, loss, or '
                  'damage arising from use of the app or reliance on its data.',
            ),

            _PolicyBlock(
              title: 'Changes',
              body:
                  'We may update these terms from time to time. Continued use of the app '
                  'after changes constitutes acceptance of the revised terms.',
            ),

            const SizedBox(height: 32),
            Center(
              child: Text(
                '© 2025 CT Fit. All rights reserved.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.blue.shade700, size: 22),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87)),
            Text(subtitle,
                style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
      ],
    );
  }
}

class _PolicyBlock extends StatelessWidget {
  final String title;
  final String body;

  const _PolicyBlock({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87)),
          const SizedBox(height: 6),
          Text(body,
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.6)),
        ],
      ),
    );
  }
}
