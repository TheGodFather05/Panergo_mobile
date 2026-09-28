import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:panergo_mobile/core/models/enums.dart';
import 'package:panergo_mobile/core/network/json.dart';

/// Wire values must match the backend's enum constants.
///
/// A name the server sends that this app does not know falls back to whatever
/// the call site named as a default. Nothing throws and nothing logs, so a
/// shopkeeper's message quietly became a client's — the PartyRole case this
/// test was written after.
///
/// Reads the Java source next door. Skipped rather than failed when it is not
/// there, so this stays useful in a checkout of the app alone.
void main() {
  final backendRoot = Directory('../Panergo/src/main/java');

  /// Constants declared before the first `;` of a Java enum body.
  Set<String>? javaEnum(String name) {
    for (final e in backendRoot.listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('$name.java')) continue;
      var src = e.readAsStringSync();
      final open = RegExp('enum\\s+$name[^{]*\\{').firstMatch(src);
      if (open == null) continue;
      var i = open.end, depth = 1;
      while (i < src.length && depth > 0) {
        if (src[i] == '{') depth++;
        if (src[i] == '}') depth--;
        i++;
      }
      var body = src.substring(open.end, i).split(';').first;
      body = body.replaceAll(RegExp(r'//[^\n]*'), '');
      body = body.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
      return RegExp(r'\b([A-Z][A-Z0-9_]{1,40})\b(?=\s*[,(\n}])')
          .allMatches(body)
          .map((m) => m.group(1)!)
          .toSet();
    }
    return null;
  }

  /// Mobile enum -> the Java enum that feeds it, where the names differ.
  final pairs = <String, ({String java, List<WireEnum> values})>{
    'PartyRole': (java: 'PartyRole', values: PartyRole.values),
    'OfferStatus': (java: 'OfferStatus', values: OfferStatus.values),
    'RequestStatus': (java: 'RequestStatus', values: RequestStatus.values),
    'BookingStatus': (java: 'BookingStatus', values: BookingStatus.values),
    'ProposalStatus': (java: 'ProposalStatus', values: ProposalStatus.values),
    'RevenuePeriod': (java: 'RevenuePeriod', values: RevenuePeriod.values),
    'TimelineLabel': (java: 'TimelineLabel', values: TimelineLabel.values),
    'Urgency': (java: 'Urgency', values: Urgency.values),
    'UrgencyLabel': (java: 'UrgencyLabel', values: UrgencyLabel.values),
    'BudgetBracket': (java: 'BudgetBracket', values: BudgetBracket.values),
    'InquiryScope': (java: 'InquiryScope', values: InquiryScope.values),
    'InquiryStatus': (java: 'InquiryStatus', values: InquiryStatus.values),
    'ServiceCategory': (java: 'Category', values: ServiceCategory.values),
    'MetricUnavailability':
        (java: 'MetricUnavailability', values: MetricUnavailability.values),
    'AssistantSilence':
        (java: 'AssistantSilence', values: AssistantSilence.values),
  };

  test('every server value has a case in the app', () {
    if (!backendRoot.existsSync()) {
      markTestSkipped('backend source not checked out beside the app');
      return;
    }

    final problems = <String>[];
    var compared = 0;

    pairs.forEach((name, pair) {
      final java = javaEnum(pair.java);
      if (java == null || java.isEmpty) return;
      compared++;
      final app = pair.values.map((v) => v.wire).toSet();
      final unknown = java.difference(app);
      if (unknown.isNotEmpty) {
        problems.add('$name is missing ${unknown.toList()..sort()} — the '
            'server sends these and they fall back silently');
      }
    });

    // A parse that matched nothing would make this pass by checking nothing.
    expect(compared, greaterThan(10),
        reason: 'only $compared enums were compared; the Java parse is broken');
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
