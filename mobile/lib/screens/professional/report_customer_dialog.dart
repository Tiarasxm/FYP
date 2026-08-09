import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';

Future<bool> showReportCustomerDialog({
  required BuildContext context,
  required String clientId,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _ReportCustomerDialog(clientId: clientId),
  );
  return result == true;
}

class _ReportCustomerDialog extends StatefulWidget {
  final String clientId;

  const _ReportCustomerDialog({required this.clientId});

  @override
  State<_ReportCustomerDialog> createState() => _ReportCustomerDialogState();
}

class _ReportCustomerDialogState extends State<_ReportCustomerDialog> {
  static const _reasons = [
    'Abusive or offensive language',
    'Harassment',
    'Spam',
    'Fake information',
    'Payment dispute',
    'Inappropriate content',
    'Other',
  ];

  final _detailsController = TextEditingController();
  String? _reason;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reporterId = Supabase.instance.client.auth.currentUser?.id;
    if (reporterId == null || _reason == null || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      await Supabase.instance.client.from('reports').insert({
        'reporter_id': reporterId,
        'content_type': 'user',
        'report_type': _reason,
        'reported_user_id': widget.clientId,
        'details': _detailsController.text.trim(),
        'status': 'pending',
      });
      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (error) {
      if (!mounted) return;
      final message = error.code == '23505'
          ? 'You have already reported this customer.'
          : 'Unable to submit report: ${error.message}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to submit report: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Report Customer',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                GestureDetector(
                  onTap: _isSubmitting ? null : () => Navigator.pop(context, false),
                  child: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Let us know what happened. Reports are reviewed by our team.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            const Text(
              'Reason',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.cardMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _reason,
                  isExpanded: true,
                  hint: Text(
                    'Select a reason',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                  items: _reasons.map((reason) {
                    return DropdownMenuItem(
                      value: reason,
                      child: Text(reason, style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (value) => setState(() => _reason = value),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Additional details (optional)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _detailsController,
              enabled: !_isSubmitting,
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Describe what happened...',
                hintStyle: TextStyle(fontSize: 12, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.cardMuted,
                counterText: '',
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _reason == null || _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.border,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit Report',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
