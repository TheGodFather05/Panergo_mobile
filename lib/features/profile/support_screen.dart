import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/material_symbol.dart';

/// Help, and how to reach a person.
///
/// The questions are the ones the product's own decisions create — why an
/// artisan must not confirm their own arrival, why a price stops moving, why a
/// quartier has to be picked from a list. Someone who hits those without an
/// explanation reads them as bugs.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  /// Only one answer open at a time — a page of everything unfolded is a wall.
  int? _open;

  static const _questions = <(String, String)>[
    (
      'Comment trouver un prestataire ?',
      'Décrivez votre besoin depuis l’accueil. Votre demande part aux artisans '
          'de votre métier et de votre quartier, et vous recevez leurs offres '
          'avec leur prix et leur délai. Vous choisissez.',
    ),
    (
      'Pourquoi dois-je choisir mon quartier dans une liste ?',
      'Vos demandes sont envoyées aux artisans du même quartier. Une '
          'orthographe différente — « Akwa » et « akwa » — crée deux quartiers '
          'séparés, et votre demande n’atteindrait personne.',
    ),
    (
      'Comment le prix est-il fixé ?',
      'Le prestataire propose un prix. Vous pouvez en proposer un autre, et lui '
          'aussi, jusqu’à ce que l’un accepte celui de l’autre. Le prix devient '
          'définitif quand le prestataire confirme son arrivée.',
    ),
    (
      'Pourquoi le prestataire scanne-t-il mon code ?',
      'C’est la preuve qu’il est bien arrivé chez vous. Le code est sur votre '
          'écran : s’il pouvait confirmer seul, la confirmation ne prouverait '
          'rien.',
    ),
    (
      'Panergo prend-il ma commission ou mon paiement ?',
      'Non. Vous payez l’artisan directement, comme vous en convenez tous les '
          'deux. Panergo met en relation, il ne gère pas l’argent.',
    ),
    (
      'Comment devenir prestataire ?',
      'Depuis votre profil, « Devenir prestataire ». Vous choisissez votre '
          'métier et votre quartier, et vous recevez des demandes aussitôt. '
          'Vous gardez votre compte et pouvez revenir en mode client quand vous '
          'voulez.',
    ),
    (
      'Une mission s’est mal passée. Que faire ?',
      'Écrivez-nous. Le fil de discussion et l’historique du prix restent '
          'consultables, ce qui permet de reconstituer ce qui a été convenu.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PanergoColors.page,
      body: SafeArea(
        child: FadeUp(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(
                title: 'Aide & support',
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Space.gutterTight, Space.s8, Space.gutterTight, Space.s26),
                  children: [
                    const _SectionLabel('Questions fréquentes'),
                    for (var i = 0; i < _questions.length; i++)
                      _Question(
                        question: _questions[i].$1,
                        answer: _questions[i].$2,
                        open: _open == i,
                        onTap: () => setState(() => _open = _open == i ? null : i),
                      ),
                    const SizedBox(height: Space.s26),
                    const _SectionLabel('Nous joindre'),
                    const _ContactCard(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({
    required this.question,
    required this.answer,
    required this.open,
    required this.onTap,
  });

  final String question;
  final String answer;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: Space.s8),
        padding: const EdgeInsets.all(Space.s14),
        decoration: BoxDecoration(
          color: PanergoColors.surface,
          borderRadius: Radii.brCard,
          border: Border.all(color: PanergoColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(question,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                          color: PanergoColors.ink)),
                ),
                const SizedBox(width: Space.s10),
                MaterialSymbol(open ? 'expand_less' : 'expand_more',
                    size: 20, color: PanergoColors.subtle),
              ],
            ),
            if (open) ...[
              const SizedBox(height: Space.s10),
              Text(answer,
                  style: const TextStyle(
                      fontSize: 13.5, height: 1.5, color: PanergoColors.body)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Space.gutterTight),
      decoration: BoxDecoration(
        color: PanergoColors.surface,
        borderRadius: Radii.brCardLarge,
        border: Border.all(color: PanergoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MaterialSymbol('support_agent',
                  size: 22, color: context.brand.link),
              const SizedBox(width: Space.s10),
              const Expanded(
                child: Text('Une question sans réponse ici ?',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: PanergoColors.ink)),
              ),
            ],
          ),
          const SizedBox(height: Space.s10),
          const Text(
            'Écrivez-nous sur WhatsApp au +237 6 XX XX XX XX. Nous répondons '
            'aux heures ouvrables, du lundi au samedi.',
            style: TextStyle(
                fontSize: 13, height: 1.5, color: PanergoColors.body),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s10, left: 2),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
            color: PanergoColors.faint),
      ),
    );
  }
}
