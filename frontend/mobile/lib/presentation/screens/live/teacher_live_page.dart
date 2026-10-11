import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/remote/live_api.dart';
import '../../providers/core_providers.dart';
import '../../router/app_router.dart';
import '../../widgets/common.dart';
import '../../widgets/kit.dart';

/// Démarrer un cours : la classe, qui est là, et comment faire venir le reste.
///
/// --- Ce que le professeur regarde avant d'ouvrir -----------------------
///
/// Une seule question : *est-ce que je commence ?* Elle se répond avec deux
/// nombres — combien sont attendus, combien sont entrés — et une liste de ceux
/// qui manquent. Tout le reste de l'écran existe pour agir sur cette liste.
///
/// --- Prévenir : une place, ou toutes -----------------------------------
///
/// Le bouton global sert le cas courant (« on commence ») ; le bouton par ligne
/// sert celui qui traîne. Les deux écrivent dans `notifications`, que seul le
/// serveur alimente.
///
/// **Aucun SMS.** Chaque message coûte, et prévenir quinze familles deux fois
/// par séance mangerait la marge du cours. Le jour où le SMS existera, ce sera
/// une décision avec un budget.
class TeacherLivePage extends ConsumerStatefulWidget {
  const TeacherLivePage({super.key});

  @override
  ConsumerState<TeacherLivePage> createState() => _TeacherLivePageState();
}

class _TeacherLivePageState extends ConsumerState<TeacherLivePage> {
  TeacherSession? _choisie;
  Roster? _classe;
  String? _erreur;
  bool _charge = false;
  bool _envoi = false;
  Timer? _rafraichir;

  @override
  void initState() {
    super.initState();
    _charger();
    // La présence change pendant qu'on regarde : quelqu'un entre, quelqu'un
    // part. Vingt secondes, comme le rattrapage des points de contrôle.
    _rafraichir = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && _choisie != null) _relireClasse(_choisie!.id);
    });
  }

  @override
  void dispose() {
    _rafraichir?.cancel();
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final seances = await ref.read(liveApiProvider).teacherSessions();
      if (!mounted) return;
      // Celle qu'on peut ouvrir maintenant, sinon la prochaine : c'est celle
      // qu'on vient chercher dans les deux cas.
      final maintenant = DateTime.now();
      final ouvrable = seances
          .where((s) => s.canOpenAt(maintenant))
          .firstOrNull;
      setState(() {
        _choisie = ouvrable ?? seances.firstOrNull;
        _charge = true;
      });
      if (_choisie != null) await _relireClasse(_choisie!.id);
    } on LiveApiException catch (cause) {
      if (!mounted) return;
      setState(() {
        _erreur = cause.message;
        _charge = true;
      });
    }
  }

  Future<void> _relireClasse(String sessionId) async {
    try {
      final classe = await ref.read(liveApiProvider).roster(sessionId);
      if (mounted) setState(() => _classe = classe);
    } catch (_) {
      // La classe est un confort : son échec ne doit pas empêcher d'ouvrir la
      // salle, qui est le geste principal de l'écran.
    }
  }

  Future<void> _prevenir({List<String>? places, bool tous = false}) async {
    final seance = _choisie;
    if (seance == null || _envoi) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _envoi = true);
    try {
      final combien = await ref
          .read(liveApiProvider)
          .notifySession(seance.id, enrolmentIds: places, all: tous);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            combien == 0
                ? 'Personne à prévenir pour le moment.'
                : '$combien famille${combien > 1 ? 's' : ''} prévenue'
                      '${combien > 1 ? 's' : ''}.',
          ),
        ),
      );
    } on LiveApiException catch (cause) {
      messenger.showSnackBar(SnackBar(content: Text(cause.message)));
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seance = _choisie;
    final classe = _classe;
    final maintenant = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Mon cours en direct'),
      ),
      body: SafeArea(
        child: !_charge
            ? const Center(child: CircularProgressIndicator())
            : seance == null
            ? Padding(
                padding: const EdgeInsets.all(AppSpacing.screenH),
                child: EmptyState(
                  icon: Icons.sensors_off_outlined,
                  title: 'Aucune séance programmée',
                  message:
                      _erreur ??
                      'Publiez votre premier cours : choisissez la matière, la '
                          'classe, le prix et vos créneaux. Les séances se '
                          'programment ensuite toutes seules.',
                  actionLabel: 'Publier un cours',
                  onAction: () => context.push(Routes.publishCourse),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.md,
                  AppSpacing.screenH,
                  AppSpacing.xxl,
                ),
                children: [
                  _Entete(seance: seance, classe: classe),

                  const Gap(AppSpacing.lg),
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: seance.canOpenAt(maintenant)
                          ? () => context.push(Routes.liveRoom(seance.id))
                          : null,
                      icon: const Icon(Icons.videocam_rounded),
                      label: Text(
                        seance.status == 'LIVE'
                            ? 'Reprendre le cours'
                            : 'Démarrer le cours',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (!seance.canOpenAt(maintenant)) ...[
                    const Gap(AppSpacing.sm),
                    // Dire pourquoi le bouton est gris. Un bouton inerte sans
                    // explication se lit comme une panne.
                    MetaText(
                      'La salle ouvre quinze minutes avant le début, à '
                      '${Fmt.time(seance.startsAt.subtract(const Duration(minutes: 15)))}.',
                    ),
                  ],

                  const Gap(AppSpacing.xl),
                  KitSectionTitle(
                    title: 'Qui est attendu',
                    actionLabel: (classe?.absents.isEmpty ?? true)
                        ? null
                        : 'Prévenir tout le monde',
                    onAction: (classe?.absents.isEmpty ?? true)
                        ? null
                        : () => _prevenir(tous: true),
                  ),

                  if (classe == null)
                    const KitEmpty(
                      icon: Icons.group_outlined,
                      message: 'Liste en cours de lecture…',
                    )
                  else if (classe.entries.isEmpty)
                    KitEmpty(
                      icon: Icons.group_outlined,
                      message:
                          'Aucune place vendue pour cette séance. Invitez des '
                          'familles que vous connaissez déjà.',
                      actionLabel: 'Ouvrir mon répertoire',
                      onAction: _ouvrirRepertoire,
                    )
                  else ...[
                    for (final eleve in classe.entries)
                      ListItemCard(
                        leading: InitialsTile(
                          name: eleve.name,
                          tone: eleve.present
                              ? StatusTone.success
                              : StatusTone.neutral,
                        ),
                        title: eleve.name,
                        subtitle: eleve.present
                            ? 'En salle depuis ${eleve.minutes} min'
                            : 'Pas encore entré',
                        trailing: eleve.present
                            ? const Icon(
                                Icons.check_circle,
                                color: AppColors.success,
                                size: 20,
                              )
                            : TextButton(
                                onPressed: _envoi
                                    ? null
                                    : () => _prevenir(
                                        places: [eleve.enrolmentId],
                                      ),
                                child: const Text('Prévenir'),
                              ),
                      ),
                  ],

                  const Gap(AppSpacing.lg),
                  // Publier un cours : la porte qui manquait. Sans elle, un
                  // professeur ne pouvait pas creer son propre cours, et la
                  // grille restait vide faute d'offre.
                  OutlinedButton.icon(
                    onPressed: () => context.push(Routes.publishCourse),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Publier un nouveau cours'),
                  ),
                  const Gap(AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: _ouvrirRepertoire,
                    icon: const Icon(Icons.contacts_outlined),
                    label: const Text('Inviter depuis mon répertoire'),
                  ),
                ],
              ),
      ),
    );
  }

  void _ouvrirRepertoire() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _Repertoire(),
    );
  }
}

