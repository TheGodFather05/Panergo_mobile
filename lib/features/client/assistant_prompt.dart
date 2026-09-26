import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

/// The placeholder in the assistant field, which teaches what can be asked.
///
/// « D'abord la forme, puis une seule chose qui bouge, une fois. » The sunken
/// well and the fixed caret are what say « write here », for everybody and on
/// every open. This rotation only teaches *what* — which is why it stops, and
/// why it stops for good after a few opens.
///
/// Three examples, then back to the plain invitation and still. No loop: the
/// home screen is opened many times a day, and something that moves forever
/// there becomes noise within a week and costs battery on the phones this is
/// built for.
class AssistantPrompt extends StatefulWidget {
  const AssistantPrompt({
    super.key,
    required this.style,
    required this.showCaret,
  });

  final TextStyle style;

  /// The drawn caret, shown only while the real one is absent.
  final bool showCaret;

  /// How many times the examples play before the invitation stays fixed.
  ///
  /// Somebody who has opened the home screen three times without asking
  /// anything will not learn it from a fourth.
  static const playLimit = 3;

  static const _key = 'panergo.assistant.opens';

  /// Counts this open and says whether the examples should still play.
  static Future<bool> shouldPlay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final opens = (prefs.getInt(_key) ?? 0) + 1;
      // Stops counting at the limit: the number itself is of no interest, and
      // an unbounded counter is a value that only grows.
      if (opens <= playLimit) await prefs.setInt(_key, opens);
      return opens <= playLimit;
    } catch (_) {
      // Storage unavailable — play rather than not. A missed animation is
      // nothing; a crash on the home screen is not.
      return true;
    }
  }

  @override
  State<AssistantPrompt> createState() => AssistantPromptState();
}

class AssistantPromptState extends State<AssistantPrompt> {
  /// The first is the resting invitation; the rotation returns to it and stops.
  static const _prompts = [
    'Décrivez votre besoin…',
    'Une fuite dans la cuisine ?',
    'Un électricien ce soir ?',
  ];

  /// 1.2s, then 2s between each, ending back on the invitation at 5.2s.
  static const _beats = [
    (Duration(milliseconds: 1200), 1),
    (Duration(milliseconds: 3200), 2),
    (Duration(milliseconds: 5200), 0),
  ];

  int _index = 0;
  bool _playing = false;

  /// Cancellable, so disposal leaves nothing pending. `mounted` checks alone
  /// keep the callbacks harmless but leave timers alive behind the screen.
  final _timers = <Timer>[];

  @override
  void initState() {
    super.initState();
    _maybeStart();
  }

  Future<void> _maybeStart() async {
    if (!await AssistantPrompt.shouldPlay()) return;
    if (!mounted) return;

    // Asked here rather than at build: the setting can change while the app is
    // open, and a rotation already running should not be interrupted by it.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;

    setState(() => _playing = true);

    for (final (delay, index) in _beats) {
      _timers.add(Timer(delay, () {
        if (!mounted || !_playing) return;
        setState(() {
          _index = index;
          if (index == 0) _playing = false;
        });
      }));
    }
  }

  /// Stops on the first touch, on focus, and when the screen leaves view.
  ///
  /// Returns to the fixed invitation with no fade: a crossfade here would read
  /// as one more thing happening at the moment somebody decided to type.
  void stop() {
    _cancel();
    if (!_playing && _index == 0) return;
    setState(() {
      _playing = false;
      _index = 0;
    });
  }

  void _cancel() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Row(
      children: [
        if (widget.showCaret) ...[
          // Fixed, never blinking. A blinking caret under no cursor is a
          // promise the field has not yet made.
          Container(
            width: 2,
            height: 20,
            decoration: BoxDecoration(
              color: context.brand.link,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: AnimatedSwitcher(
            // Instant when the rotation is over or animations are reduced, so
            // the return to the invitation does not fade.
            duration: _playing && !reduced ? Motion.fadeUp : Duration.zero,
            switchInCurve: Curves.easeOut,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.35),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: Text(
              _prompts[_index],
              key: ValueKey(_index),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: widget.style,
            ),
          ),
        ),
      ],
    );
  }
}
