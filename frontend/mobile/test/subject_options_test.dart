import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/data/local/database/app_database.dart';
import 'package:veriprof/data/local/seed/database_seeder.dart';
import 'package:veriprof/domain/entities/onboarding_spec.dart';
import 'package:veriprof/presentation/controllers/onboarding_flow_controller.dart';
import 'package:veriprof/presentation/providers/core_providers.dart';

/// Les matières proposées à l'inscription d'un professeur.
///
/// Signalé le 24/09 : « Quelles matières enseignez-vous » n'affichait aucune
/// valeur et bloquait l'inscription. Le parcours filtrait sur les classes
/// choisies, mais les matières ne portaient que leur cycle — « lvl_11 » ne
/// figure dans aucun cycle, donc la liste était vide.
///
/// Rien ne le signalait : un filtre qui ne retient rien rend une liste vide,
/// pas une erreur. C'est ce test qui manquait, pas le code.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await DatabaseSeeder(db).seedIfNeeded();
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() {
    container.dispose();
    return db.close();
  });

  Future<List<OnboardingOption>> matieres() =>
      container.read(onboardingOptionsProvider('subjects').future);

  Future<List<OnboardingOption>> pour(List<String> classes) async =>
      OptionsFilter.on(
        'level_ids',
      ).apply(await matieres(), {'level_ids': classes});

  test('choisir une classe laisse des matières', () async {
    // Le cas exact du signalement.
    expect(await pour(['lvl_11']), isNotEmpty);
  });

  test('chaque classe proposée mène à au moins une matière', () async {
    // Une seule classe sans matière suffit à bloquer l'inscription de qui
    // l'a choisie — et elle ne se verrait qu'une fois le parcours essayé.
    final classes = await container.read(
      onboardingOptionsProvider('levels').future,
    );
    expect(classes, isNotEmpty);
    for (final classe in classes) {
      expect(
        await pour([classe.value]),
        isNotEmpty,
        reason: '${classe.label} (${classe.value}) ne propose aucune matière',
      );
    }
  });

  test('le filtre resserre vraiment', () async {
    // S'il rendait tout, le test précédent passerait sans rien prouver.
    //
    // La borne basse compte autant que la haute : écrite en `lessThan` seul,
    // cette assertion était satisfaite par zéro — et zéro est précisément le
    // défaut qu'on cherche à empêcher.
    final toutes = await matieres();
    final college = await pour(['lvl_7']);
    expect(college, isNotEmpty);
    expect(
      college.length,
      lessThan(toutes.length),
      reason: 'le filtre ne retire rien : il ne filtre pas',
    );
  });

  test('deux classes éloignées ne proposent pas la même chose', () async {
    // La vraie propriété à vérifier. `groups` est un sac plat — cycles,
    // profils et classes y cohabitent — donc le *nom* du champ filtré ne
    // restreint pas la comparaison. Ce qui compte n'est pas la famille du
    // groupe, c'est que la dimension « classe » discrimine réellement :
    // sinon le filtre serait décoratif et laisserait tout passer.
    final college = (await pour(['lvl_7'])).map((o) => o.value).toSet();
    final lycee = (await pour(['lvl_11'])).map((o) => o.value).toSet();

    expect(college, isNotEmpty);
    expect(lycee, isNotEmpty);
    expect(
      college,
      isNot(equals(lycee)),
      reason: 'la 7ᵉ et la 11ᵉ proposent exactement les mêmes matières',
    );
    // Et au moins une matière de lycée ne s'enseigne pas au collège.
    expect(lycee.difference(college), isNotEmpty);
  });
}
