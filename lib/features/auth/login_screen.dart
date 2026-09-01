import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';
import '../../core/widgets/panergo_button.dart';

/// Phone number, then the 6-digit code.
///
/// There is no SMS provider in this deployment — the backend writes the code to
/// its log — so the screen says where to find it rather than pretending a text
/// is on its way.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

enum _Step { phone, code }

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController(text: '+237');
  final _otpController = TextEditingController();

  _Step _step = _Step.phone;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String get _phone => _phoneController.text.trim();
  String get _otp => _otpController.text.trim();

  bool get _phoneValid => _phone.length >= 9;
  bool get _otpValid => _otp.length == 6;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() => _run(() async {
        await ref.read(authProvider.notifier).requestOtp(_phone);
        if (mounted) setState(() => _step = _Step.code);
      });

  Future<void> _verify() => _run(() async {
        await ref.read(authProvider.notifier).verifyOtp(_phone, _otp);
        // Routing reacts to the auth state; nothing to navigate here.
      });

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final type = context.type;

    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: FadeUp(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                Space.gutter, Space.s40, Space.gutter, Space.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: brand.fill,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'P',
                    style: type.h1.copyWith(color: Colors.white, fontSize: 30),
                  ),
                ),
                const SizedBox(height: Space.s26),
                Text(
                  _step == _Step.phone
                      ? 'Bienvenue sur\nPanergo'
                      : 'Entrez votre code',
                  style: type.display,
                ),
                const SizedBox(height: Space.s12),
                Text(
                  _step == _Step.phone
                      ? 'Trouvez un artisan de confiance près de chez vous, à Douala.'
                      : 'Nous avons envoyé un code à 6 chiffres au $_phone.',
                  style: type.bodyLarge,
                ),
                const SizedBox(height: Space.s30),
                if (_step == _Step.phone) ..._phoneStep(context) else ..._codeStep(context),
                if (_error != null) ...[
                  const SizedBox(height: Space.s14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MaterialSymbol('error_outline',
                          size: 18, color: PanergoColors.danger),
                      const SizedBox(width: Space.s8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: type.bodySmall
                              .copyWith(color: PanergoColors.danger),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _phoneStep(BuildContext context) {
    return [
      Text('Numéro de téléphone', style: context.type.label),
      const SizedBox(height: Space.s10),
      _Field(
        controller: _phoneController,
        hint: '+237 6 00 00 00 01',
        keyboardType: TextInputType.phone,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
        ],
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: Space.s22),
      PanergoButton(
        label: 'Recevoir mon code',
        icon: 'arrow_forward',
        enabled: _phoneValid,
        loading: _busy,
        onPressed: _sendCode,
      ),
      if (!_phoneValid) ...[
        const SizedBox(height: Space.s10),
        const ValidationHint('Entrez un numéro pour continuer.'),
      ],
    ];
  }

  List<Widget> _codeStep(BuildContext context) {
    return [
      Text('Code à 6 chiffres', style: context.type.label),
      const SizedBox(height: Space.s10),
      _Field(
        controller: _otpController,
        hint: '000000',
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: Space.s14),
      // Honest about how the code arrives in this deployment.
      Container(
        padding: const EdgeInsets.all(Space.s12),
        decoration: BoxDecoration(
          color: PanergoColors.warningBg,
          borderRadius: Radii.brInput,
          border: Border.all(color: PanergoColors.warningBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MaterialSymbol('info',
                size: 18, color: PanergoColors.warningIcon),
            const SizedBox(width: Space.s8),
            Expanded(
              child: Text(
                'Le SMS n’est pas encore actif : le code est affiché dans les '
                'journaux du serveur pendant la phase de test.',
                style: context.type.metaSmall
                    .copyWith(color: PanergoColors.warningBody, height: 1.4),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: Space.s22),
      PanergoButton(
        label: 'Se connecter',
        enabled: _otpValid,
        loading: _busy,
        onPressed: _verify,
      ),
      const SizedBox(height: Space.s12),
      Center(
        child: TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                    _step = _Step.phone;
                    _otpController.clear();
                    _error = null;
                  }),
          child: Text(
            'Modifier le numéro',
            style: context.type.label.copyWith(color: PanergoColors.subtle),
          ),
        ),
      ),
    ];
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brInput,
        border: Border.all(color: PanergoColors.borderStrong),
      ),
      padding: const EdgeInsets.symmetric(horizontal: Space.s14),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        style: context.type.cardTitle.copyWith(fontSize: 16),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: context.type.cardTitle
              .copyWith(fontSize: 16, color: PanergoColors.placeholder),
          contentPadding: const EdgeInsets.symmetric(vertical: Space.s16),
        ),
      ),
    );
  }
}
