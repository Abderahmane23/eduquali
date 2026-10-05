/// Les créneaux horaires, lus depuis la source partagée.
///
/// --- Pourquoi un fichier et non six constantes Dart ----------------------
///
/// Ces six créneaux sont écrits une fois, dans `shared/scheduling/slots.json`,
/// et `shared/onboarding/sync.mjs` les recopie vers le site et vers
/// `assets/scheduling/`. Les redéclarer ici en constantes les mettrait à quatre
/// endroits : le formulaire du professeur, la grille de l'élève, le générateur
/// de séances du serveur et cette copie.
///
/// Ce dépôt a déjà payé cette erreur : `catalog.json` a existé en deux copies
/// divergentes de onze matières, et la commission est encore écrite à trois
/// endroits.
///
/// --- Le défaut que ce fichier a révélé -----------------------------------
///
/// `assets/scheduling/` recevait `slots.json` depuis le 02/10 **sans être
/// déclaré dans `pubspec.yaml`**. Flutter n'embarque que les dossiers listés :
/// le fichier était donc écrit à chaque synchronisation et absent de l'APK, et
/// le premier appel à [SlotGrid.load] aurait levé chez l'usager. `sync.mjs`
/// vérifie désormais la déclaration.
library;

import 'dart:convert';

import 'package:flutter/services.dart';

const String slotsAssetPath = 'assets/scheduling/slots.json';

/// L'ordre de la semaine, celui dans lequel on lit un emploi du temps.
const List<String> weekOrder = [
  'MON',
  'TUE',
  'WED',
  'THU',
  'FRI',
  'SAT',
  'SUN',
];

class Slot {
  const Slot({
    required this.id,
    required this.label,
    required this.days,
    required this.start,
    required this.end,
  });

  final String id;

  /// « 18 h – 19 h 30 », tel qu'écrit dans le fichier partagé. Affiché sans
  /// retouche : reformater ici ferait diverger l'affichage des deux clients.
  final String label;

  final List<String> days;

  /// « 18:00 ».
  final String start;
  final String end;
}

class SlotGrid {
  const SlotGrid({
    required this.sessionMinutes,
    required this.slots,
    required this.weekdayLabels,
  });

  /// 90 minutes. Lu et non supposé : une séance plus courte — révision avant
  /// examen — ne demandera pas de toucher au code.
  final int sessionMinutes;

  final List<Slot> slots;
  final Map<String, String> weekdayLabels;

  Slot? byId(String id) {
    for (final slot in slots) {
      if (slot.id == id) return slot;
    }
    return null;
  }

  /// Le libellé d'un créneau, ou son identifiant si le fichier a changé sans
  /// que l'application soit remise à jour. Rendre vide cacherait l'horaire ;
  /// rendre l'identifiant est laid mais lisible.
  String labelOf(String slotId) => byId(slotId)?.label ?? slotId;

  String dayLabel(String day) => weekdayLabels[day] ?? day;

  /// `DateTime.weekday` va de 1 (lundi) à 7 (dimanche).
  String dayOf(DateTime date) => weekOrder[(date.weekday - 1).clamp(0, 6)];

  /// Les créneaux d'un jour, dans l'ordre horaire.
  List<Slot> slotsOn(String day) =>
      slots.where((slot) => slot.days.contains(day)).toList(growable: false)
        ..sort((a, b) => a.start.compareTo(b.start));

  static SlotGrid fromJson(Map<String, dynamic> json) {
    final brut = json['slots'];
    final slots = brut is List
        ? brut
              .whereType<Map<String, dynamic>>()
              .map(
                (slot) => Slot(
                  id: (slot['id'] ?? '').toString(),
                  label: (slot['label'] ?? '').toString(),
                  days:
                      (slot['days'] as List?)
                          ?.map((jour) => jour.toString())
                          .toList(growable: false) ??
                      const [],
                  start: (slot['start'] ?? '').toString(),
                  end: (slot['end'] ?? '').toString(),
                ),
              )
              .where((slot) => slot.id.isNotEmpty)
              .toList(growable: false)
        : const <Slot>[];

    final libelles = json['weekdayLabels'];
    return SlotGrid(
      sessionMinutes: switch (json['sessionMinutes']) {
        final int i => i,
        final num n => n.round(),
        _ => 90,
      },
      slots: slots,
      weekdayLabels: libelles is Map
          ? {
              for (final entree in libelles.entries)
                entree.key.toString(): entree.value.toString(),
            }
          : const {},
    );
  }

  /// Charge la grille depuis les ressources embarquées.
  ///
  /// Le résultat est gardé en mémoire : le fichier ne change pas pendant la vie
  /// du processus, et chaque écran de cours en direct le demanderait sinon.
  static SlotGrid? _cache;

  static Future<SlotGrid> load({AssetBundle? bundle}) async {
    final dejaLu = _cache;
    if (dejaLu != null) return dejaLu;

    final brut = await (bundle ?? rootBundle).loadString(slotsAssetPath);
    final grille = SlotGrid.fromJson(jsonDecode(brut) as Map<String, dynamic>);
    _cache = grille;
    return grille;
  }

  /// Vide le cache. Réservé aux tests : sans cela, un test qui fournit un
  /// paquet de ressources différent lirait celui du test précédent.
  static void resetCacheForTests() => _cache = null;
}
