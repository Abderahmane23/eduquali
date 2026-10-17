import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../domain/entities/live_models.dart';
import '../../providers/core_providers.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/kit.dart';
import '../../widgets/marque.dart';

/// La preuve de présence : l'écran que le parent reçoit après chaque séance.
///
/// --- Pourquoi cet écran existe -------------------------------------------
///
/// C'est le cœur de la promesse : il paie, et il sait. Un parent qui paie un
/// répétiteur ne sait pas s'il est venu mardi, ni ce qui s'est fait pendant
/// l'heure. Cet écran répond aux deux, avec un chiffre que personne n'a
/// déclaré.
///
/// --- Ce qu'il montre, et dans cet ordre ---------------------------------
///
///   1. **la réponse**, en une phrase : « Aïssatou était là. » Les deux
///      derniers mots sont surlignés — c'est le geste de la marque, et c'est
///      la seule chose qu'on vient lire ;
///   2. « Présente ! » en écriture de cahier, une fois ;
///   3. les minutes en grand, puis la ligne du temps qui dit **quand** ;
///   4. trois faits, pas plus : l'heure d'arrivée, les points de contrôle,
///      ce qui a été travaillé ;
///   5. la mention « Compté par EduQuali, pas déclaré par l'élève » ;
///   6. **un seul bouton** : réserver la séance suivante. C'est le moment où
///      le parent a confiance.
///
/// --- Ce qu'il ne montre pas ---------------------------------------------
///
/// Ni note, ni classement, ni comparaison avec les autres élèves. La charte
/// l'écrit comme un interdit, et la raison tient en une ligne : EduQuali
/// promet ce qu'il mesure — un professeur présent, quinze places, des minutes
/// comptées — et rien d'autre.
class PresenceProofPage extends ConsumerStatefulWidget {
  const PresenceProofPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<PresenceProofPage> createState() => _PresenceProofPageState();
}

class _PresenceProofPageState extends ConsumerState<PresenceProofPage> {
  PresenceProof? _preuve;
  String? _erreur;
  bool _charge = false;

  @override
  void initState() {
    super.initState();
    _lire();
  }

  Future<void> _lire() async {
    try {
      final preuve = await ref
          .read(liveApiProvider)
          .presenceProof(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _preuve = preuve;
        _charge = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erreur =
            'La preuve de présence n’a pas pu être lue. '
            'Réessayez dans un instant.';
        _charge = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preuve = _preuve;

    return Scaffold(
      appBar: AppBar(title: const Text('La séance')),
      body: SafeArea(
        child: !_charge
            ? const Center(child: CircularProgressIndicator())
            : preuve == null
            ? Padding(
                padding: const EdgeInsets.all(AppSpacing.espace4),
                child: InfoBanner(
                  message: _erreur ?? 'Séance introuvable.',
                  tone: StatusTone.warning,
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.espace4,
                  AppSpacing.espace4,
                  AppSpacing.espace4,
                  AppSpacing.espace6,
                ),
                children: [
                  _Reponse(preuve: preuve),
                  const Gap(AppSpacing.espace5),
                  if (preuve.etaitLa) ...[
                    _Minutes(preuve: preuve),
                    const Gap(AppSpacing.espace5),
                  ],
                  _TroisFaits(preuve: preuve),
                  const Gap(AppSpacing.espace4),
                  const _Mention(),
                  const Gap(AppSpacing.espace6),
                  _Suite(preuve: preuve),
                ],
              ),
      ),
    );
  }
}

/// La réponse, en une phrase.
class _Reponse extends StatelessWidget {
  const _Reponse({required this.preuve});

  final PresenceProof preuve;

  @override
  Widget build(BuildContext context) {
    final qui = preuve.childName ?? 'Vous';
    final texte = Theme.of(context).textTheme;

    /*
     * « Aïssatou était là. » — les deux derniers mots surlignés.
     *
     * Pour un compte qui suit pour lui-même, « Vous étiez là » : la charte
     * vouvoie tout le monde, et une phrase à la troisième personne sur son
     * propre écran se lit comme un dossier.
     */
    final verbe = preuve.childName == null ? 'étiez là.' : 'était là.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (preuve.etaitLa)
          Affiche(
            avant: '$qui ',
            surligne: verbe,
            style: texte.headlineMedium,
          )
        else
          /*
           * Une absence : pas de surlignage.
           *
           * La charte est explicite — « en cas d'absence : pas de
           * surlignage ». Le signe dit « ce qui compte » ; l'employer sur une
           * absence en ferait un signe d'échec, et il perdrait son sens
           * partout ailleurs.
           *
           * La phrase reste neutre, et la suite propose le rattrapage.
           */
          Text(
            preuve.childName == null
                ? 'Vous n’étiez pas en cours.'
                : '$qui n’était pas en cours.',
            style: texte.headlineMedium,
          ),

        // « Présente ! », une fois par écran, légèrement penchée.
        if (preuve.etaitLa) ...[
          const Gap(AppSpacing.espace3),
          Annotation(_accord(preuve.childName)),
        ],
      ],
    );
  }

  /// « Présent ! » ou « Présente ! ».
  ///
  /// On ne connaît pas le genre de l'élève — l'application ne le demande
  /// nulle part, et c'est bien ainsi. Le mot reste donc au masculin, qui est
  /// la forme non marquée en français, plutôt que d'inventer une donnée pour
  /// accorder un adjectif.
  static String _accord(String? prenom) => 'Présent !';
}

