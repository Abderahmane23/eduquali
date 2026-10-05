import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/repositories/promotions_repository.dart';
import '../../../domain/usecases/subscription_rules.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/kit.dart';
import '../billing/subscription_sheet.dart';

/// Configurer une promotion d'établissement (note du 21/09).
///
/// Titre, vidéos et images, puis mise en ligne. Ouverte par la formule
/// Master depuis le 25/09 — elle coûtait 50 crédits, et le système de
/// crédits a été retiré au profit des trois formules.
class PromotionFormPage extends ConsumerStatefulWidget {
  const PromotionFormPage({super.key});

  @override
  ConsumerState<PromotionFormPage> createState() => _PromotionFormState();
}

class _PromotionFormState extends ConsumerState<PromotionFormPage> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  final List<String> _media = [];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  /// La formule du compte, expiration comprise.
  SubscriptionPlan get _plan {
    final session = ref.watch(currentSessionProvider);
    return effectivePlan(
      SubscriptionPlan.fromCode(session?.plan),
      session?.planRenewsAt,
      DateTime.now(),
    );
  }

  /// Ce qui s'écrit au-dessus du bouton quand rien ne bloque.
  ///
  /// Dire « comprise dans Master » avant d'appuyer vaut mieux que de le
  /// découvrir sur une feuille au moment de valider un formulaire rempli.
  String get _note => allows(_plan, PaidFeature.promotion)
      ? 'Comprise dans votre formule Master · 30 jours en ligne'
      : 'Comprise dans la formule Master · 30 jours en ligne';

  String? get _blocking {
    if (_title.text.trim().isEmpty) return 'Donnez un titre à votre annonce.';
    if (_media.isEmpty) return 'Ajoutez au moins une image ou une vidéo.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Faire ma promotion'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: AppSpacing.page,
                children: [
                  // L'accroche du 21/09, telle quelle : c'est la promesse
                  // que l'établissement achète.
                  AppCard(
                    color: AppColors.infoSurface,
                    borderColor: AppColors.infoSurface,
                    child: Text(
                      'Montrez votre établissement à plus de '
                      '${AppConstants.promotionReach} parents et étudiants.',
                      style: text.titleSmall,
                    ),
                  ),
                  const Gap(AppSpacing.xl),

                  TextField(
                    controller: _title,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Titre',
                      hintText: 'Inscriptions ouvertes pour la rentrée',
                    ),
                  ),
                  const Gap(AppSpacing.lg),
                  TextField(
                    controller: _message,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Votre message (facultatif)',
                      hintText: 'Ce qui distingue votre établissement',
                    ),
                  ),

                  const Gap(AppSpacing.xl),
                  Text('Vidéos et images', style: text.titleSmall),
                  const Gap(AppSpacing.sm),
                  for (var i = 0; i < _media.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.perm_media_outlined,
                              size: 20,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(child: Text(_media[i])),
                            IconButton(
                              onPressed: () =>
                                  setState(() => _media.removeAt(i)),
                              icon: const Icon(Icons.close, size: 18),
                              tooltip: 'Retirer',
                            ),
                          ],
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(
                            () => _media.add('photo_${_media.length + 1}.jpg'),
                          ),
                          icon: const Icon(Icons.image_outlined, size: 18),
                          label: const Text('Image'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(
                            () => _media.add('video_${_media.length + 1}.mp4'),
                          ),
                          icon: const Icon(Icons.videocam_outlined, size: 18),
                          label: const Text('Vidéo'),
                        ),
                      ),
                    ],
                  ),

                  if (_error != null) ...[
                    const Gap(AppSpacing.lg),
                    InfoBanner(
                      message: _error!,
                      tone: StatusTone.danger,
                      icon: Icons.error_outline,
                    ),
                  ],
                ],
              ),
            ),

            // Ce qui manque encore, ou ce que la mise en ligne suppose :
            // l'apprendre en appuyant fait reculer.
            StickyActionBar(
              label: 'Mettre en ligne',
              busy: _busy,
              note: _blocking ?? _note,
              onPressed: _blocking != null ? null : _publish,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _publish() async {
    final session = ref.read(currentSessionProvider);
    final institutionId = session?.institutionId;
    if (session == null || institutionId == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(promotionsRepositoryProvider)
          .publish(
            institutionId: institutionId,
            ownerId: session.userId,
            title: _title.text,
            message: _message.text,
            mediaPaths: _media,
          );
      refreshPromotions(ref);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Votre promotion est en ligne.')),
      );
      // Droit sur ses chiffres, et non retour au formulaire vide : la
      // phrase « en ligne » ne dit pas ce que la promotion rapporte, et
      // c'est la seule question qui reste.
      context.go(Routes.institutionPromotions);
    } on PromotionNeedsPlan catch (refus) {
      // Un refus qui se rattrape : on propose la formule plutot que
      // d'afficher une phrase et de laisser la personne devant un
      // formulaire rempli. S'abonner relance la mise en ligne toute seule.
      if (!mounted) return;
      final souscrit = await showSubscriptionSheet(
        context,
        required: refus.required,
        because:
            'La mise en avant fait partie de la formule Master : votre '
            'établissement apparaît auprès des familles qui cherchent une '
            'école près de chez elles.',
      );
      if (souscrit && mounted) {
        setState(() => _busy = false);
        return _publish();
      }
    } on PromotionException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
