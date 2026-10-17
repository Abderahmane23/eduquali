import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/remote/points_api.dart';
import '../../providers/core_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/kit.dart';

/// La boutique : ce que les points permettent d'obtenir (phase D2).
///
/// --- Pourquoi cet écran existe ------------------------------------------
///
/// Les points existaient depuis le 03/10 et ne s'échangeaient contre rien. Une
/// monnaie de fidélité qui n'achète rien est un nombre qui monte, et un enfant
/// s'en rend compte vite. C'est la contrepartie qui donne sa valeur à la
/// monnaie, pas l'inverse.
///
/// --- Les trois choses que la page doit dire -----------------------------
///
///   1. **Le solde**, en haut, avant les lots : c'est ce qu'on vient vérifier.
///   2. **La distance au lot suivant** — « encore 25 000 points ». Un solde seul
///      ne dit pas si l'on progresse ; un écart le dit.
///   3. **Le prix en points ET l'équivalent en francs.** « 30 000 points » ne
///      veut rien dire seul ; « ≈ 5 000 000 GNF » rend le barème jugeable.
///
/// Rien n'est calculé ici : le solde, l'écart et le fait qu'un lot soit
/// accessible viennent tous du serveur. Les recalculer afficherait « échanger »
/// sur un lot que le serveur refusera ensuite.
class ShopPage extends ConsumerWidget {
  const ShopPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boutique = ref.watch(shopProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Boutique'),
      ),
      body: SafeArea(
        child: boutique.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            // Un message, jamais un catalogue vide : « aucun lot » laisserait
            // croire qu'il n'y a rien à gagner.
            child: EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Boutique indisponible',
              message: '$error',
            ),
          ),
          data: (shop) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(shopProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.md,
                AppSpacing.screenH,
                AppSpacing.xxl,
              ),
              children: [
                _Solde(shop: shop),
                const Gap(AppSpacing.lg),
                if (shop.items.isEmpty)
                  const EmptyState(
                    icon: Icons.card_giftcard_outlined,
                    title: 'Aucun lot pour le moment',
                    message: 'De nouveaux lots arrivent régulièrement.',
                  )
                else
                  for (final lot in shop.items) ...[
                    _LotCard(lot: lot),
                    const Gap(AppSpacing.md),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Le solde, et la marche suivante.
class _Solde extends StatelessWidget {
  const _Solde({required this.shop});

  final Shop shop;

  @override
  Widget build(BuildContext context) {
    final suivant = shop.nextId == null
        ? null
        : shop.items.where((l) => l.id == shop.nextId).firstOrNull;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MetaText('Vos points'),
          const Gap(AppSpacing.xs),
          Text(
            Fmt.money(shop.balance, withCurrency: false),
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
          ),
          if (suivant != null) ...[
            const Gap(AppSpacing.md),
            // La phrase que le plan demande : « encore 140 points ». Elle dit
            // ce qu'un solde seul ne dit pas.
            Text(
              'Encore ${Fmt.money(shop.missing, withCurrency: false)} points '
              'pour ${suivant.name}.',
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const Gap(AppSpacing.sm),
            ThinProgressBar(
              value: suivant.pointsPrice == 0
                  ? 0
                  : (shop.balance / suivant.pointsPrice).clamp(0.0, 1.0),
            ),
          ],
        ],
      ),
    );
  }
}

class _LotCard extends ConsumerStatefulWidget {
  const _LotCard({required this.lot});

  final ShopItem lot;

  @override
  ConsumerState<_LotCard> createState() => _LotCardState();
}

class _LotCardState extends ConsumerState<_LotCard> {
  bool _envoi = false;

