import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/remote/promotions_api.dart';
import '../../providers/core_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/kit.dart';

/// La promotion d'un établissement, dans l'accueil d'une famille.
///
/// --- Ce que cet emplacement corrige -------------------------------------
///
/// Un établissement remplissait « Faire ma promotion », déposait une image, et
/// son espace lui affichait un compteur « Affichages ». Ce compteur restait à
/// zéro pour toujours : **aucun écran ne lisait les promotions actives**.
/// `activePromotionsProvider` existait sans un seul consommateur, et le seul
/// `PromoCard` affiché était un bouton fixe « Créer un cours » pour les
/// professeurs. Une promotion n'était vue par personne.
///
/// --- Pourquoi elle ne s'affiche qu'aux comptes FREE ---------------------
///
/// Payer, c'est ne plus voir de publicité — et c'est ce qui donne une raison
/// de passer à une formule payante. Le serveur décide : lire la formule ici la
/// rendrait contournable, et l'écran n'a pas à connaître la règle.
///
/// --- Pourquoi l'affichage est annoncé au serveur ------------------------
///
/// « Affichages » est ce que l'établissement achète : le chiffre doit vouloir
/// dire quelque chose. Le serveur compte **une vue par personne et par jour**,
/// donc rouvrir l'onglet ne gonfle rien. L'appel part une seule fois par
/// montage, et son échec ne se voit pas — un compteur manqué n'est pas une
/// raison de déranger quelqu'un.
class PromotionSlot extends ConsumerStatefulWidget {
  const PromotionSlot({super.key});

  @override
  ConsumerState<PromotionSlot> createState() => _PromotionSlotState();
}

class _PromotionSlotState extends ConsumerState<PromotionSlot> {
  /// Les affichages déjà annoncés pendant cette ouverture d'écran.
  ///
  /// Le serveur dédoublonne déjà par jour ; ceci évite simplement un appel
  /// réseau à chaque redessin, ce qui arrive souvent sur un tableau de bord.
  final _annonces = <String>{};

  void _annoncer(String id) {
    if (!_annonces.add(id)) return;
    // Volontairement sans `await` : l'écran ne doit pas attendre un compteur.
    ref.read(promotionsApiProvider).recordView(id);
  }

  @override
  Widget build(BuildContext context) {
    final promotions = ref.watch(promotionFeedProvider).valueOrNull ?? const [];
    // Rien à montrer, ou compte payant : la section disparaît. Un cadre vide
    // « publicité » serait pire que pas de publicité.
    if (promotions.isEmpty) return const SizedBox.shrink();

    final promotion = promotions.first;
    _annoncer(promotion.id);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    promotion.institutionName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                // Dit que c'en est une. Une promotion qui se fait passer pour
                // du contenu est une tromperie, et les familles s'en
                // aperçoivent toujours.
                const TagChip(label: 'Annonce', tone: StatusTone.neutral),
              ],
            ),
            if (promotion.institutionCity != null) ...[
              const Gap(2),
              MetaText(promotion.institutionCity!),
            ],
            const Gap(AppSpacing.sm),
            Text(
              promotion.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if (promotion.message != null &&
                promotion.message!.trim().isNotEmpty) ...[
              const Gap(4),
              Text(
                promotion.message!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, height: 1.3),
              ),
            ],
            if (promotion.image != null) ...[
              const Gap(AppSpacing.sm),
              _Visuel(chemin: promotion.image!),
            ],
          ],
        ),
      ),
    );
  }
}

/// L'image déposée par l'établissement.
///
/// Un chemin local : les médias ne sont pas encore téléversés (R2 n'est pas
/// configuré). Le fichier n'existe donc que sur l'appareil qui l'a déposé, et
/// la carte se contente de son texte ailleurs — plutôt qu'un cadre cassé.
class _Visuel extends StatelessWidget {
  const _Visuel({required this.chemin});

  final String chemin;

  @override
  Widget build(BuildContext context) {
    final fichier = File(chemin);
    if (!fichier.existsSync()) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: AppRadius.card,
      child: Image.file(
        fichier,
        height: 140,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}

/// Ce que le serveur choisit de montrer à cette personne.
///
/// La sélection est une règle produit — la moins vue d'abord, pour étaler la
/// diffusion — et elle vit au serveur : recopiée dans chaque écran, elle
/// divergerait.
final promotionFeedProvider = FutureProvider<List<PromotionAd>>(
  (ref) => ref.watch(promotionsApiProvider).feed(),
);
