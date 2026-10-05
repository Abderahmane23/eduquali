import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/remote/chat_api.dart';
import '../../../domain/usecases/chat_grouping.dart';
import '../../providers/core_providers.dart';
import '../../providers/session_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/kit.dart';

/// Un groupe, ouvert.
///
/// --- La forme, reprise de Discord mobile ---------------------------------
///
///   * **Des lignes, pas des bulles.** Avatar à gauche, nom et heure en
///     en-tête, texte dessous, sur toute la largeur. Un fil à bulles perd un
///     tiers de l'écran en marges ; ici quinze personnes écrivent et c'est le
///     texte qui doit tenir.
///   * **Les messages consécutifs d'une même personne se regroupent** : on
///     n'écrit son nom qu'une fois. C'est ce qui rend une discussion rapide
///     lisible au lieu d'une colonne de noms répétés.
///   * **Le nom du professeur est en ambre**, comme dans le fil d'une séance
///     en direct. Dans un groupe de quinze, sa réponse ne doit pas se perdre
///     entre deux « bonjour ».
///
/// --- Ce qui est différent d'un salon Discord -----------------------------
///
/// Pas de fichiers, pas de réactions, pas de réponse à un message précis. Rien
/// de tout cela n'était demandé, et chacun porte sa propre question — un
/// envoi de fichier dans un groupe d'enfants n'est pas une fonction d'affichage.
class ChatRoomPage extends ConsumerStatefulWidget {
  const ChatRoomPage({super.key, required this.groupId, this.title});

  final String groupId;
  final String? title;

  @override
  ConsumerState<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends ConsumerState<ChatRoomPage> {
  final _champ = TextEditingController();
  final _defilement = ScrollController();

  List<ChatMessage> _messages = const [];
  String? _erreur;
  bool _charge = false;
  bool _envoi = false;
  Timer? _rafraichir;

  @override
  void initState() {
    super.initState();
    _lire();
    // Pas de temps réel : il faudrait une connexion maintenue, qui coûte de la
    // batterie et tombe sur un réseau guinéen. Dix secondes, et l'écran se
    // referme dès qu'on le quitte.
    _rafraichir = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _lire(silencieux: true),
    );
  }

  @override
  void dispose() {
    _rafraichir?.cancel();
    _champ.dispose();
    _defilement.dispose();
    super.dispose();
  }

  Future<void> _lire({bool silencieux = false}) async {
    try {
      final liste = await ref.read(chatApiProvider).messages(widget.groupId);
      if (!mounted) return;
      // Les messages encore en attente restent affichés : le serveur ne les
      // connaît pas, et les faire disparaître à chaque rafraîchissement
      // donnerait l'impression que l'envoi a échoué.
      final enAttente = [
        for (final m in _messages)
          if (m.pending && !liste.any((s) => s.body == m.body)) m,
      ];
      setState(() {
        _messages = [...liste, ...enAttente];
        _erreur = null;
        _charge = true;
      });
      _versLeBas();
    } on ChatApiException catch (cause) {
      if (!mounted) return;
      setState(() {
        _charge = true;
        // Un échec silencieux ne remplace pas ce qui est déjà lisible : on
        // garde la discussion affichée et on se taira jusqu'au prochain tour.
        if (!silencieux) _erreur = cause.message;
      });
    }
  }