class _Entete extends StatelessWidget {
  const _Entete({required this.seance, required this.classe});

  final TeacherSession seance;
  final Roster? classe;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  seance.label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (seance.status == 'LIVE')
                const StatusPill(label: 'EN DIRECT', tone: StatusTone.danger),
            ],
          ),
          const Gap(AppSpacing.xs),
          MetaText('${Fmt.time(seance.startsAt)} – ${Fmt.time(seance.endsAt)}'),
          const Gap(AppSpacing.md),
          // Les deux nombres qui répondent à « est-ce que je commence ? ».
          //
          // Écrits à la main plutôt qu'avec `HeroStatStrip` : celui-ci se
          // dessine sur le dégradé de l'en-tête, avec des couleurs claires sur
          // fond sombre. Posé dans une carte blanche, il serait illisible.
          Row(
            children: [
              _Compte(
                value: '${classe?.present ?? 0}',
                label: 'en salle',
                tone: (classe?.present ?? 0) > 0
                    ? AppColors.success
                    : AppColors.textPrimary,
              ),
              _Compte(
                value: '${classe?.expected ?? seance.seatsTaken}',
                label: 'attendus',
              ),
              _Compte(value: '${seance.seats}', label: 'places'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Compte extends StatelessWidget {
  const _Compte({required this.value, required this.label, this.tone});

  final String value;
  final String label;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: tone ?? AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Le répertoire : les familles que le professeur connaît déjà.
///
/// **Rien n'est stocké.** La liste est dérivée des relations qui existent —
/// séances suivies, contrats en cours — et disparaît d'elle-même quand la
/// relation s'arrête. Une table de contacts serait une copie permanente des
/// coordonnées d'enfants, et une copie diverge : le contrat se termine, la ligne
/// reste. Voir `/live/teacher/contacts`.
class _Repertoire extends ConsumerWidget {
  const _Repertoire();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(teacherContactsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          0,
          AppSpacing.screenH,
          AppSpacing.lg,
        ),
        child: contacts.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Répertoire indisponible',
              message: '$error',
            ),
          ),
          data: (liste) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mon répertoire',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const Gap(AppSpacing.xs),
              const MetaText(
                'Les familles que vous connaissez déjà : séances suivies et '
                'contrats en cours.',
              ),
              const Gap(AppSpacing.lg),
              if (liste.isEmpty)
                const KitEmpty(
                  icon: Icons.contacts_outlined,
                  message:
                      'Votre répertoire se remplit tout seul : une famille y '
                      'entre dès qu’elle suit une de vos séances ou signe un '
                      'contrat avec vous.',
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: liste.length,
                    itemBuilder: (context, i) => ListItemCard(
                      leading: InitialsTile(name: liste[i].name),
                      title: liste[i].name,
                      // D'où je la connais : une liste de noms sans contexte
                      // ne dit pas à qui l'on écrit.
                      subtitle: liste[i].origin,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

final teacherContactsProvider = FutureProvider<List<TeacherContact>>(
  (ref) => ref.watch(liveApiProvider).teacherContacts(),
);
