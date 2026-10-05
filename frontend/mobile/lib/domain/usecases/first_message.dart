/// Le premier message d'un fil, écrit pour celui qui prend contact.
///
/// Demandé le 02/10 : une famille qui réserve, ou une école qui contacte, ne
/// doit pas se retrouver devant un champ vide. Le fil s'ouvre avec ce qu'il
/// y a à dire — qui écrit, ce qu'il cherche, pour qui, et la question qui
/// appelle une réponse.
///
/// **Ce message part sous le nom de celui qui l'envoie.** Il ne peut donc
/// affirmer que ce qu'on sait réellement : chaque phrase est posée à partir
/// d'une donnée, et une donnée absente retire la phrase au lieu d'imprimer
/// un gabarit à trous. « Il est en classe de null » se lit comme un défaut
/// du produit ; la phrase en moins ne se remarque pas.
///
/// Aucune coordonnée n'y figure, et ce n'est pas un oubli : `ContactMasker`
/// masque les numéros dans les messages jusqu'à la mise en relation (§30).
/// Un modèle qui en contiendrait verrait son propre texte caviardé.
library;

/// Qui prend contact.
enum FirstMessageAuthor {
  /// Un parent, pour son enfant.
  parent,

  /// Un étudiant majeur, pour lui-même.
  student,

  /// Un établissement, pour un poste.
  institution,
}

/// De quoi il est question.
enum FirstMessagePurpose {
  /// Des cours à domicile.
  homeCourse,

  /// Un poste à pourvoir.
  job,
}

/// Compose le premier message.
///
/// [teacherName] et [senderName] sont les seuls éléments obligatoires : sans
/// eux le message ne nomme personne et ne vaut pas la peine d'être envoyé.
String composeFirstMessage({
  required FirstMessageAuthor author,
  required FirstMessagePurpose purpose,
  required String teacherName,
  required String senderName,

  /// La matière cherchée, quand elle est connue.
  String? subject,

  /// La classe de l'élève — « Terminale ». Ignorée pour un établissement :
  /// un poste ne se présente pas par la classe d'un élève.
  String? levelName,

  /// L'intitulé du poste, pour un établissement.
  String? jobTitle,
}) {
  final phrases = <String>[];

  phrases.add('Bonjour ${teacherName.trim()},');

  // Ce qu'on cherche. La matière précise l'objet quand on la connaît ; sans
  // elle, la phrase reste vraie, juste moins précise.
  final quoi = switch (purpose) {
    FirstMessagePurpose.homeCourse =>
      subject == null
          ? 'Nous cherchons un professeur pour des cours à domicile.'
          : 'Nous cherchons un professeur de ${subject.toLowerCase()} pour des '
                'cours à domicile.',
    FirstMessagePurpose.job =>
      jobTitle != null
          ? 'Nous recherchons un enseignant pour le poste : $jobTitle.'
          : subject == null
          ? 'Nous recherchons un enseignant à recruter.'
          : 'Nous recherchons un enseignant de ${subject.toLowerCase()} à '
                'recruter.',
  };
  phrases.add(quoi);

  // Qui écrit. Un professeur reçoit des demandes de gens qu'il ne connaît
  // pas : savoir qui lui écrit décide s'il répond.
  phrases.add(switch (author) {
    FirstMessageAuthor.institution => 'Je représente ${senderName.trim()}.',
    FirstMessageAuthor.parent =>
      'Je suis ${senderName.trim()}, parent '
          'd’élève.',
    FirstMessageAuthor.student => 'Je m’appelle ${senderName.trim()}.',
  });

  // La classe, quand elle est connue et qu'elle veut dire quelque chose.
  if (levelName != null && author != FirstMessageAuthor.institution) {
    final classe = levelName.trim();
    if (classe.isNotEmpty) {
      phrases.add(
        author == FirstMessageAuthor.student
            ? 'Je suis en $classe.'
            : 'Mon enfant est en $classe.',
      );
    }
  }

  // La question. Un premier message sans demande n'attend rien, et n'obtient
  // rien.
  phrases.add('Pourriez-vous me dire vos disponibilités ?');
  phrases.add('Merci d’avance.');

  return phrases.join('\n');
}
