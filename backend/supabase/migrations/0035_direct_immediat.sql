-- Un direct qui commence maintenant (18/10).
--
-- --- Pourquoi une migration pour cela ------------------------------------
--
-- Une séance appartenait forcément à un créneau récurrent : `slot_id` était
-- `not null`, et sa valeur devait figurer dans le catalogue fermé des
-- créneaux (mardi 18 h, samedi 10 h…). C'est juste pour un cours qui revient
-- chaque semaine — c'est le cas normal, et il reste le cas normal.
--
-- Mais le professeur doit pouvoir ouvrir un direct **tout de suite** : il
-- vient de saisir sa matière et son prix, et il veut commencer. Cette séance
-- n'est l'occurrence de rien. Lui coller un créneau du catalogue ferait dire
-- à l'application « le cours du mardi 18 h » pour une séance ouverte un jeudi
-- à 15 h 20 — une donnée fausse, écrite pour contenter une contrainte.
--
-- La colonne devient donc facultative. `null` se lit « cette séance n'a pas
-- de créneau », ce qui est exactement la vérité.
--
-- --- Ce que cela ne change pas -------------------------------------------
--
-- Le générateur de séances continue de s'appuyer sur `slot_id` pour les
-- cours récurrents, et le champ reste obligatoire côté générateur : une
-- occurrence sans créneau ne pourrait pas être régénérée. Seule la table
-- cesse de l'exiger.

alter table live_sessions
  alter column slot_id drop not null;

comment on column live_sessions.slot_id is
  'Le créneau récurrent dont cette séance est l''occurrence. `null` pour un '
  'direct ouvert à l''instant, qui n''est l''occurrence de rien.';

/*
 * Un index pour retrouver les directs ouverts à l'instant.
 *
 * Ils n'apparaissent dans aucun planning : on les retrouve par leur absence
 * de créneau, et c'est la seule requête qui les distingue.
 */
create index if not exists live_sessions_immediates
  on live_sessions (live_course_id, starts_at desc)
  where slot_id is null;
