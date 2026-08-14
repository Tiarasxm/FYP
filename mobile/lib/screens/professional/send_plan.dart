import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/professional/workout_plan.dart';
import '../../widgets/professional/mobile_page_wrapper.dart';
import '../../theme/app_theme.dart';

class SendPlan extends StatefulWidget {
  const SendPlan({super.key});

  @override
  State<SendPlan> createState() => _SendPlanState();
}

class _SendPlanState extends State<SendPlan> {
  String searchText = '';
  WorkoutPlan? selectedPlan;
  List<WorkoutPlan> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final data = await Supabase.instance.client
          .from('free_plans')
          .select()
          .eq('professional_id', userId)
          .order('created_at', ascending: false);

      final plans = (data as List).map((row) {
        final tags = <String>[];
        if (row['tag1'] != null && (row['tag1'] as String).isNotEmpty) tags.add(row['tag1']);
        if (row['tag2'] != null && (row['tag2'] as String).isNotEmpty) tags.add(row['tag2']);
        if (row['tag3'] != null && (row['tag3'] as String).isNotEmpty) tags.add(row['tag3']);

        final durationWeeks = row['duration_weeks'] as int? ?? 1;

        return WorkoutPlan(
          freePlanId: row['free_plan_id'],
          title: row['plan_name'] ?? 'Untitled',
          days: durationWeeks * 7,
          
          durationWeeks: durationWeeks,
          visibility: row['visibility'] ?? 'public',
          tags: tags,
          workoutDays: [],
        );
      }).toList();

      if (mounted) {
        setState(() {
          _plans = plans;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading plans: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<WorkoutPlan> get filteredPlans {
    return _plans.where((plan) {
      return plan.title.toLowerCase().contains(searchText.toLowerCase());
    }).toList();
  }

  void sendPlan() {
    if (selectedPlan == null) return;
    final nav = Navigator.of(context);
    debugPrint('SendPlan: canPop=${nav.canPop()}, popping with plan: ${selectedPlan!.title}');
    if (nav.canPop()) {
      nav.pop(selectedPlan);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobilePageWrapper(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      debugPrint('SendPlan: close button tapped, canPop=${Navigator.of(context).canPop()}');
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.cardMuted,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),

                  const Expanded(
                    child: Center(
                      child: Text(
                        'Select Plan',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 44),
                ],
              ),

              const SizedBox(height: 32),

              TextField(
                onChanged: (value) {
                  setState(() {
                    searchText = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search plan name',
                  hintStyle: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                  ),
                  suffixIcon: Icon(
                    Icons.search,
                    color: AppColors.textSecondary,
                  ),
                  filled: true,
                  fillColor: AppColors.cardMuted,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredPlans.isEmpty
                        ? Center(
                            child: Text(
                              'No plans found',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 14,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredPlans.length,
                            itemBuilder: (context, index) {
                              final plan = filteredPlans[index];
                              final selected = selectedPlan == plan;

                              return _SelectablePlanCard(
                                plan: plan,
                                selected: selected,
                                onTap: () {
                                  setState(() {
                                    selectedPlan = plan;
                                  });
                                },
                              );
                            },
                          ),
              ),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: selectedPlan == null ? null : sendPlan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.border,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Send Plan',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectablePlanCard extends StatelessWidget {
  final WorkoutPlan plan;
  final bool selected;
  final VoidCallback onTap;

  const _SelectablePlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? AppColors.primary : Colors.transparent,
          width: 1.3,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  '${plan.days} Days',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 10),

                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: plan.tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.border,
                        ),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}