  void _versLeBas() {
    if (!_defilement.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_defilement.hasClients) {
        _defilement.jumpTo(_defilement.position.maxScrollExtent);
      }
    });
  }

  Future<void> _envoyer() async {
    final texte = _champ.text.trim();
    if (texte.isEmpty || _envoi) return;

    final session = ref.read(currentSessionProvider);
    // Posé tout de suite, en attente : sur une connexion lente, un champ qui
    // se vide sans que rien n'apparaisse fait réécrire le même message.
    final provisoire = ChatMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      groupId: widget.groupId,
      authorId: session?.userId ?? '',
      authorName: session?.displayName ?? 'Moi',
      authorRole: session?.role.code ?? 'PARENT',
      body: texte,
      sentAt: DateTime.now(),
      pending: true,
    );

    setState(() {
      _messages = [..._messages, provisoire];
      _envoi = true;
    });
    _champ.clear();
    _versLeBas();

    final messenger = ScaffoldMessenger.of(context);
    try {
      final envoye = await ref
          .read(chatApiProvider)
          .send(widget.groupId, texte);
      if (!mounted) return;
      setState(() {
        _messages = [
          for (final m in _messages)
            if (m.id == provisoire.id)
              m.withId(envoye.id, envoye.sentAt)
            else
              m,
        ];
      });
    } on ChatApiException catch (cause) {
      if (!mounted) return;
      // Retiré de la liste, et le texte rendu au champ : perdre ce qu'on
      // venait d'écrire est la pire façon d'annoncer un échec.
      setState(() {
        _messages = [
          for (final m in _messages)
            if (m.id != provisoire.id) m,
        ];
        _champ.text = texte;
      });
      messenger.showSnackBar(SnackBar(content: Text(cause.message)));
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final moi = ref.watch(currentSessionProvider)?.userId;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Row(
          children: [
            const Icon(Icons.tag, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                widget.title ?? 'Groupe',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: !_charge
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: EmptyState(
                        icon: _erreur == null
                            ? Icons.forum_outlined
                            : Icons.cloud_off_outlined,
                        title: _erreur == null
                            ? 'Personne n’a encore écrit'
                            : 'Discussion indisponible',
                        message:
                            _erreur ??
                            'Posez votre question : tout le groupe la voit, et '
                                'la réponse servira aussi aux autres.',
                      ),
                    )
                  : ListView.builder(
                      controller: _defilement,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final message = _messages[i];
                        final avant = i == 0 ? null : _messages[i - 1];
                        // Même auteur, moins de cinq minutes : on prolonge son
                        // bloc au lieu de réécrire son nom. La règle est pure
                        // et vérifiée dans `chat_grouping.dart`.
                        final suite = prolongeLeBloc(
                          precedentAuteur: avant?.authorId,
                          precedentEnvoi: avant?.sentAt,
                          auteur: message.authorId,
                          envoi: message.sentAt,
                        );
                        return _Ligne(
                          message: message,
                          groupe: suite,
                          moi: moi,
                        );
                      },
                    ),
            ),
            _Saisie(controller: _champ, onSend: _envoyer, occupe: _envoi),
          ],
        ),
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.message, required this.groupe, this.moi});

  final ChatMessage message;

  /// Vrai quand la ligne prolonge le bloc du même auteur.
  final bool groupe;
  final String? moi;

  @override
  Widget build(BuildContext context) {
    const largeurAvatar = 40.0;

    return Padding(
      padding: EdgeInsets.only(top: groupe ? 2 : AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: largeurAvatar,
            // Rien dans la gouttière quand la ligne prolonge un bloc : c'est
            // ce vide qui fait lire les deux lignes comme une seule prise de
            // parole.
            child: groupe
                ? null
                : InitialsTile(
                    name: message.authorName,
                    tone: message.fromTeacher
                        ? StatusTone.warning
                        : StatusTone.neutral,
                  ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!groupe)
                  Row(
                    children: [
                      Text(
                        message.authorId == moi ? 'Vous' : message.authorName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          // L'ambre du professeur, comme dans le fil du direct.
                          color: message.fromTeacher
                              ? AppColors.warning
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (message.fromTeacher) ...[
                        const SizedBox(width: 6),
                        const TagChip(label: 'PROF', tone: StatusTone.warning),
                      ],
                      const SizedBox(width: 6),
                      Text(
                        Fmt.time(message.sentAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        message.body,
                        style: const TextStyle(fontSize: 14.5, height: 1.35),
                      ),
                    ),
                    // L'horloge d'un message pas encore parti. Discret : il
                    // arrivera, et l'écran n'a pas à inquiéter en attendant.
                    if (message.pending)
                      const Padding(
                        padding: EdgeInsets.only(left: 6, top: 2),
                        child: Icon(
                          Icons.schedule,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Saisie extends StatelessWidget {
  const _Saisie({
    required this.controller,
    required this.onSend,
    required this.occupe,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool occupe;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        // Au-dessus du clavier quand il s'ouvre : sinon on écrit derrière.
        AppSpacing.sm + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              minLines: 1,
              maxLines: 4,
              // La même borne que la colonne en base : refuser à l'écran vaut
              // mieux qu'un refus du serveur après l'envoi.
              maxLength: 2000,
              decoration: InputDecoration(
                hintText: 'Écrire au groupe…',
                counterText: '',
                isDense: true,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.filled(
            onPressed: occupe ? null : onSend,
            icon: const Icon(Icons.send_rounded, size: 20),
            tooltip: 'Envoyer',
          ),
        ],
      ),
    );
  }
}
