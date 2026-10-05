import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/data/local/database/app_database.dart';

/// La migration v16 → v17, sur une base qui contient déjà des messages.
///
/// Rendre `room_id` facultatif oblige SQLite à réécrire la table. Une
/// réécriture ratée ne lève rien : elle rend une table vide, et les
/// conversations de recrutement disparaissent sans bruit sur les téléphones
/// déjà installés — pas sur celui du développeur, qui réinstalle.
void main() {
  test('les messages existants survivent à la réécriture', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // Un espace de recrutement complet, comme sur un téléphone déjà en
    // service.
    await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            id: 'u_t',
            role: 'TEACHER',
            phone: '+224620000101',
          ),
        );
    await db
        .into(db.teachers)
        .insert(TeachersCompanion.insert(id: 't1', userId: 'u_t'));
    await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            id: 'u_i',
            role: 'INSTITUTION',
            phone: '+224620000102',
          ),
        );
    await db
        .into(db.institutions)
        .insert(
          InstitutionsCompanion.insert(
            id: 'i1',
            userId: const Value('u_i'),
            name: 'Lycée Donka',
            type: 'SECONDARY',
            city: 'Conakry',
          ),
        );
    await db
        .into(db.subjects)
        .insert(
          SubjectsCompanion.insert(id: 'sub_math', name: 'Maths', code: 'MATH'),
        );
    await db
        .into(db.jobs)
        .insert(
          JobsCompanion.insert(
            id: 'j1',
            institutionId: 'i1',
            title: 'Professeur de maths',
            subjectId: 'sub_math',
            city: 'Conakry',
            contractType: 'PERMANENT',
          ),
        );
    await db
        .into(db.applications)
        .insert(
          ApplicationsCompanion.insert(id: 'a1', jobId: 'j1', teacherId: 't1'),
        );
    await db
        .into(db.recruitmentRooms)
        .insert(
          RecruitmentRoomsCompanion.insert(
            id: 'r1',
            applicationId: 'a1',
            jobId: 'j1',
            teacherId: 't1',
            institutionId: 'i1',
          ),
        );
    await db
        .into(db.messages)
        .insert(
          MessagesCompanion.insert(
            id: 'm1',
            roomId: const Value('r1'),
            senderId: 'u_t',
            senderRole: 'TEACHER',
            body: 'Bonjour, je suis disponible dès lundi.',
          ),
        );

    final relu = await db.select(db.messages).getSingle();
    expect(relu.body, 'Bonjour, je suis disponible dès lundi.');
    expect(relu.roomId, 'r1');
    // La nouvelle colonne existe et reste vide pour un message de
    // recrutement : c'est ce qui sépare les deux familles de fils.
    expect(relu.conversationId, isNull);
  });

  test('la version du schéma et la migration avancent ensemble', () async {
    // Une table ajoutée sans incrémenter la version ne se crée jamais sur un
    // téléphone déjà installé : l'application démarre puis échoue à la
    // première lecture.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, greaterThanOrEqualTo(17));
    expect(await db.select(db.conversations).get(), isEmpty);
  });
}
