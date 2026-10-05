import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/remote/live_api.dart';
import '../../providers/core_providers.dart';
import '../../router/app_router.dart';

/// Le grand bouton « cours en direct » de l'accueil du professeur.
///
/// --- Pourquoi un seul bouton pour trois situations ----------------------
///
/// Un professeur arrive sur cet écran dans trois états : il a un cours à
/// ouvrir maintenant, il en a un plus tard, ou il n'en a aucun. Trois boutons
/// distincts obligeraient à choisir ; un seul, dont le sous-titre dit lequel
/// des trois est vrai, se touche sans réfléchir. L'écran derrière raconte le
/// reste.
///
/// Il reste donc touchable même quand la salle n'ouvre pas : on y va aussi
/// pour voir qui a payé et prévenir ceux qui manquent, ce qui se fait
/// justement *avant* le début.
///
/// --- Pourquoi rien ne s'affiche en cas d'échec --------------------------
///
/// La liste vient du réseau. Tant qu'elle n'est pas là, la carte montre son
/// libellé neutre plutôt qu'un vide : une connexion guinéenne met parfois
/// plusieurs secondes, et un accueil qui se réorganise sous le doigt fait
/// toucher autre chose que ce qu'on visait.
class StartLiveButton extends ConsumerStatefulWidget {
  const StartLiveButton({super.key});

  @override
  ConsumerState<StartLiveButton> createState() => _StartLiveButtonState();
}

class _StartLiveButtonState extends ConsumerState<StartLiveButton> {
  TeacherSession? _prochaine;
  bool _lu = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final seances = await ref.read(liveApiProvider).teacherSessions();
      if (!mounted) return;
      final maintenant = DateTime.now();
      setState(() {
        _prochaine =
            seances.where((s) => s.canOpenAt(maintenant)).firstOrNull ??
            seances.firstOrNull;
        _lu = true;
      });
    } catch (_) {
      // Le bouton garde son libellé neutre : il mène à un écran qui saura dire
      // ce qui ne va pas, avec le message du serveur.
      if (mounted) setState(() => _lu = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seance = _prochaine;
    final maintenant = DateTime.now();
    final ouvrable = seance != null && seance.canOpenAt(maintenant);

    final sousTitre = !_lu
        ? 'Vos séances, vos élèves, vos invitations'
        : seance == null
        ? 'Aucune séance programmée pour le moment'
        : ouvrable
        ? '${seance.label} · la salle est ouverte'
        : 'Prochaine séance ${Fmt.relative(seance.startsAt)} '
              'à ${Fmt.time(seance.startsAt)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Material(
        color: ouvrable ? AppColors.danger : AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => context.push(Routes.teacherLive),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            child: Row(
              children: [
                // Le point qui bat quand c'est en direct : c'est le signal que
                // tout le monde reconnaît, et il distingue d'un coup d'œil
                // « ça tourne » de « c'est prévu ».
                if (ouvrable)
                  const _Pulsation()
                else
                  const Icon(
                    Icons.videocam_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ouvrable
                            ? 'Reprendre le direct'
                            : 'Démarrer un cours en direct',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sousTitre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xDDFFFFFF),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Le point rouge qui respire. Deux secondes par cycle : plus court, il
/// clignote et agace sur un écran qu'on garde ouvert pendant le cours.
class _Pulsation extends StatefulWidget {
  const _Pulsation();

  @override
  State<_Pulsation> createState() => _PulsationState();
}

class _PulsationState extends State<_Pulsation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: 1, end: 0.35).animate(_ctrl),
    child: Container(
      width: 14,
      height: 14,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    ),
  );
}