  @override
  Widget build(BuildContext context) {
    final lot = widget.lot;
    final echangeable = lot.affordable && lot.inStock && !_envoi;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  width: 84,
                  height: 84,
                  color: AppColors.surfaceMuted,
                  // Tous les lots ne sont pas des objets : un forfait internet
                  // se dit mieux par une icône que par une vignette inventée.
                  child: lot.hasImage
                      ? Image.asset(
                          lot.assetPath,
                          fit: BoxFit.contain,
                          // Une illustration absente du bundle ne doit pas
                          // faire tomber l'écran.
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.card_giftcard_outlined,
                            color: AppColors.textSecondary,
                          ),
                        )
                      : const Icon(
                          Icons.redeem_outlined,
                          size: 34,
                          color: AppColors.primary,
                        ),
                ),
              ),
              const Gap(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            lot.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _Coeur(lot: lot),
                      ],
                    ),
                    if (lot.summary != null) ...[
                      const Gap(AppSpacing.xs),
                      MetaText(lot.summary!),
                    ],
                    const Gap(AppSpacing.sm),
                    Text(
                      lot.isRaffle
                          ? '${Fmt.money(lot.pointsPrice, withCurrency: false)} points l’entrée'
                          : '${Fmt.money(lot.pointsPrice, withCurrency: false)} points',
                      style: const TextStyle(
                        // Un nombre : la police des chiffres, nommee. Sans
                        // elle, le 800 n'existe pas dans Lexend et le
                        // moteur l'epaissit lui-meme — plus lourd, moins
                        // net, et different du reste des chiffres.
                        fontFamily: AppTheme.fontTitre,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    // L'équivalent en francs : « 30 000 points » ne veut rien
                    // dire seul. Ce n'est PAS un prix de vente — rien ne
                    // s'achète ici avec de l'argent.
                    if (lot.valueGnf > 0)
                      MetaText('soit ${Fmt.money(lot.valueGnf)}'),
                  ],
                ),
              ),
            ],
          ),
          const Gap(AppSpacing.md),
          Row(
            children: [
              if (!lot.inStock)
                StatusPill(
                  label: lot.isRaffle ? 'Tirage passé' : 'Épuisé',
                  tone: StatusTone.neutral,
                )
              else if (lot.isRaffle)
                // Ses propres chances d'abord : c'est ce qu'on vient vérifier.
                StatusPill(
                  label: lot.entries == 0
                      ? 'Aucune chance'
                      : '${lot.entries} chance${lot.entries > 1 ? 's' : ''}',
                  tone: lot.entries == 0
                      ? StatusTone.neutral
                      : StatusTone.success,
                )
              else
                StatusPill(
                  label: '${lot.stock} disponible${lot.stock > 1 ? 's' : ''}',
                  tone: StatusTone.success,
                ),
              const Spacer(),
              FilledButton(
                /*
                 * La largeur minimale, redite ici, et pourquoi.
                 *
                 * Le theme pose `minimumSize: Size.fromHeight(56)` — ce qui
                 * veut dire `Size(infinity, 56)` : un bouton large par
                 * defaut. Dans une colonne, le parent borne cette largeur et
                 * tout va bien. Dans une **rangee**, l'enfant sans `flex`
                 * est mesure sans borne : le bouton reclame alors une
                 * largeur infinie, et la mise en page leve.
                 *
                 * Quatre autres ecrans ont le meme montage. Corriger le
                 * theme les reglerait tous d'un coup, mais rendrait sa
                 * largeur de contenu a chaque bouton de l'application : ce
                 * n'est pas une retouche a glisser dans une livraison.
                 */
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, AppSpacing.cible),
                ),
                onPressed: echangeable ? _echanger : null,
                child: Text(
                  _envoi
                      ? 'Envoi…'
                      : lot.isRaffle
                      ? 'Tenter ma chance'
                      : 'Échanger',
                ),
              ),
            ],
          ),
          // Une date transforme une attente en rendez-vous. Sans elle, « tirage
          // au sort » se lit comme « un jour, peut-être ».
          if (lot.isRaffle && lot.drawsAt != null && lot.inStock) ...[
            const Gap(AppSpacing.sm),
            MetaText('Tirage le ${Fmt.date(lot.drawsAt!)}'),
          ],
        ],
      ),
    );
  }

  Future<void> _echanger() async {
    final lot = widget.lot;
    final messenger = ScaffoldMessenger.of(context);

    /*
     * Une confirmation, parce que le geste est irréversible.
     *
     * Les points sont débités au moment de la demande, pas à la remise : sans
     * cela, deux personnes pourraient demander le dernier exemplaire en pensant
     * toutes deux l'avoir. Il faut donc le dire avant, pas après.
     */
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          lot.isRaffle ? 'Tenter ma chance ?' : 'Échanger ${lot.name} ?',
        ),
        content: Text(
          lot.isRaffle
              // Dit avant, pas après : une mise perdue reste dépensée, et
              // l'apprendre après coup se vit comme un vol.
              ? '${Fmt.money(lot.pointsPrice, withCurrency: false)} points pour '
                    'une chance de gagner ${lot.name}. Les points misés sont '
                    'dépensés, que vous gagniez ou non.'
              : '${Fmt.money(lot.pointsPrice, withCurrency: false)} points seront '
                    'retirés de votre solde. Un responsable vous contactera pour '
                    'la remise.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(lot.isRaffle ? 'Tenter' : 'Échanger'),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    setState(() => _envoi = true);
    try {
      await ref.read(pointsApiProvider).redeem(lot.id);
      ref.invalidate(shopProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            lot.isRaffle
                ? 'Chance enregistrée pour ${lot.name}. Résultat au tirage.'
                : 'Demande enregistrée. Un responsable vous contactera pour '
                      '${lot.name}.',
          ),
        ),
      );
    } on PointsApiException catch (erreur) {
      // Le message du serveur est déjà écrit pour l'élève — « Il vous manque
      // des points pour ce lot. » — on le relaie tel quel.
      messenger.showSnackBar(SnackBar(content: Text(erreur.message)));
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }
}

