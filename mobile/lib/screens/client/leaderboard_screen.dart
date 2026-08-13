import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/health_sync_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/client/sub_screen_scaffold.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = true;
  bool _isUpdatingVisibility = false;
  bool _isVisibleOnLeaderboard = false;

  List<_LeaderboardUser> _entries = [];
  _LeaderboardUser? _myEntry;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  DateTime get _weekStart {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: today.weekday - 1));
  }

  DateTime get _weekEnd {
    return _weekStart.add(const Duration(days: 6));
  }

  String _dateParam(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = _client.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('User is not signed in.');
      }

      try {
        await HealthSyncService.syncTodayAndRecentDays(userId, daysBack: 7);
      } catch (e) {
        debugPrint('Leaderboard: step sync failed: $e');
      }

      final profile = await _client
          .from('profiles')
          .select('steps_leaderboard_visible')
          .eq('id', userId)
          .maybeSingle();

      final visible = profile?['steps_leaderboard_visible'] == true;

      if (!visible) {
        if (!mounted) return;

        setState(() {
          _isVisibleOnLeaderboard = false;
          _entries = [];
          _myEntry = null;
        });
        return;
      }

      final response = await _client.rpc(
        'get_steps_leaderboard',
        params: {
          'p_start_date': _dateParam(_weekStart),
          'p_end_date': _dateParam(_weekEnd),
        },
      );

      debugPrint('Leaderboard: RPC returned ${response is List ? (response as List).length : 'non-list'} rows');

      final rows = List<Map<String, dynamic>>.from(response as List);

      rows.sort((a, b) {
        final stepsA = _parseInt(a['total_steps']) ?? 0;
        final stepsB = _parseInt(b['total_steps']) ?? 0;

        if (stepsA != stepsB) {
          return stepsB.compareTo(stepsA);
        }

        final nameA = a['display_name']?.toString() ?? '';
        final nameB = b['display_name']?.toString() ?? '';
        return nameA.compareTo(nameB);
      });

      final entries = <_LeaderboardUser>[];

      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        final profileId = row['profile_id']?.toString() ?? '';

        entries.add(
          _LeaderboardUser(
            rank: i + 1,
            profileId: profileId,
            name: _safeName(row['display_name']),
            avatarUrl: _safeAvatar(row['avatar_url']),
            steps: _parseInt(row['total_steps']) ?? 0,
            isMe: profileId == userId,
          ),
        );
      }

      _LeaderboardUser? myEntry;

      for (final entry in entries) {
        if (entry.isMe) {
          myEntry = entry;
          break;
        }
      }

      if (!mounted) return;

      setState(() {
        _isVisibleOnLeaderboard = true;
        _entries = entries;
        _myEntry = myEntry;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load leaderboard: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _setLeaderboardVisibility(bool value) async {
    if (_isUpdatingVisibility) return;

    setState(() {
      _isUpdatingVisibility = true;
    });

    try {
      await _client.rpc(
        'set_steps_leaderboard_visible',
        params: {
          'p_visible': value,
        },
      );

      if (!mounted) return;

      setState(() {
        _isVisibleOnLeaderboard = value;
      });

      await _loadLeaderboard();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Your steps are now visible on the leaderboard.'
                : 'Your steps are now hidden from the leaderboard.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update visibility: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingVisibility = false;
        });
      }
    }
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }

  String _safeName(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return 'User';
    return text;
  }

  String? _safeAvatar(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    return text;
  }

  String _dateRangeText() {
    final start = _weekStart;
    final end = _weekEnd;
    return '${_monthShort(start.month)} ${start.day} - ${_monthShort(end.month)} ${end.day}';
  }

  String _monthShort(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final top3 = _entries.take(3).toList();
    final rest = _entries.skip(3).toList();

    return SubScreenScaffold(
      title: 'Leaderboard',
      children: [
        Center(child: _dateChip()),

        const SizedBox(height: 16),

        _visibilityCard(),

        const SizedBox(height: 20),

        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 70),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (!_isVisibleOnLeaderboard)
          _hiddenState()
        else if (_entries.isEmpty)
          _emptyState()
        else ...[
          if (top3.length >= 3) _podium(top3),

          if (top3.length < 3) _simpleTopList(top3),

          const SizedBox(height: 26),

          for (final entry in rest) ...[
            _rankRow(entry),
            const SizedBox(height: 12),
          ],

          if (_myEntry != null) ...[
            const SizedBox(height: 8),
            _myPositionCard(_myEntry!),
          ],
        ],
      ],
    );
  }

  Widget _dateChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        _dateRangeText(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _visibilityCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.directions_walk,
              color: AppColors.primary,
              size: 22,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Show My Steps',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _isVisibleOnLeaderboard
                      ? 'You can view and join the weekly ranking.'
                      : 'Hidden users cannot view or join the ranking.',
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          if (_isUpdatingVisibility)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Transform.scale(
              scale: 0.86,
              child: Switch(
                value: _isVisibleOnLeaderboard,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.primary,
                onChanged: _setLeaderboardVisibility,
              ),
            ),
        ],
      ),
    );
  }

  Widget _hiddenState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 54),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.visibility_off_outlined,
                color: AppColors.primary,
                size: 31,
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'Steps are hidden',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Turn on Show My Steps to join the ranking and view other users.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUpdatingVisibility
                    ? null
                    : () {
                        _setLeaderboardVisibility(true);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Join Leaderboard',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 70),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.leaderboard,
                color: AppColors.primary,
                size: 30,
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'No step data yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Connect Health Connect and sync steps to appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 18),

            TextButton.icon(
              onPressed: _loadLeaderboard,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh step ranking'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _podium(List<_LeaderboardUser> top3) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _podiumSpot(
          entry: top3[1],
          medal: Icons.workspace_premium,
          medalColor: AppColors.textMuted,
          avatarRadius: 32,
          topPadding: 34,
        ),

        const SizedBox(width: 16),

        _podiumSpot(
          entry: top3[0],
          medal: Icons.emoji_events,
          medalColor: AppColors.amber,
          avatarRadius: 38,
          topPadding: 0,
        ),

        const SizedBox(width: 16),

        _podiumSpot(
          entry: top3[2],
          medal: Icons.workspace_premium,
          medalColor: const Color(0xFFB07626),
          avatarRadius: 32,
          topPadding: 34,
        ),
      ],
    );
  }

  Widget _simpleTopList(List<_LeaderboardUser> entries) {
    return Column(
      children: [
        for (final entry in entries) ...[
          _rankRow(entry),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _podiumSpot({
    required _LeaderboardUser entry,
    required IconData medal,
    required Color medalColor,
    required double avatarRadius,
    required double topPadding,
  }) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              medal,
              color: medalColor,
              size: entry.rank == 1 ? 28 : 24,
            ),

            const SizedBox(height: 8),

            _avatar(
              entry,
              radius: avatarRadius,
              backgroundColor: AppColors.primarySoft,
            ),

            const SizedBox(height: 9),

            Text(
              entry.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: entry.rank == 1 ? 14 : 13,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              '${entry.steps} steps',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rankRow(_LeaderboardUser entry) {
    final isMe = entry.isMe;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? AppColors.primarySoft : AppColors.cardMuted,
        borderRadius: BorderRadius.circular(16),
        border: isMe ? Border.all(color: AppColors.primary, width: 1.2) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '${entry.rank}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isMe ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),

          _avatar(
            entry,
            radius: 24,
            backgroundColor: isMe ? AppColors.card : AppColors.primarySoft,
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Text(
              entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isMe ? FontWeight.w800 : FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          const SizedBox(width: 8),

          Text(
            '${entry.steps} steps',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _myPositionCard(_LeaderboardUser me) {
    final shouldShowCompact = me.rank <= 3;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Position (#${me.rank} of ${_entries.length})',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),

          const SizedBox(height: 12),

          if (shouldShowCompact)
            Row(
              children: [
                const Icon(
                  Icons.emoji_events,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You are in the top 3 this week.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  '${me.steps} steps',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 26,
                  child: Text(
                    '${me.rank}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),

                _avatar(
                  me,
                  radius: 24,
                  backgroundColor: AppColors.card,
                ),

                const SizedBox(width: 13),

                Expanded(
                  child: Text(
                    me.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                Text(
                  '${me.steps} steps',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _avatar(
    _LeaderboardUser entry, {
    required double radius,
    required Color backgroundColor,
  }) {
    final avatarUrl = entry.avatarUrl;

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      backgroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl),
      child: avatarUrl == null
          ? Icon(
              Icons.person,
              size: radius,
              color: AppColors.primary,
            )
          : null,
    );
  }
}

class _LeaderboardUser {
  final int rank;
  final String profileId;
  final String name;
  final String? avatarUrl;
  final int steps;
  final bool isMe;

  const _LeaderboardUser({
    required this.rank,
    required this.profileId,
    required this.name,
    required this.avatarUrl,
    required this.steps,
    required this.isMe,
  });
}
