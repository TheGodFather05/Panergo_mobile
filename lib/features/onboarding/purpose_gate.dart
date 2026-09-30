import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether this device has been asked what brought its owner here.
///
/// A device preference rather than a column, for the same reason the active
/// mode is one: the question has no answer worth storing. Picking
/// « commerçant » does not make anybody a merchant — it opens the form that
/// does, and the form creates the row. Someone who picks it and walks away is a
/// client who owns nothing, which is exactly what they are, and a column saying
/// otherwise would be a record of an intention the product never honoured.
///
/// The cost is that reinstalling asks again. That is mild, and the alternative
/// — withholding profile_completed_at until the question is answered — would
/// make somebody who abandons this screen look like they never introduced
/// themselves at all.
///
/// If the drop-off between « I keep a shop » and a published listing ever needs
/// measuring, that is the moment for a column, and it should be a new one
/// rather than this flag moved server-side.
final purposeAskedProvider =
    NotifierProvider<PurposeAskedNotifier, bool>(PurposeAskedNotifier.new);

class PurposeAskedNotifier extends Notifier<bool> {
  static const _key = 'panergo.purpose_asked';

  @override
  bool build() {
    _restore();
    // Asked, until storage says otherwise. The wrong guess in this direction
    // costs a returning user nothing; the other way round flashes the question
    // at somebody who answered it months ago, on every cold start.
    return true;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  /// Remember that the question has been put, whatever the answer was.
  ///
  /// Called for every outcome including « I am here to find someone », because
  /// what is recorded is that we asked — not what we were told.
  Future<void> markAsked() async {
    state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
