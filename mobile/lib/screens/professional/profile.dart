import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/professional/mobile_page_wrapper.dart';
import '../auth/welcome_screen.dart';

import 'my_profile.dart';
import 'manage_account.dart';
import 'faqs.dart';
import 'privacy_policy.dart';
import 'terms_conditions.dart';

class ProfessionalProfile extends StatefulWidget {
  const ProfessionalProfile({super.key});

  @override
  State<ProfessionalProfile> createState() => _ProfessionalProfileState();
}

class _ProfessionalProfileState extends State<ProfessionalProfile> {
  bool isLoading = true;
  String fullName = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('full_name, email')
          .eq('id', Supabase.instance.client.auth.currentUser!.id)
          .single();

      if (!mounted) return;
      setState(() {
        fullName = data['full_name'] as String? ?? '';
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e')),
      );
    }
  }

  Future<void> logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const WelcomeScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const MobilePageWrapper(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return MobilePageWrapper(
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 28, 26, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profile',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),

              const SizedBox(height: 18),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4F5),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: Colors.black,
                          child: Text(
                            fullName.isNotEmpty ? fullName[0].toUpperCase() : '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),

                        const SizedBox(width: 16),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECE9FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'FITNESS PROFESSIONAL',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF6C63FF),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),

                              Text(
                                fullName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                ),
                              ),

                              const SizedBox(height: 4),

                              Text(
                                'Nutrition • Strength',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _ProfileStat(value: '4.8', label: 'RATING'),
                        _ProfileStat(value: '34', label: 'REVIEWS'),
                        _ProfileStat(value: '12', label: 'ACTIVE PLANS'),
                        _ProfileStat(value: '31', label: 'CLIENTS'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              _ProfileMenuGroup(
                title: 'GENERAL',
                children: [
                  _ProfileMenuItem(
                    title: 'My Profile',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyProfile(),
                        ),
                      );
                    },
                  ),
                  _ProfileMenuItem(
                    title: 'Manage Account',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ManageAccount(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _ProfileMenuGroup(
                title: 'OTHERS',
                children: [
                  _ProfileMenuItem(
                    title: 'FAQs',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FAQs(),
                        ),
                      );
                    },
                  ),
                  _ProfileMenuItem(
                    title: 'Privacy Policy',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PrivacyPolicy(),
                        ),
                      );
                    },
                  ),
                  _ProfileMenuItem(
                    title: 'Terms and Conditions',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TermsConditions(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    logout(context);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6C63FF),
                    side: const BorderSide(
                      color: Color(0xFF6C63FF),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String value;
  final String label;

  const _ProfileStat({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ProfileMenuGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ProfileMenuGroup({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          ...children,
        ],
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _ProfileMenuItem({
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        size: 22,
        color: Colors.black54,
      ),
      onTap: onTap,
    );
  }
}