/// Les minutes, et la ligne du temps qui dit quand.
class _Minutes extends StatelessWidget {
  const _Minutes({required this.preuve});

  final PresenceProof preuve;

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;

    return KitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /*
           * Le chiffre d'abord, puis l'unité.
           *
           * « 52 minutes sur 60 » se vérifie et se raconte le soir ; « taux
           * d'assiduité 87 % » demande de croire un calcul. La charte en fait
           * une règle, et c'est celle qui distingue cet écran d'un bulletin.
           */
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${preuve.minutesAttended}',
                style: texte.displayMedium,
              ),
              const Gap(AppSpacing.espace2),
              Text(
                'minutes sur ${preuve.durationMinutes}',
                style: texte.titleMedium,
              ),
            ],
          ),
          const Gap(AppSpacing.espace4),
          LigneDuTemps(
            minutesSuivies: preuve.minutesAttended,
            minutesTotales: preuve.durationMinutes,
          ),
        ],
      ),
    );
  }
}

/// Trois faits, pas plus.
class _TroisFaits extends StatelessWidget {
  const _TroisFaits({required this.preuve});

  final PresenceProof preuve;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      /*
       * L'heure d'arrivée, sans reproche.
       *
       * « Un retard se dit avec l'heure d'arrivée. » On écrit l'heure, et
       * l'on s'arrête là : ni « en retard », ni le nombre de minutes perdues
       * au début. Le parent sait lire une heure.
       */
      if (preuve.joinedAt != null)
        _Fait(
          icone: Icons.schedule_rounded,
          libelle: 'Arrivé à ${Fmt.time(preuve.joinedAt!)}',
        ),

      /*
       * Les points de contrôle.
       *
       * Toutes les quinze minutes, le professeur demande si tout le monde
       * suit. Le nombre de réponses dit mieux que les minutes si l'élève
       * était devant son téléphone ou seulement connecté — c'est ce qui
       * sépare une présence d'un onglet ouvert.
       */
      if (preuve.checkpointsTotal > 0)
        _Fait(
          icone: Icons.task_alt_rounded,
          libelle:
              '${preuve.checkpointsAnswered} '
              'réponse${preuve.checkpointsAnswered > 1 ? 's' : ''} '
              'sur ${preuve.checkpointsTotal} '
              'point${preuve.checkpointsTotal > 1 ? 's' : ''} de contrôle',
        ),

      // Ce qui a été travaillé : le titre que le professeur a donné à son
      // cours, et la matière.
      if (preuve.title != null)
        _Fait(
          icone: Icons.menu_book_rounded,
          libelle: [
            preuve.title,
            preuve.subject,
            preuve.level,
          ].whereType<String>().join(' · '),
        ),
    ],
  );
}

class _Fait extends StatelessWidget {
  const _Fait({required this.icone, required this.libelle});

  final IconData icone;
  final String libelle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.espace3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 20, color: AppColors.crayon),
        const Gap(AppSpacing.espace3),
        Expanded(
          child: Text(libelle, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    ),
  );
}

/// La mention qui fait tenir tout le reste.
class _Mention extends StatelessWidget {
  const _Mention();

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(Icons.verified_outlined, size: 18, color: AppColors.crayon),
      const Gap(AppSpacing.espace2),
      Expanded(
        /*
         * « Compté par EduQuali, pas déclaré par l'élève. »
         *
         * La charte l'impose sur tout écran qui montre des minutes, et c'est
         * la phrase qui rend le chiffre utile : la présence est comptée par
         * le serveur de visioconférence, et un onglet fermé n'envoie pas de
         * départ. Sans elle, « 52 minutes » ne vaut pas mieux qu'une case
         * cochée par l'élève.
         *
         * Elle remplace « Présence certifiée », qui s'annonce au lieu de se
         * prouver.
         */
        child: Text(
          'Compté par EduQuali, pas déclaré par l’élève.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ],
  );
}

/// Un seul bouton.
class _Suite extends StatelessWidget {
  const _Suite({required this.preuve});

  final PresenceProof preuve;

  @override
  Widget build(BuildContext context) {
    /*
     * Deux situations, un seul bouton dans chacune.
     *
     * S'il manque des minutes, le rattrapage passe devant : « une absence se
     * dit avec le moyen de la rattraper ». Sinon, c'est la séance suivante —
     * « c'est le moment où le parent a confiance ».
     *
     * Jamais les deux à la fois : « un bouton principal par écran ».
     */
    if (preuve.aRattraper && preuve.replay != null) {
      final prete = preuve.replay == 'READY';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Les ${preuve.minutesManquees} minutes manquantes sont sur '
            'l’enregistrement.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const Gap(AppSpacing.espace3),
          FilledButton(
            onPressed: prete
                ? () => context.push(Routes.sessionReplay(preuve.sessionId))
                : null,
            child: Text(
              prete
                  ? 'Revoir la séance'
                  : 'Enregistrement en préparation',
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: () => context.push(Routes.live),
          child: const Text('Réserver la séance suivante'),
        ),
        if (preuve.replay == 'READY') ...[
          const Gap(AppSpacing.espace3),
          // En second, et en bouton contour : revoir une séance qu'on a
          // suivie en entier est utile, mais ce n'est pas ce qui fait revenir.
          OutlinedButton(
            onPressed: () => context.push(Routes.sessionReplay(preuve.sessionId)),
            child: const Text('Revoir la séance'),
          ),
        ],
      ],
    );
  }
}
