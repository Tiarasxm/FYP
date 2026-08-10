import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';

class MembershipPage extends StatefulWidget {
  const MembershipPage({super.key});

  @override
  State<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage> {
  bool isLoading = true;
  bool isUpdating = false;

  String currentPlan = 'free';

  final SupabaseClient supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadMembership();
  }

  Future<void> _loadMembership() async {
    setState(() {
      isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('User is not signed in.');
      }

      final response = await supabase
          .from('profiles')
          .select('user_type')
          .eq('id', userId)
          .maybeSingle();

      if (!mounted) return;

      final userType =
          response?['user_type']?.toString().trim().toLowerCase() ?? 'free';

      setState(() {
        currentPlan = userType == 'priority' ? 'priority' : 'free';
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load membership: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> _updateMembership(String newPlan) async {
    if (isUpdating) return;

    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      _showMessage('User is not signed in.', isError: true);
      return;
    }

    setState(() {
      isUpdating = true;
    });

    try {
      final userTypeValue = newPlan == 'priority' ? 'Priority' : 'Free';

      await supabase.from('profiles').update({
        'user_type': userTypeValue,
      }).eq('id', userId);

      if (!mounted) return;

      setState(() {
        currentPlan = newPlan;
      });

      if (newPlan == 'priority') {
        _showMessage('Priority membership activated.');
      } else {
        _showMessage('Priority membership cancelled.');
      }
    } catch (error) {
      _showMessage('Failed to update membership: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isUpdating = false;
        });
      }
    }
  }

  Future<void> _upgradeToPriority() async {
    final confirmed = await _showConfirmDialog(
      title: 'Upgrade to Priority',
      message:
          'Do you want to upgrade your account to Priority membership?',
      confirmText: 'Upgrade',
    );

    if (!confirmed) return;

    await _updateMembership('priority');
  }

  Future<void> _cancelSubscription() async {
    final confirmed = await _showConfirmDialog(
      title: 'Cancel Subscription',
      message: 'Are you sure you want to cancel your Priority membership?',
      confirmText: 'Yes, Cancel',
    );

    if (!confirmed) return;

    await _updateMembership('free');
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : null,
      ),
    );
  }

  String _nextBillingDateText() {
    final now = DateTime.now();
    final next = DateTime(now.year, now.month + 1, now.day);

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${next.day} ${months[next.month - 1]} ${next.year}';
  }

  void _goBack() {
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : RefreshIndicator(
                onRefresh: _loadMembership,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  children: [
                    Row(
                      children: [
                        _MembershipBackButton(
                          onPressed: _goBack,
                        ),
                        const Expanded(
                          child: Center(
                            child: Text(
                              "Membership",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 38),
                      ],
                    ),

                    const SizedBox(height: 28),

                    MembershipCard(
                      title: "Free",
                      price: "\$0",
                      description:
                          "Access basic workout, nutrition, progress tracking and social features.",
                      isCurrentPlan: currentPlan == 'free',
                      buttonText:
                          currentPlan == 'free' ? null : 'Switch to Free',
                      isUpdating: isUpdating,
                      onPressed:
                          currentPlan == 'free' ? null : _cancelSubscription,
                    ),

                    const SizedBox(height: 12),

                    MembershipCard(
                      title: "Priority",
                      price: "\$7.99 /month",
                      description:
                          "Unlock advanced features, additional insights and enhanced membership benefits.",
                      isCurrentPlan: currentPlan == 'priority',
                      nextBillingDate: currentPlan == 'priority'
                          ? _nextBillingDateText()
                          : null,
                      buttonText: currentPlan == 'priority'
                          ? 'Cancel Subscription'
                          : 'Upgrade to Priority',
                      isUpdating: isUpdating,
                      onPressed: currentPlan == 'priority'
                          ? _cancelSubscription
                          : _upgradeToPriority,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class MembershipCard extends StatelessWidget {
  final String title;
  final String price;
  final String description;
  final bool isCurrentPlan;
  final String? nextBillingDate;
  final String? buttonText;
  final bool isUpdating;
  final VoidCallback? onPressed;

  const MembershipCard({
    super.key,
    required this.title,
    required this.price,
    required this.description,
    this.isCurrentPlan = false,
    this.nextBillingDate,
    this.buttonText,
    this.isUpdating = false,
    this.onPressed,
  });

  bool get _isPriority {
    return title.toLowerCase() == 'priority';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FC),
        borderRadius: BorderRadius.circular(16),
        border: isCurrentPlan
            ? Border.all(
                color: AppColors.primary,
                width: 1.2,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isCurrentPlan)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5DFFF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    "Current Plan",
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 5),

          Text(
            price,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            description,
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),

          if (_isPriority) ...[
            const SizedBox(height: 14),
            _BenefitRow(text: 'Advanced progress insights'),
            _BenefitRow(text: 'Priority nutrition features'),
            _BenefitRow(text: 'Enhanced membership benefits'),
          ],

          if (isCurrentPlan && nextBillingDate != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Next billing",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  nextBillingDate!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],

          if (buttonText != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton(
                onPressed: isUpdating ? null : onPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      buttonText == 'Cancel Subscription'
                          ? Colors.red
                          : AppColors.primary,
                  side: BorderSide(
                    color: buttonText == 'Cancel Subscription'
                        ? Colors.red
                        : AppColors.primary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isUpdating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        buttonText!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final String text;

  const _BenefitRow({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            size: 15,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MembershipBackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _MembershipBackButton({
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F3FC),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: const Icon(
          Icons.arrow_back_ios_new,
          size: 15,
        ),
      ),
    );
  }
}