/// Mettre un lot de côté.
///
/// Le cœur s'allume **avant** la réponse du serveur, et revient en arrière si
/// elle échoue. Attendre l'aller-retour donnerait un bouton qui ne réagit pas
/// pendant une seconde sur une connexion guinéenne, et on appuie alors deux
/// fois — ce que les verbes PUT/DELETE encaissent sans dommage, contrairement à
/// une bascule.
class _Coeur extends ConsumerStatefulWidget {
  const _Coeur({required this.lot});

  final ShopItem lot;

  @override
  ConsumerState<_Coeur> createState() => _CoeurState();
}

class _CoeurState extends ConsumerState<_Coeur> {
  bool? _optimiste;

  @override
  Widget build(BuildContext context) {
    final actif = _optimiste ?? widget.lot.favorite;

    return IconButton(
      tooltip: actif ? 'Retirer de mes favoris' : 'Mettre de côté',
      visualDensity: VisualDensity.compact,
      onPressed: () async {
        final vise = !actif;
        // Pris avant l'attente : après, `context` peut avoir disparu.
        final messenger = ScaffoldMessenger.of(context);
        setState(() => _optimiste = vise);
        try {
          await ref
              .read(pointsApiProvider)
              .setFavorite(widget.lot.id, on: vise);
          ref.invalidate(favoritesProvider);
        } on PointsApiException catch (erreur) {
          if (!mounted) return;
          setState(() => _optimiste = !vise);
          messenger.showSnackBar(SnackBar(content: Text(erreur.message)));
        }
      },
      icon: Icon(
        actif ? Icons.favorite : Icons.favorite_border,
        // Rouge seulement quand il est allumé : une rangée de cœurs colorés sur
        // des cartes déjà illustrées ferait un écran criard.
        color: actif ? AppColors.danger : AppColors.textSecondary,
        size: 22,
      ),
    );
  }
}

final favoritesProvider = FutureProvider<List<ShopItem>>(
  (ref) => ref.watch(pointsApiProvider).favorites(),
);

final shopProvider = FutureProvider<Shop>(
  (ref) => ref.watch(pointsApiProvider).shop(),
);
