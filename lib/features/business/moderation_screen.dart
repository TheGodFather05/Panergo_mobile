import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/panergo_button.dart';
import 'business_providers.dart';

/// Listings waiting to be looked at.
///
/// The review is the whole trust claim of the directory: published, a listing
/// says this shop exists at this address and answers on this number. Whoever
/// reads this screen is the reason that claim means anything.
class ModerationScreen extends ConsumerWidget {
  const ModerationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(moderationQueueProvider);
    final pending = async.value ?? const <BusinessDetail>[];

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Modération',
              subtitle: pending.isEmpty
                  ? null
                  : '${pending.length} en attente',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: AsyncView<List<BusinessDetail>>(
                state: AsyncView.stateFor(
                  isLoading: async.isLoading,
                  error: async.error,
                  isEmpty: pending.isEmpty,
                ),
                data: pending,
                onRetry: () => ref.invalidate(moderationQueueProvider),
                errorTitle: 'File indisponible',
                skeleton: (_) => const _Skeleton(),
                empty: (_) => const _NothingWaiting(),
                builder: (context, items) => RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(moderationQueueProvider),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                        Space.gutterTight, 0, Space.gutterTight, Space.gutter),
                    children: [
                      for (final business in items)
                        _PendingCard(business: business),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Everything a reviewer needs to decide, without opening anything else.
///
/// The question is "does this shop exist where it says it does", and the answer
/// lives in the address and the number — so both are on the card rather than a
/// tap away.
class _PendingCard extends ConsumerStatefulWidget {
  const _PendingCard({required this.business});

  final BusinessDetail business;

  @override
  ConsumerState<_PendingCard> createState() => _PendingCardState();
}

class _PendingCardState extends ConsumerState<_PendingCard> {
  bool _busy = false;
  String? _error;

  Future<void> _publish() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).publishBusiness(widget.business.id);
      ref.invalidate(moderationQueueProvider);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'La publication a échoué.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RejectSheet(name: widget.business.name),
    );
    if (reason == null || reason.trim().isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).rejectBusiness(widget.business.id, reason);
      ref.invalidate(moderationQueueProvider);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Le refus n’est pas parti.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.business;

    return Container(
      margin: const EdgeInsets.only(bottom: Space.s12),
      padding: const EdgeInsets.all(Space.s14),
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brCardLarge,
        border: Border.all(color: PanergoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InitialsAvatar(
                  name: b.name, photoUrl: b.photoUrl, size: 44, radius: 13),
              const SizedBox(width: Space.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.name,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: PanergoColors.ink)),
                    const SizedBox(height: 2),
                    Text('${b.categoryLabel} · ${b.neighborhood}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: PanergoColors.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.s12),
          if (b.addressLine != null)
            _Fact(icon: 'place', label: 'Adresse', value: b.addressLine!),
          if (b.phoneNumber != null)
            _Fact(icon: 'call', label: 'Téléphone', value: b.phoneNumber!),
          if (b.description != null && b.description!.isNotEmpty) ...[
            const SizedBox(height: Space.s8),
            Text(b.description!,
                style: const TextStyle(
                    fontSize: 12.5, height: 1.45, color: PanergoColors.body)),
          ],
          if (b.services.isNotEmpty) ...[
            const SizedBox(height: Space.s8),
            Text(b.services.join(' · '),
                style: const TextStyle(
                    fontSize: 12, color: PanergoColors.muted)),
          ],

          if (_error != null) ...[
            const SizedBox(height: Space.s8),
            Text(_error!,
                style: const TextStyle(
                    fontSize: 12, color: PanergoColors.danger)),
          ],

          const SizedBox(height: Space.s14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _busy ? null : _reject,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: PanergoColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: PanergoColors.borderStrong),
                    ),
                    child: const Text('Refuser',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: PanergoColors.danger)),
                  ),
                ),
              ),
              const SizedBox(width: Space.s8),
              Expanded(
                child: GestureDetector(
                  onTap: _busy ? null : _publish,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _busy
                          ? PanergoColors.disabledButton
                          : context.brand.fill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_busy ? 'Un instant…' : 'Publier',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: _busy
                                ? PanergoColors.disabledLabel
                                : Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});

  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MaterialSymbol(icon, size: 16, color: PanergoColors.subtle),
          const SizedBox(width: Space.s8),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12.5, height: 1.4, color: PanergoColors.body)),
          ),
        ],
      ),
    );
  }
}

/// Refusing, with the reason the owner will read.
class _RejectSheet extends StatefulWidget {
  const _RejectSheet({required this.name});

  final String name;

  @override
  State<_RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState extends State<_RejectSheet> {
  final _controller = TextEditingController();

  /// The reasons a listing actually fails, so a reviewer taps rather than types.
  static const _common = [
    'L’adresse ne permet pas de vous situer. Ajoutez un repère.',
    'Le numéro ne répond pas.',
    'Ce commerce semble déjà inscrit.',
    'Le nom ne correspond pas à l’enseigne.',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = _controller.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: PanergoColors.page,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(
            Space.gutterTight, Space.s12, Space.gutterTight, Space.s20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: PanergoColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: Space.s16),
            Text('Refuser ${widget.name}',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: PanergoColors.ink)),
            const SizedBox(height: 4),
            const Text(
              'Le commerçant lira ce message. Dites-lui quoi corriger.',
              style: TextStyle(fontSize: 12.5, color: PanergoColors.muted),
            ),
            const SizedBox(height: Space.s14),
            for (final reason in _common)
              GestureDetector(
                onTap: () => setState(() => _controller.text = reason),
                child: Container(
                  margin: const EdgeInsets.only(bottom: Space.s6),
                  padding: const EdgeInsets.all(Space.s10),
                  decoration: BoxDecoration(
                    color: PanergoColors.surface,
                    borderRadius: Radii.brCard,
                    border: Border.all(color: PanergoColors.border),
                  ),
                  child: Text(reason,
                      style: const TextStyle(
                          fontSize: 12.5, color: PanergoColors.body)),
                ),
              ),
            const SizedBox(height: Space.s10),
            Container(
              decoration: BoxDecoration(
                color: PanergoColors.surface,
                borderRadius: Radii.brInput,
                border: Border.all(color: PanergoColors.borderInput),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: Space.s14, vertical: Space.s12),
              child: TextField(
                controller: _controller,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                    fontSize: 14, height: 1.4, color: PanergoColors.ink),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: 'Ou écrivez la raison',
                  hintStyle: TextStyle(
                      fontSize: 14, color: PanergoColors.placeholder),
                ),
              ),
            ),
            const SizedBox(height: Space.s16),
            PanergoButton(
              label: 'Envoyer le refus',
              enabled: valid,
              onPressed: () =>
                  Navigator.of(context).pop(_controller.text.trim()),
            ),
          ],
        ),
      ),
    );
  }
}

class _NothingWaiting extends StatelessWidget {
  const _NothingWaiting();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(Space.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MaterialSymbol('task_alt', size: 34, color: PanergoColors.subtle),
            SizedBox(height: Space.s12),
            Text('Rien en attente',
                style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: PanergoColors.ink)),
            SizedBox(height: Space.s6),
            Text('Toutes les fiches envoyées ont été traitées.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, height: 1.5, color: PanergoColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          Space.gutterTight, 0, Space.gutterTight, Space.gutter),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: Space.s12),
      itemBuilder: (_, __) => Container(
        height: 190,
        decoration: BoxDecoration(
          color: PanergoColors.skeleton,
          borderRadius: Radii.brCardLarge,
        ),
      ),
    );
  }
}
