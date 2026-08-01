import 'package:flutter/material.dart';

import '../../models/client/leaderboard_entry.dart';
import '../../theme/app_theme.dart';
import '../../widgets/client/sub_screen_scaffold.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _isLoading = true;

  List<LeaderboardEntry> _entries = [];
  LeaderboardEntry? _myEntry;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // There is currently no steps table or steps API.

      // Therefore, we cannot read real data here, nor can we use mock data.

      //Later, when connecting to the API, we will convert the data returned by the API into:
      // LeaderboardEntry(
      //   rank: 1,
      //   name: 'User Name',
      //   steps: 12000,
      //   isMe: false,
      // );

      final entries = <LeaderboardEntry>[];

      LeaderboardEntry? myEntry;

      for (final entry in entries) {
        if (entry.isMe) {
          myEntry = entry;
          break;
        }
      }

      if (!mounted) return;

      setState(() {
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

  String _dateRangeText() {
    final now = DateTime.now();

    final start = DateTime(now.year, now.month, now.day).subtract(
      Duration(days: now.weekday - 1),
    );

    final end = start.add(const Duration(days: 6));

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
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _dateRangeText(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 70),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          )
        else if (_entries.isEmpty)
          _emptyState()
        else ...[
          if (top3.length >= 3) _podium(top3),

          if (top3.length < 3) _simpleTopList(top3),

          const SizedBox(height: 24),

          for (final entry in rest) ...[
            _rankRow(entry),
            const SizedBox(height: 10),
          ],

          const SizedBox(height: 6),

          if (_myEntry != null) _myPositionCard(_myEntry!),
        ],
      ],
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
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
              'Steps ranking will be available after connecting a steps API.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _podium(List<LeaderboardEntry> top3) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _podiumSpot(
          top3[1],
          Icons.workspace_premium,
          AppColors.textMuted,
          30,
        ),
        const SizedBox(width: 24),
        _podiumSpot(
          top3[0],
          Icons.emoji_events,
          AppColors.amber,
          38,
        ),
        const SizedBox(width: 24),
        _podiumSpot(
          top3[2],
          Icons.workspace_premium,
          const Color(0xFFCD7F32),
          30,
        ),
      ],
    );
  }

  Widget _simpleTopList(List<LeaderboardEntry> entries) {
    return Column(
      children: [
        for (final entry in entries) ...[
          _rankRow(entry),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _podiumSpot(
    LeaderboardEntry entry,
    IconData medal,
    Color medalColor,
    double radius,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(medal, color: medalColor, size: 22),

          const SizedBox(height: 6),

          CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.primarySoft,
            child: Icon(
              Icons.person,
              color: AppColors.primary,
              size: radius,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),

          Text(
            '${entry.steps} steps',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankRow(LeaderboardEntry entry) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '${entry.rank}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),

          CircleAvatar(
            radius: 18,
            backgroundColor:
                entry.isMe ? AppColors.card : AppColors.primarySoft,
            child: const Icon(
              Icons.person,
              size: 18,
              color: AppColors.primary,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: entry.isMe ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),

          Text(
            '${entry.steps} steps',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _myPositionCard(LeaderboardEntry me) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Position ( #${me.rank} of ${_entries.length})',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '${me.rank}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),

              const CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.card,
                child: Icon(
                  Icons.person,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  me.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              Text(
                '${me.steps} steps',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}