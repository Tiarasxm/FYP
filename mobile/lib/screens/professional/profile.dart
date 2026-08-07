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
  String? avatarUrl;
  String specialties = '';

  double avgRating = 0;
  int reviewCount = 0;
  int activePlansCount = 0;
  int clientsCount = 0;

  RealtimeChannel? _profileChannel;
  RealtimeChannel? _statsChannel;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    if (_profileChannel != null) {
      Supabase.instance.client.removeChannel(_profileChannel!);
    }
    if (_statsChannel != null) {
      Supabase.instance.client.removeChannel(_statsChannel!);
    }
    super.dispose();
  }

  Future<void> _loadStats(String userId) async {
    final client = Supabase.instance.client;

    try {
      final professionalRow = await client
          .from('fitness_professional')
          .select('specializations')
          .eq('profile_id', userId)
          .maybeSingle();

      final reviewRows = await client
          .from('reviews')
          .select('rating')
          .eq('professional_id', userId);

      final plansRows = await client
          .from('free_plans')
          .select('free_plan_id')
          .eq('professional_id', userId)
          .or('status.is.null,status.neq.archived');

      final roomsRows = await client
          .from('chat_rooms')
          .select('client_id')
          .eq('professional_id', userId);

      final reviews = List<Map<String, dynamic>>.from(reviewRows as List);
      double rating = 0;
      if (reviews.isNotEmpty) {
        final total = reviews.fold<double>(
            0, (sum, r) => sum + ((r['rating'] as num?)?.toDouble() ?? 0));
        rating = total / reviews.length;
      }

      final uniqueClients = <String>{
        for (final row in (roomsRows as List)) row['client_id'].toString(),
      };

      if (!mounted) return;
      setState(() {
        specialties = professionalRow?['specializations']?.toString() ?? '';
        avgRating = rating;
        reviewCount = reviews.length;
        activePlansCount = (plansRows as List).length;
        clientsCount = uniqueClients.length;
      });
    } catch (e) {
      debugPrint('Error loading profile stats: $e');
    }

    _subscribeToStats(userId);
  }

  void _subscribeToStats(String userId) {
    if (_statsChannel != null) return;

    _statsChannel = Supabase.instance.client
        .channel('public:pro_profile_stats:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reviews',
          callback: (payload) {
            final affectedId = (payload.newRecord['professional_id'] ??
                    payload.oldRecord['professional_id'])
                ?.toString();
            if (affectedId == userId) _loadStats(userId);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'free_plans',
          callback: (payload) {
            final affectedId = (payload.newRecord['professional_id'] ??
                    payload.oldRecord['professional_id'])
                ?.toString();
            if (affectedId == userId) _loadStats(userId);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_rooms',
          callback: (payload) {
            final affectedId = (payload.newRecord['professional_id'] ??
                    payload.oldRecord['professional_id'])
                ?.toString();
            if (affectedId == userId) _loadStats(userId);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'fitness_professional',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'profile_id',
            value: userId,
          ),
          callback: (payload) {
            final specs = payload.newRecord['specializations']?.toString();
            if (!mounted) return;
            setState(() {
              specialties = specs ?? specialties;
            });
          },
        )
        .subscribe();
  }

  Future<void> _loadProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final data = await Supabase.instance.client
          .from('profiles')
          .select('full_name, email, avatar_url')
          .eq('id', userId)
          .single();

      if (!mounted) return;
      setState(() {
        fullName = data['full_name'] as String? ?? '';
        final url = data['avatar_url']?.toString().trim();
        avatarUrl = (url != null && url.isNotEmpty) ? url : null;
        isLoading = false;
      });

      _subscribeToProfile(userId);
      await _loadStats(userId);
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

  void _subscribeToProfile(String userId) {
    if (_profileChannel != null) return;

    _profileChannel = Supabase.instance.client
        .channel('public:profiles:pro_profile:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            final name = record['full_name']?.toString().trim();
            final url = record['avatar_url']?.toString().trim();

            if (!mounted) return;
            setState(() {
              if (name != null && name.isNotEmpty) {
                fullName = name;
              }
              avatarUrl = (url != null && url.isNotEmpty) ? url : null;
            });
          },
        )
        .subscribe();
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
                          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                          child: avatarUrl == null
                              ? Text(
                                  fullName.isNotEmpty ? fullName[0].toUpperCase() : '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )
                              : null,
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
                                specialties.isNotEmpty
                                    ? specialties.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).join(' • ')
                                    : 'No specializations set',
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

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _ProfileStat(value: avgRating.toStringAsFixed(1), label: 'RATING'),
                        _ProfileStat(value: '$reviewCount', label: 'REVIEWS'),
                        _ProfileStat(value: '$activePlansCount', label: 'ACTIVE PLANS'),
                        _ProfileStat(value: '$clientsCount', label: 'CLIENTS'),
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