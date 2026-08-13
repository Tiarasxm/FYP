import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/membership_service.dart';
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

  DateTime? _subscribedAt;
  DateTime? _priorityUntil;
  bool _isCancelling = false;

  static const String _defaultFreePrice = '\$0';
  static const String _defaultFreeDescription =
      'Access basic workout, nutrition, progress tracking and social features.';
  static const String _defaultPriorityPrice = '\$7.99 /month';
  static const String _defaultPriorityDescription =
      'Unlock advanced features, additional insights and enhanced membership benefits.';

  String _freePrice = _defaultFreePrice;
  String _freeDescription = _defaultFreeDescription;
  String _priorityPrice = _defaultPriorityPrice;
  String _priorityDescription = _defaultPriorityDescription;

  final SupabaseClient supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadMembership();
  }

  Future<void> _loadPlanContent() async {
    try {
      final response = await supabase
          .from('website_content')
          .select('content')
          .eq('section_key', 'subscription')
          .maybeSingle();

      final content = response?['content'];
      final plans = content is Map ? content['plans'] : null;

      if (plans is! List) return;

      String? freePrice;
      String? freeDescription;
      String? priorityPrice;
      String? priorityDescription;

      for (final plan in plans) {
        if (plan is! Map) continue;

        final title = plan['title']?.toString().trim().toLowerCase();
        final price = plan['price']?.toString();
        final description = plan['description']?.toString();

        if (title == 'free') {
          freePrice = price;
          freeDescription = description;
        } else if (title == 'priority') {
          priorityPrice = price;
          priorityDescription = description;
        }
      }

      if (!mounted) return;

      setState(() {
        if (freePrice != null && freePrice.isNotEmpty) {
          _freePrice = freePrice;
        }
        if (freeDescription != null && freeDescription.isNotEmpty) {
          _freeDescription = freeDescription;
        }
        if (priorityPrice != null && priorityPrice.isNotEmpty) {
          _priorityPrice = '$priorityPrice /month';
        }
        if (priorityDescription != null && priorityDescription.isNotEmpty) {
          _priorityDescription = priorityDescription;
        }
      });
    } catch (_) {
      // Keep the hardcoded fallback values so the screen never renders blank.
    }
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

      await MembershipService.ensureCurrentPriorityStatus();
      await _loadPlanContent();

      final response = await supabase
          .from('profiles')
          .select('user_type')
          .eq('id', userId)
          .maybeSingle();

      final userType =
          response?['user_type']?.toString().trim().toLowerCase() ?? 'free';

      final priority = await supabase
          .from('priority_user')
          .select('subscribed_at, expires_at')
          .eq('profile_id', userId)
          .maybeSingle();

      DateTime? subscribedAt = _parseDateTime(priority?['subscribed_at']);
      DateTime? expiresAt = _parseDateTime(priority?['expires_at']);

      if (userType == 'priority') {
        if (subscribedAt == null) {
          final now = DateTime.now();
          await supabase.from('priority_user').upsert({
            'profile_id': userId,
            'subscribed_at': now.toIso8601String(),
          });
          subscribedAt = now;
        }

        final endsAt = expiresAt ?? _oneMonthAfter(subscribedAt);

        if (endsAt.isBefore(DateTime.now())) {
          await supabase
              .from('profiles')
              .update({'user_type': 'Free'})
              .eq('id', userId);

          await supabase
              .from('priority_user')
              .delete()
              .eq('profile_id', userId);

          _resetPriorityState('free');
        } else {
          _resetPriorityState('priority',
              subscribedAt: subscribedAt,
              priorityUntil: endsAt,
              isCancelling: expiresAt != null);
        }
      } else {
        _resetPriorityState('free');
      }
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

  void _resetPriorityState(
    String plan, {
    DateTime? subscribedAt,
    DateTime? priorityUntil,
    bool isCancelling = false,
  }) {
    setState(() {
      currentPlan = plan;
      _subscribedAt = subscribedAt;
      _priorityUntil = priorityUntil;
      _isCancelling = isCancelling;
    });
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  DateTime _oneMonthAfter(DateTime date) {
    return DateTime(date.year, date.month + 1, date.day);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';

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

    return '${date.day} ${months[date.month - 1]} ${date.year}';
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

  Future<void> _upgradeToPriority() async {
    if (isUpdating) return;

    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      _showMessage('User is not signed in.', isError: true);
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: 'Upgrade to Priority',
      message: 'Do you want to upgrade your account to Priority membership?',
      confirmText: 'Upgrade',
    );

    if (!confirmed) return;

    setState(() {
      isUpdating = true;
    });

    try {
      final now = DateTime.now();

      await supabase.from('priority_user').upsert({
        'profile_id': userId,
        'subscribed_at': now.toIso8601String(),
        'expires_at': null,
      });

      await supabase.from('profiles').update({
        'user_type': 'Priority',
      }).eq('id', userId);

      _showMessage('Priority membership activated.');
    } catch (error) {
      _showMessage('Failed to upgrade membership: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isUpdating = false;
        });
      }
      _loadMembership();
    }
  }

  Future<void> _renewPriority() async {
    if (isUpdating) return;

    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      _showMessage('User is not signed in.', isError: true);
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: 'Renew Priority',
      message:
          'Renewing will start a new 30-day Priority period from today. Do you want to continue?',
      confirmText: 'Renew',
    );

    if (!confirmed) return;

    setState(() {
      isUpdating = true;
    });

    try {
      final now = DateTime.now();

      await supabase.from('priority_user').upsert({
        'profile_id': userId,
        'subscribed_at': now.toIso8601String(),
        'expires_at': null,
      });

      await supabase.from('profiles').update({
        'user_type': 'Priority',
      }).eq('id', userId);

      _showMessage('Priority membership renewed.');
    } catch (error) {
      _showMessage('Failed to renew membership: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isUpdating = false;
        });
      }
      _loadMembership();
    }
  }

  Future<void> _cancelSubscription() async {
    if (isUpdating) return;

    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      _showMessage('User is not signed in.', isError: true);
      return;
    }

    if (_subscribedAt == null) return;

    final endsAt = _oneMonthAfter(_subscribedAt!);
    final endsAtText = _formatDate(endsAt);

    final confirmed = await _showConfirmDialog(
      title: 'Cancel Subscription',
      message:
          'You will remain Priority until $endsAtText, then your account will switch to Free.',
      confirmText: 'Yes, Cancel',
    );

    if (!confirmed) return;

    setState(() {
      isUpdating = true;
    });

    try {
      await supabase.from('priority_user').update({
        'expires_at': endsAt.toIso8601String(),
      }).eq('profile_id', userId);

      if (mounted) {
        setState(() {
          _isCancelling = true;
          _priorityUntil = endsAt;
        });
      }

      _showMessage('Priority will end on $endsAtText.');
    } catch (error) {
      _showMessage('Failed to cancel membership: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isUpdating = false;
        });
      }
      _loadMembership();
    }
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
                      price: _freePrice,
                      description: _freeDescription,
                      isCurrentPlan: currentPlan == 'free',
                      isCancelling: _isCancelling,
                      buttonText: currentPlan == 'free'
                          ? null
                          : (_isCancelling
                              ? 'Downgrade scheduled'
                              : 'Switch to Free'),
                      isUpdating: isUpdating,
                      onPressed: (currentPlan == 'free' || _isCancelling)
                          ? null
                          : _cancelSubscription,
                    ),

                    const SizedBox(height: 12),

                    MembershipCard(
                      title: "Priority",
                      price: _priorityPrice,
                      description: _priorityDescription,
                      isCurrentPlan: currentPlan == 'priority',
                      isCancelling: _isCancelling,
                      nextBillingDate: _priorityUntil != null
                          ? _formatDate(_priorityUntil)
                          : null,
                      buttonText: currentPlan == 'priority'
                          ? (_isCancelling
                              ? 'Renew Priority'
                              : 'Cancel Subscription')
                          : 'Upgrade to Priority',
                      isUpdating: isUpdating,
                      onPressed: currentPlan == 'priority'
                          ? (_isCancelling
                              ? _renewPriority
                              : _cancelSubscription)
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
  final bool isCancelling;
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
    this.isCancelling = false,
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
                Expanded(
                  child: Text(
                    _isPriority && isCancelling
                        ? "Downgrading on"
                        : _isPriority
                            ? "Priority until"
                            : "Next billing",
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  nextBillingDate!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _isPriority && isCancelling
                        ? Colors.redAccent
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            if (isCancelling) ...[
              const SizedBox(height: 8),
              Text(
                'You will switch to the Free plan on this date.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.redAccent.withOpacity(0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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