import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/kit.dart';

/// Joindre Eduquali.
///
/// Trois canaux, et rien d'autre. Un formulaire de contact dans une
/// application qui fonctionne hors ligne promet un envoi qu'elle ne peut pas
/// tenir : le message resterait dans une file de synchronisation pendant que
/// la personne attend une réponse. Un numéro qu'on peut appeler tout de
/// suite est honnête, lui.
///
/// Chaque ligne se copie d'un appui : sur un téléphone d'entrée de gamme,
/// l'application de téléphone ne s'ouvre pas toujours depuis un lien, et
/// recopier un numéro à la main à côté d'un écran allumé est le meilleur
/// moyen de se tromper d'un chiffre.
class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nous contacter'),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          const Text(
            'Une question sur votre compte, un paiement, une fiche ? '
            'Écrivez-nous, nous répondons du lundi au samedi, de 8 h à 20 h.',
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const Gap(AppSpacing.xl),

          const KitSectionTitle(title: 'Nos coordonnées'),
          for (final canal in _Canal.tous)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: KitCard(
                onTap: () => _copier(context, canal),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    IconTile(icon: canal.icon, tone: canal.tone, size: 46),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            canal.label,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            canal.valeur,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.copy_outlined,
                      size: 20,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),

          const Gap(AppSpacing.lg),
          const InfoBanner(
            title: 'Avant d’écrire',
            message:
                'Donnez le numéro de téléphone de votre compte : c’est lui '
                'qui nous permet de retrouver votre dossier.',
            tone: StatusTone.info,
            icon: Icons.lightbulb_outline,
          ),
        ],
      ),
    );
  }

  void _copier(BuildContext context, _Canal canal) {
    Clipboard.setData(ClipboardData(text: canal.valeur));
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text('${canal.label} copié')));
  }
}

/// Un canal de contact. Les valeurs viennent des constantes : elles seront
/// pilotées par le back-office, et une adresse écrite en dur dans un écran
/// oblige à republier l'application pour la corriger.
class _Canal {
  const _Canal({
    required this.icon,
    required this.tone,
    required this.label,
    required this.valeur,
  });

  final IconData icon;
  final StatusTone tone;
  final String label;
  final String valeur;

  static const tous = [
    _Canal(
      icon: Icons.call_outlined,
      tone: StatusTone.primary,
      label: 'Téléphone',
      valeur: AppConstants.supportPhone,
    ),
    _Canal(
      icon: Icons.chat_outlined,
      tone: StatusTone.success,
      label: 'WhatsApp',
      valeur: AppConstants.supportWhatsApp,
    ),
    _Canal(
      icon: Icons.mail_outline,
      tone: StatusTone.info,
      label: 'Courriel',
      valeur: AppConstants.supportEmail,
    ),
  ];
}
