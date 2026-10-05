import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Un message de la salle, le temps de la séance.
///
/// Éphémère à dessein : rien n'est écrit en base. Un fil de discussion de cours
/// se lit pendant le cours ; le conserver créerait des lignes que personne ne
/// relit, à modérer et à purger — et pour une classe d'adolescents, un
/// historique conservé est une responsabilité, pas une fonction.
class LiveChatMessage {
  const LiveChatMessage({
    required this.author,
    required this.text,
    required this.at,
    this.fromTeacher = false,
    this.mine = false,
  });

  final String author;
  final String text;
  final DateTime at;
  final bool fromTeacher;
  final bool mine;
}

/// Le fil de discussion, par-dessus la vidéo.
///
/// --- Pourquoi par-dessus et non à côté ----------------------------------
///
/// Sur un téléphone tenu à la verticale, une colonne de discussion à côté de la
/// vidéo réduit les deux à rien. Les applications qui diffusent en direct ont
/// toutes convergé vers la même réponse : le fil flotte au-dessus de l'image,
/// sur un dégradé sombre, et l'image reste entière dessous.
///
/// --- Les choix de lisibilité --------------------------------------------
///
///   * **Un dégradé, pas un aplat.** Une bande opaque couperait la vidéo en
///     deux ; le dégradé rend le texte lisible en haut du fil et laisse l'image
///     intacte en bas.
///   * **Chaque message porte sa propre pastille sombre.** Sur une vidéo
///     claire — un tableau blanc, une feuille — du texte blanc sans fond
///     disparaît complètement.
///   * **Les derniers en bas**, comme partout ailleurs, et la liste se tient
///     collée au bas : on suit sans toucher.
///   * **Douze messages au maximum.** Au-delà, le fil masque la séance qu'il
///     commente.
class LiveChatOverlay extends StatelessWidget {
  const LiveChatOverlay({
    super.key,
    required this.messages,
    required this.onSend,
    this.canWrite = true,
  });

  final List<LiveChatMessage> messages;
  final ValueChanged<String> onSend;

  /// Faux quand la séance ne permet pas d'écrire — avant l'entrée, après la
  /// fin. Le champ disparaît alors au lieu d'accepter un texte qui ne partira
  /// jamais.
  final bool canWrite;

  static const int visibles = 12;

  @override
  Widget build(BuildContext context) {
    final derniers = messages.length > visibles
        ? messages.sublist(messages.length - visibles)
        : messages;

    return IgnorePointer(
      // Seule la zone de saisie intercepte le toucher : le reste laisse passer
      // les gestes vers la vidéo — plein écran, double-tap — comme sur
      // n'importe quel lecteur.
      ignoring: false,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: IgnorePointer(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xxl,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0x73000000)],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final message in derniers)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _Bulle(message: message),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (canWrite) _Saisie(onSend: onSend),
        ],
      ),
    );
  }
}

class _Bulle extends StatelessWidget {
  const _Bulle({required this.message});

  final LiveChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          // Assez sombre pour tenir sur un tableau blanc, assez transparent
          // pour qu'on voie ce qui s'écrit dessous.
          color: const Color(0x8C000000),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: RichText(
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: const TextStyle(fontSize: 13.5, color: Colors.white),
              children: [
                TextSpan(
                  text: message.author,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    // Le professeur se distingue d'un coup d'œil : dans une
                    // classe de quinze, sa consigne ne doit pas se perdre entre
                    // deux « bonjour ».
                    color: message.fromTeacher
                        ? AppColors.warning
                        : message.mine
                        ? Colors.white
                        : const Color(0xCCFFFFFF),
                  ),
                ),
                const TextSpan(text: '  '),
                TextSpan(text: message.text),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Saisie extends StatefulWidget {
  const _Saisie({required this.onSend});

  final ValueChanged<String> onSend;

  @override
  State<_Saisie> createState() => _SaisieState();
}

class _SaisieState extends State<_Saisie> {
  final _champ = TextEditingController();

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  void _envoyer() {
    final texte = _champ.text.trim();
    if (texte.isEmpty) return;
    widget.onSend(texte);
    _champ.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        // Au-dessus du clavier quand il s'ouvre : sinon on écrit derrière.
        AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _champ,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _envoyer(),
              maxLength: 200,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Écrire à la classe…',
                hintStyle: const TextStyle(color: Color(0x99FFFFFF)),
                counterText: '',
                isDense: true,
                filled: true,
                fillColor: const Color(0x8C000000),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.filled(
            onPressed: _envoyer,
            icon: const Icon(Icons.send_rounded, size: 20),
            tooltip: 'Envoyer',
          ),
        ],
      ),
    );
  }
}
