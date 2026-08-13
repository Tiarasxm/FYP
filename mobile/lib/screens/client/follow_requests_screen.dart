import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';

class FollowRequestsScreen extends StatefulWidget {
  const FollowRequestsScreen({super.key});

  @override
  State<FollowRequestsScreen> createState() => _FollowRequestsScreenState();
}

class _FollowRequestsScreenState extends State<FollowRequestsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      final rows = await _supabase
          .from('follows')
          .select('follower_id, created_at')
          .eq('following_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final followerIds = (rows as List<dynamic>)
          .map((row) => (row as Map<String, dynamic>)['follower_id']?.toString())
          .whereType<String>()
          .toList();

      if (followerIds.isEmpty) {
        if (mounted) setState(() { _requests = []; _isLoading = false; });
        return;
      }

      final profileRows = await _supabase
          .from('profiles')
          .select('id, full_name, avatar_url')
          .inFilter('id', followerIds);

      final profileMap = <String, Map<String, dynamic>>{};
      for (final row in profileRows as List<dynamic>) {
        final id = (row as Map<String, dynamic>)['id']?.toString();
        if (id != null) profileMap[id] = row;
      }

      final requests = <Map<String, dynamic>>[];
      for (final row in rows) {
        final followerId = (row as Map<String, dynamic>)['follower_id']?.toString();
        if (followerId == null) continue;
        final profile = profileMap[followerId];
        requests.add({
          'follower_id': followerId,
          'full_name': profile?['full_name']?.toString() ?? 'Unknown User',
          'avatar_url': profile?['avatar_url']?.toString(),
        });
      }

      if (mounted) setState(() { _requests = requests; _isLoading = false; });
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load requests: $error')),
        );
      }
    }
  }

  Future<void> _respond(String followerId, bool accept) async {
    try {
      await _supabase.rpc(
        'respond_follow_request',
        params: {
          'p_follower_uuid': followerId,
          'p_accept': accept,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(accept ? 'Follow request accepted.' : 'Follow request declined.')),
      );

      await _loadRequests();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to respond: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        title: const Text('Follow Requests'),
        backgroundColor: AppColors.pageBg,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_add_disabled, size: 64, color: AppColors.textMuted),
                      const SizedBox(height: 16),
                      Text(
                        'No pending follow requests',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRequests,
                  child: ListView.separated(
                    itemCount: _requests.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final req = _requests[index];
                      final name = req['full_name']?.toString() ?? 'Unknown User';
                      final avatarUrl = req['avatar_url']?.toString();
                      final followerId = req['follower_id']?.toString() ?? '';

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.primarySoft,
                          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl == null || avatarUrl.isEmpty
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                                )
                              : null,
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('wants to follow you', style: TextStyle(fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _respond(followerId, false),
                              icon: const Icon(Icons.close, color: Colors.red),
                              tooltip: 'Decline',
                            ),
                            IconButton(
                              onPressed: () => _respond(followerId, true),
                              icon: const Icon(Icons.check, color: Colors.green),
                              tooltip: 'Accept',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
