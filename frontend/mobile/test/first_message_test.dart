import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/core/utils/contact_masker.dart';
import 'package:veriprof/domain/usecases/first_message.dart';

/// Le premier message d'un fil.
///
/// Il part **sous le nom de celui qui l'envoie**. Il ne peut donc affirmer
/// que ce qu'on sait : c'est tout l'objet de ces tests. Une donnée absente
/// doit retirer la phrase, pas imprimer un gabarit à trous — « Mon enfant est
/// en classe de null » se lit comme un défaut du produit, et c'est la famille
/// qui en porte la faute aux yeux du professeur.
void main() {
  group('Une famille qui réserve', () {
    test('se présente, dit ce qu’elle cherche et pour qui', () {
      final message = composeFirstMessage(
        author: FirstMessageAuthor.parent,
        purpose: FirstMessagePurpose.homeCourse,
        teacherName: 'Mariama Diallo',
        senderName: 'Ousmane Camara',
        subject: 'Mathématiques',
        levelName: 'Terminale',
      );

      expect(message, contains('Bonjour Mariama Diallo,'));
      expect(message, contains('professeur de mathématiques'));
      expect(message, contains('cours à domicile'));
      expect(message, contains('Je suis Ousmane Camara, parent d’élève.'));
      expect(message, contains('Mon enfant est en Terminale.'));
      expect(message, contains('disponibilités'));
    });

    test('tait la classe quand elle est inconnue', () {
      // Le parent peut ne pas avoir renseigné la classe de son enfant : la
      // phrase disparaît, et rien dans le message ne le signale.
      final message = composeFirstMessage(
        author: FirstMessageAuthor.parent,
        purpose: FirstMessagePurpose.homeCourse,
        teacherName: 'Mariama Diallo',
        senderName: 'Ousmane Camara',
        subject: 'Physique',
      );

      expect(message, isNot(contains('enfant est en')));
      expect(message, isNot(contains('null')));
      expect(message, contains('professeur de physique'));
    });

    test('tait la matière quand elle est inconnue', () {
      final message = composeFirstMessage(
        author: FirstMessageAuthor.parent,
        purpose: FirstMessagePurpose.homeCourse,
        teacherName: 'Mariama Diallo',
        senderName: 'Ousmane Camara',
      );

      expect(message, contains('un professeur pour des cours à domicile'));
      expect(message, isNot(contains('professeur de ')));
    });
  });

  group('Un étudiant majeur', () {
    test('parle de lui-même, pas d’un enfant', () {
      // Il *est* l'élève : « mon enfant » serait faux, et il le lirait.
      final message = composeFirstMessage(
        author: FirstMessageAuthor.student,
        purpose: FirstMessagePurpose.homeCourse,
        teacherName: 'Alpha Barry',
        senderName: 'Fatoumata Sow',
        subject: 'Chimie',
        levelName: 'L2',
      );

      expect(message, contains('Je m’appelle Fatoumata Sow.'));
      expect(message, contains('Je suis en L2.'));
      expect(message, isNot(contains('enfant')));
    });
  });

  group('Un établissement', () {
    test('nomme le poste et l’école qu’il représente', () {
      final message = composeFirstMessage(
        author: FirstMessageAuthor.institution,
        purpose: FirstMessagePurpose.job,
        teacherName: 'Sekou Keita',
        senderName: 'Lycée Donka',
        subject: 'Mathématiques',
        jobTitle: 'Professeur de Mathématiques — Terminale',
      );

      expect(message, contains('Je représente Lycée Donka.'));
      expect(
        message,
        contains('poste : Professeur de Mathématiques — Terminale'),
      );
      expect(message, isNot(contains('cours à domicile')));
    });

    test('ne parle jamais de la classe d’un élève', () {
      // Un poste ne se présente pas par la classe d'un enfant. Passer
      // `levelName` ici ne doit rien produire.
      final message = composeFirstMessage(
        author: FirstMessageAuthor.institution,
        purpose: FirstMessagePurpose.job,
        teacherName: 'Sekou Keita',
        senderName: 'Lycée Donka',
        levelName: 'Terminale',
      );

      expect(message, isNot(contains('est en Terminale')));
      expect(message, isNot(contains('Je suis en')));
    });
  });

  group('Ce que le message ne doit pas contenir', () {
    test('aucune coordonnée, sinon il serait caviardé', () {
      // `ContactMasker` masque les numéros dans les messages jusqu'à la mise
      // en relation (§30). Un modèle qui en porterait verrait son propre
      // texte remplacé par des points — l'application se censurant
      // elle-même.
      for (final author in FirstMessageAuthor.values) {
        final message = composeFirstMessage(
          author: author,
          purpose: FirstMessagePurpose.homeCourse,
          teacherName: 'Mariama Diallo',
          senderName: 'Ousmane Camara',
          subject: 'Anglais',
          levelName: '10ème année',
        );
        final result = ContactMasker.mask(message, unlocked: false);
        expect(
          result.masked,
          isFalse,
          reason: 'le message de $author se fait caviarder',
        );
      }
    });

    test('ni gabarit à trous, ni parenthèse laissée ouverte', () {
      // Les gabarits du type « bonjour (nom) » arrivent tels quels chez le
      // destinataire dès qu'une substitution manque.
      final message = composeFirstMessage(
        author: FirstMessageAuthor.parent,
        purpose: FirstMessagePurpose.homeCourse,
        teacherName: 'Mariama Diallo',
        senderName: 'Ousmane Camara',
      );
      for (final suspect in ['(', ')', '{', '}', 'null', 'TODO']) {
        expect(
          message,
          isNot(contains(suspect)),
          reason: 'le message laisse passer « $suspect »',
        );
      }
    });

    test('finit par une question, pas par un constat', () {
      final message = composeFirstMessage(
        author: FirstMessageAuthor.institution,
        purpose: FirstMessagePurpose.job,
        teacherName: 'Sekou Keita',
        senderName: 'Lycée Donka',
      );
      expect(message, contains('?'));
    });
  });
}
