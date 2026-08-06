import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<bool> showSocialReportDialog({
  required BuildContext context,
  required String contentType,
  required String reportedUserId,
  String? postId,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _SocialReportDialog(
      contentType: contentType,
      reportedUserId: reportedUserId,
      postId: postId,
    ),
  );
  return result == true;
}

class _SocialReportDialog extends StatefulWidget {
  final String contentType;
  final String reportedUserId;
  final String? postId;

  const _SocialReportDialog({
    required this.contentType,
    required this.reportedUserId,
    this.postId,
  });

  @override
  State<_SocialReportDialog> createState() => _SocialReportDialogState();
}

class _SocialReportDialogState extends State<_SocialReportDialog> {
  static const _reasons = [
    'Spam',
    'Harassment or bullying',
    'Hate speech',
    'Nudity or sexual content',
    'False information',
    'Impersonation',
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
        'content_type': widget.contentType,
        'report_type': _reason,
        'reported_user_id': widget.reportedUserId,
        'post_id': widget.postId,
        'details': _detailsController.text.trim(),
        'status': 'pending',
      });
      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (error) {
      if (!mounted) return;
      final message = error.code == '23505'
          ? 'You have already reported this ${widget.contentType}.'
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
    final target = widget.contentType == 'post' ? 'Post' : 'User';
    return AlertDialog(
      title: Text('Report $target'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Why are you reporting this?'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _reason,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              items: _reasons
                  .map(
                    (reason) => DropdownMenuItem(
                      value: reason,
                      child: Text(reason),
                    ),
                  )
                  .toList(),
              onChanged: _isSubmitting
                  ? null
                  : (value) => setState(() => _reason = value),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _detailsController,
              enabled: !_isSubmitting,
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Additional details (optional)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _reason == null || _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Submit Report'),
        ),
      ],
    );
  }
}
