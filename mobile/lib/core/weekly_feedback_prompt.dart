import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../shared/widgets/feedback_dialog.dart';

/// If it's been 7+ days (or never) since the person last saw the
/// feedback prompt, show it automatically. Updates the timestamp
/// regardless of whether they submit or dismiss, so it never nags
/// more than once a week.
class WeeklyFeedbackPrompt {
  static const _storage = FlutterSecureStorage();
  static const _key = 'last_feedback_prompt_at';

  static Future<void> maybeShow(BuildContext context) async {
    final lastShownStr = await _storage.read(key: _key);
    final now = DateTime.now();

    if (lastShownStr == null) {
      // First time ever - just set the baseline, don't show immediately.
      // The prompt starts a week from whenever the person first logged in,
      // not the instant they open the app for the first time.
      await _storage.write(key: _key, value: now.toIso8601String());
      return;
    }

    final lastShown = DateTime.tryParse(lastShownStr);
    if (lastShown != null && now.difference(lastShown).inDays < 7) {
      return;
    }

    await _storage.write(key: _key, value: now.toIso8601String());
    if (!context.mounted) return;
    await showFeedbackDialog(context, introText: "It's been a week - how's Milk Ledger working for you?");
  }
}
