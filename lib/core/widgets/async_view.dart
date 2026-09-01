import 'package:flutter/material.dart';

import '../network/api_exception.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import 'material_symbol.dart';

/// The five states every list and fetch in Panergo must declare (RM-04).
enum LoadState { normal, loading, empty, error, offline }

/// Renders a fetch in whichever of the five states it is in.
///
/// Every list goes through this so none can quietly ship without its loading,
/// empty, error and offline treatments. The offline branch keeps showing
/// whatever was last loaded — cached offers stay readable when the network
/// drops.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.state,
    required this.data,
    required this.builder,
    required this.skeleton,
    required this.empty,
    this.onRetry,
    this.errorTitle = 'Impossible de charger les données',
    this.errorBody = 'La connexion au serveur a échoué.',
    this.offlineTitle = 'Hors ligne',
    this.offlineBody =
        'Les données déjà reçues restent consultables. La liste se mettra à jour au retour du réseau.',
  });

  final LoadState state;
  final T? data;

  /// Renders the loaded content.
  final Widget Function(BuildContext context, T data) builder;

  /// Shown while loading — skeleton bones, never a spinner on a list.
  final WidgetBuilder skeleton;

  /// Shown when the fetch genuinely returned nothing.
  final WidgetBuilder empty;

  final VoidCallback? onRetry;
  final String errorTitle;
  final String errorBody;
  final String offlineTitle;
  final String offlineBody;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case LoadState.loading:
        return skeleton(context);

      case LoadState.empty:
        return empty(context);

      case LoadState.error:
        return _StateMessage(
          icon: 'error_outline',
          iconColor: PanergoColors.errorIcon,
          title: errorTitle,
          body: errorBody,
          actionLabel: 'Réessayer',
          actionIcon: 'refresh',
          onAction: onRetry,
        );

      case LoadState.offline:
        // Keep the stale content visible underneath when we have any: being
        // able to re-read the offers you already received is the whole point.
        final cached = data;
        if (cached != null) return builder(context, cached);
        return _StateMessage(
          icon: 'cloud_off',
          iconColor: const Color(0xFFC6B892),
          title: offlineTitle,
          body: offlineBody,
          actionLabel: 'Reconnecter',
          actionIcon: 'wifi',
          onAction: onRetry,
        );

      case LoadState.normal:
        final loaded = data;
        if (loaded == null) return empty(context);
        return builder(context, loaded);
    }
  }

  /// Maps a fetch outcome onto a state, so callers do not each invent their own
  /// rules for "is this empty or is this an error".
  static LoadState stateFor({
    required bool isLoading,
    required Object? error,
    required bool isEmpty,
  }) {
    if (isLoading) return LoadState.loading;
    if (error is ApiException && error.isOffline) return LoadState.offline;
    if (error != null) return LoadState.error;
    if (isEmpty) return LoadState.empty;
    return LoadState.normal;
  }
}

/// The centred icon/title/body/action used by the error and offline states.
class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  final String icon;
  final Color iconColor;
  final String title;
  final String body;
  final String? actionLabel;
  final String? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final type = context.type;

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            Space.gutter, 34, Space.gutter, Space.s10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MaterialSymbol(icon, size: 44, color: iconColor),
            const SizedBox(height: Space.s12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: type.cardTitle.copyWith(fontSize: 15.5),
            ),
            const SizedBox(height: Space.s6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 255),
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: type.bodySmall.copyWith(color: PanergoColors.subtle, height: 1.5),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: Space.s16),
              _RetryButton(
                label: actionLabel!,
                icon: actionIcon,
                onPressed: onAction!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.label, this.icon, required this.onPressed});

  final String label;
  final String? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PanergoColors.surface,
      borderRadius: Radii.brTile,
      child: InkWell(
        onTap: onPressed,
        borderRadius: Radii.brTile,
        child: Container(
          // 44 tall keeps the touch target within guidelines.
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 17),
          decoration: BoxDecoration(
            borderRadius: Radii.brTile,
            border: Border.all(color: PanergoColors.borderInput),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                MaterialSymbol(icon!, size: 18, color: PanergoColors.ink),
                const SizedBox(width: Space.s6),
              ],
              Text(label, style: context.type.labelSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: PanergoColors.ink,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

/// The bar pinned under the status bar whenever the device is offline.
class OfflineBar extends StatelessWidget {
  const OfflineBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: PanergoColors.offlineBarBg,
      padding: const EdgeInsets.symmetric(
          horizontal: Space.gutterTight, vertical: Space.s8),
      child: Row(
        children: [
          const MaterialSymbol('cloud_off',
              size: 17, color: PanergoColors.warningIcon),
          const SizedBox(width: Space.s8),
          Expanded(
            child: Text(
              'Hors ligne · vos envois repartiront automatiquement',
              style: context.type.metaSmall
                  .copyWith(color: PanergoColors.offlineBarInk),
            ),
          ),
        ],
      ),
    );
  }
}
