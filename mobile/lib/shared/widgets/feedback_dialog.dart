import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';

/// Shows a star-rating + optional comment dialog and posts it to
/// /feedback. Used both for the manual "Give Feedback" button and the
/// weekly automatic prompt.
Future<void> showFeedbackDialog(BuildContext context, {String? introText}) async {
  int rating = 0;
  final commentController = TextEditingController();
  bool submitting = false;
  String? error;

  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Rate your experience'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (introText != null) ...[
              Text(introText, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final starIndex = i + 1;
                return IconButton(
                  icon: Icon(
                    starIndex <= rating ? Icons.star : Icons.star_border,
                    color: AppTheme.accent,
                    size: 32,
                  ),
                  onPressed: () => setDialogState(() => rating = starIndex),
                );
              }),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: commentController,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Anything you want to tell us? (optional)'),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Not now')),
          ElevatedButton(
            onPressed: submitting
                ? null
                : () async {
                    if (rating == 0) {
                      setDialogState(() => error = 'Tap a star to rate.');
                      return;
                    }
                    setDialogState(() => submitting = true);
                    try {
                      await ApiClient.instance.dio.post('/feedback', data: {
                        'rating': rating,
                        'comment': commentController.text.trim().isEmpty ? null : commentController.text.trim(),
                      });
                      if (context.mounted) Navigator.of(context).pop();
                    } catch (_) {
                      setDialogState(() {
                        submitting = false;
                        error = 'Could not submit right now. Try again later.';
                      });
                    }
                  },
            child: const Text('SUBMIT'),
          ),
        ],
      ),
    ),
  );
}
