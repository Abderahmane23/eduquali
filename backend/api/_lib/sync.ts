/**
 * Ce qu'un téléphone a le droit d'écrire sur le serveur.
 *
 * --- Le défaut que ce fichier répare ---------------------------------------
 *
 * L'application mobile envoie ses modifications en `POST /sync/push` depuis le
 * premier jour. **Le Worker n'avait pas cette route.** Tout ce qu'une personne
 * saisissait restait donc sur son téléphone, définitivement : un professeur qui
 * crée un cours, un parent qui ajoute un enfant, une disponibilité modifiée.
 * Rien ne remontait, le site ne le voyait jamais, et une réinstallation de l'APK
 * effaçait le tout.
 *
 * Rien ne l'a signalé parce que les deux côtés étaient cohérents avec eux-mêmes :
 * le client savait construire sa requête, le serveur savait répondre à `pull`, et
 * aucun contrôle ne vérifiait qu'un chemin appelé par un client existe.
 *
 * --- Pourquoi une liste blanche, et pas un `upsert` générique --------------
 *
 * La tentation est d'écrire vingt lignes : prendre `entity`, en déduire un nom
 * de table, et poser `payload` dedans. Ce serait la faille la plus grave du
 * dépôt. `payload` vient d'un téléphone : un APK décompilé en quelques minutes,
 * qui circule par Bluetooth. Un `upsert` générique laisserait n'importe qui
 * écrire n'importe quelle colonne de n'importe quelle table.
 *
 * --- Pourquoi DEUX barrières, et pas seulement RLS ------------------------
 *
 * Les écritures passent par `asUser(jeton)`, donc **RLS s'applique** : Postgres
 * refuse une ligne qui n'appartient pas à l'appelant. C'est la première barrière
 * et elle est déjà écrite, déjà relue.
 *
 * Elle ne suffit pas, et voici le cas exact qui le prouve : un professeur
 * **possède** sa ligne `teachers`. RLS le laisse donc écrire
 * `identity_status = 'VERIFIED'` sur lui-même, ou prolonger son propre
 * `boosted_until` — l'option Visibilité+ qui se paie. Les deux sont des
 * décisions du serveur, pas des champs de formulaire.
 *
 * D'où la seconde barrière : **une liste de colonnes par entité**. RLS dit
 * *quelle ligne*, la liste dit *quelles colonnes*. Aucune des deux ne remplace
 * l'autre.
 *
 * --- Ce qui est refusé, et pourquoi c'est explicite -----------------------
 *
 * `REFUSED` nomme les entités qu'un client ne doit jamais pousser, avec la
 * raison. Les lister plutôt que de les oublier change le comportement du
 * serveur : une entité inconnue est refusée avec un message lisible, et le
 * message dit pourquoi. Une entité simplement absente aurait produit « entité
 * inconnue », qu'on aurait prise pour un oubli à combler.
 */

/** Les opérations que le client envoie (`SyncOperation` côté Flutter). */
export type SyncOperation = 'CREATE' | 'UPDATE' | 'DELETE' | 'UPLOAD'

export interface SyncPushItem {
  /** Référence locale, rendue telle quelle pour que le client s'y retrouve. */
  clientRef: number
  entity: string
  entityId: string
  operation: string
  payload: Record<string, unknown>
}

export type SyncStatus = 'applied' | 'conflict' | 'failed'

export interface SyncPushResult {
  clientRef: number
  entity: string
  entityId: string
  status: SyncStatus
  message?: string
}

interface Writable {
  /** La table visée. */
  table: string
  /**
   * Les colonnes qu'un client peut poser. Tout le reste est ignoré en silence
   * plutôt que refusé : une version plus récente de l'application peut envoyer
   * un champ que ce serveur ne connaît pas encore, et faire échouer toute la
   * synchronisation pour cela serait pire.
   */
  columns: readonly string[]
  /**
   * Les colonnes que le client N'A PAS le droit de poser, et pourquoi.
   *
   * Documentaire — la liste blanche suffit techniquement. Mais c'est ici qu'on
   * répond à « pourquoi ne puis-je pas écrire ce champ ? », et sans cela
   * quelqu'un l'ajouterait à `columns` en croyant corriger un oubli.
   */
  serverOwned?: Readonly<Record<string, string>>
  /** La suppression est-elle permise depuis un client ? */
  deletable?: boolean
}

/**
 * Les entités qu'un téléphone peut écrire.
 *
 * Volontairement incomplète : seules les entités dont l'appartenance est claire
 * et qui ne touchent pas à l'argent sont ici. Les autres sont dans `REFUSED`
 * avec leur raison, et la liste se complète entité par entité — jamais en bloc.
 */
export const WRITABLE: Readonly<Record<string, Writable>> = {
  // --- La famille ---------------------------------------------------------
  child: {
    table: 'children',
    columns: [
      'id',
      'parent_id',
      'first_name',
      // Tenus par l'application depuis sa v7 et filtrés en silence ici. Les
      // matières sont la plus coûteuse des deux : c'est elle qui alimente la
      // section « Pour sa classe » de l'accueil et le classement du catalogue,
      // donc l'accueil se reconstruisait vide sur un autre appareil.
      'last_name',
      'subject_ids',
      'level_id',
      'school_name',
      'institution_id',
      'status',
      'notes',
      'filiere_id',
    ],
    deletable: true,
  },
  parent: {
    table: 'parents',
    columns: ['id', 'user_id', 'city', 'district', 'region'],
  },

  // --- Le professeur -----------------------------------------------------
  teacher: {
    table: 'teachers',
    columns: [
      'id',
      'user_id',
      'headline',
      'bio',
      'city',
      // Déclarées par l'application depuis sa v9 et filtrées en silence ici :
      // la région et le quartier d'un professeur n'arrivaient jamais. Ajoutées
      // avec les colonnes correspondantes (migration 0026).
      'region',
      'district',
      'years_experience',
      'availability',
      'available_from',
      'preferred_institution_types',
      'preferred_contract_types',
      // Les réponses de l'inscription qui n'avaient pas de destination
      // (migration 0026) : ce qu'il cherche, s'il peut déménager, et ses
      // créneaux — à domicile et en établissement.
      'service_types',
      'mobility',
      'tutoring_days',
      'tutoring_slots',
      'tutoring_hours',
      'work_hours',
    ],
    serverOwned: {
      identity_status:
        'décision de vérification : elle vient de l’examen d’une pièce ' +
        'd’identité, pas d’un formulaire',
      diploma_status: 'idem, sur un diplôme',
      boosted_until:
        'Visibilité+ se paie. Un client qui écrirait cette colonne s’offrirait ' +
        'la mise en avant',
      profile_views: 'compteur tenu par le serveur',
    },
  },
  /*
   * `teacher_subjects` et `teacher_levels` ne passent plus par ici.
   *
   * Ce sont des **ensembles**, et `planWrite` ecrit une ligne. « Voila mes
   * matieres » veut dire en ajouter *et retirer celles qu'on a decochees* :
   * une synchronisation ligne par ligne ne sait pas exprimer le retrait.
   *
   * Le client poussait `{subjectIds: [...]}` avec, pour `entityId`,
   * l'identifiant du professeur et non celui d'une ligne. Aucune cle ne
   * correspondait a une colonne : la charge etait videe puis refusee. Les
   * competences restaient sur le telephone.
   *
   * Elles ont desormais leur route, `POST /teacher/competences`, qui remplace
   * l'ensemble d'un bloc (`remplacer_competences`, migration 0029). Elles
   * figurent dans `REFUSED` avec ce renvoi, pour qu'un vieux client recoive un
   * message qui dit quoi faire plutot qu'un refus muet.
   */
  /*
   * Les créneaux à domicile, sur la fiche du professeur.
   *
   * Cette entrée nommait `teacher_tutoring_availability` — une table
   * qu'**aucune migration n'a jamais créée**, avec des colonnes
   * (`weekday`, `start_time`, `end_time`) que le client n'envoie pas : il
   * pousse `{days: [...], slots: [...]}`. Chaque enregistrement de
   * disponibilité échouait donc, d'abord sur la charge utile puis en `42P01`.
   *
   * Les créneaux vivent sur `teachers` depuis la v6 de l'application. On
   * écrit là, et le nom de l'entité le dit.
   */
  teacher_availability: {
    table: 'teachers',
    columns: ['id', 'tutoring_days', 'tutoring_slots', 'tutoring_hours'],
  },
  experience: {
    table: 'teacher_experiences',
    columns: [
      'id',
      'teacher_id',
      'institution_name',
      'position',
      'city',
      'start_date',
      'end_date',
    ],
    serverOwned: {
      verification_status:
        'c’est l’établissement cité qui confirme une expérience, pas celui ' +
        'qui la déclare',
    },
    deletable: true,
  },

  // --- Les offres de cours à domicile ------------------------------------
  tutoring_service: {
    table: 'tutoring_services',
    columns: [
      'id',
      'teacher_id',
      'subject_id',
      'level_ids',
      'mode',
      'hourly_rate',
      'city',
      'districts',
      'availability_note',
      'description',
      'active',
    ],
    deletable: true,
  },
  tutoring_request: {
    table: 'tutoring_requests',
    // `teacher_id`, `subject_id`, `level_id`, `mode` et `preferred_days`
    // étaient listés et **n'existent pas** : une demande vise une *offre*
    // (`service_id`), qui porte déjà le professeur, la matière et le mode.
    // `service_id` et `preferred_start`, eux, existaient sans être listés —
    // donc filtrés en silence.
    columns: [
      'id',
      'parent_id',
      'service_id',
      'child_id',
      'message',
      'preferred_start',
    ],
    serverOwned: {
      status:
        'c’est le professeur qui accepte ou refuse. Un client qui écrirait ' +
        '« ACCEPTED » s’accorderait le cours lui-même',
    },
  },

  // --- Candidatures et favoris -------------------------------------------
  application: {
    table: 'applications',
    // `note` n'existe pas : la colonne est `cover_note`.
    columns: ['id', 'teacher_id', 'job_id', 'cover_note'],
    serverOwned: {
      status: 'c’est l’établissement qui décide',
      match_score: 'calculé par le serveur (`scoreMatch`)',
    },
  },
  /*
   * Un professeur mis de côté.
   *
   * Cette entrée nommait `user_id`, `entity_type` et `entity_id` : **aucune
   * des trois n'existe**. La table (migration 0009) porte `owner_id` et
   * `teacher_id`, et ne met de côté que des professeurs — le modèle
   * « entité quelconque » n'a jamais été écrit.
   *
   * `owner_id` n'est pas listé : il vient du jeton, pas du client, sinon
   * n'importe qui remplirait les favoris d'un autre compte.
   */
  favourite: {
    table: 'favourites',
    columns: ['id', 'teacher_id'],
    deletable: true,
  },
}

/**
 * Les entités qu'un client ne pousse jamais, et la raison.
 *
 * Quatre familles, et chacune pour un motif différent :
 *
 *   * **l'argent** — un paiement se constate par le webhook d'un encaisseur, pas
 *     par un téléphone qui l'annonce ;
 *   * **les décisions d'un tiers** — un contrat signé, un entretien accordé, un
 *     avis sur un professeur ;
 *   * **les documents vérifiés** — leur statut vient d'un examen humain ;
 *   * **ce qui est déjà servi par une route dédiée** — mieux vaut une route qui
 *     vérifie ses règles qu'une écriture générique qui les contourne.
 */
export const REFUSED: Readonly<Record<string, string>> = {
  course_purchase:
    'un achat se constate par le webhook de l’encaisseur. Voir POST /purchases.',
  contract_payment:
    'un paiement de contrat ne s’annonce pas depuis un téléphone.',
  teacher_boost:
    'Visibilité+ se paie : l’accorder depuis un client reviendrait à l’offrir.',
  payment_method:
    'un moyen de paiement se pose par le parcours d’encaissement, qui le ' +
    'valide auprès de l’opérateur.',
  identity_verification:
    'le statut vient de l’examen d’une pièce d’identité. Le document s’envoie ' +
    'par la route de téléversement, pas par la synchronisation.',
  diploma:
    'le fichier passe par la route de téléversement, et le statut vient de ' +
    'l’examen du diplôme par quelqu’un. Ni l’un ni l’autre ne se déclare.',
  document: 'un fichier ne passe pas par la synchronisation JSON.',
  contract: 'un contrat engage deux parties : il se signe, il ne se pousse pas.',
  interview:
    'un entretien est accordé par un établissement, pas déclaré par le candidat.',
  teacher_review:
    'un avis engage son auteur et la réputation d’un professeur : route dédiée ' +
    'avec ses propres règles.',
  test_session:
    'une session de test est arbitrée par le serveur — il détient les bonnes ' +
    'réponses et le chronomètre. Voir POST /tests/:id/submit.',
  institution:
    'une fiche d’établissement est publique et vérifiée : elle ne se modifie ' +
    'pas depuis un téléphone.',
  job: 'une offre est publiée par un établissement depuis son espace.',
  recruitment:
    'une campagne de recrutement est pilotée par l’établissement depuis son ' +
    'espace : un candidat n’en crée ni n’en modifie aucune étape.',
  recruitment_offer:
    'l’offre faite à un candidat engage l’établissement sur un salaire et un ' +
    'poste. Elle ne vient pas du téléphone de celui qui la reçoit.',
  recruitment_room:
    'la salle d’un recrutement est ouverte par l’établissement, et son contenu ' +
    'sert de trace à une décision d’embauche.',
  // Cette raison nommait une route qui n'existait pas, et c'etait tout le
  // probleme : un compte cree depuis le telephone avait une identite chez
  // Supabase et aucune ligne `profiles`. La route existe depuis le 06/10.
  user:
    'un profil porte le rôle, et le rôle décide de tout le reste : il se crée ' +
    'par POST /account, qui lit l’identité dans le jeton et jamais dans le ' +
    'corps. Ouvrir cette table à un client laisserait quelqu’un se déclarer ' +
    'ADMIN.',
  teacher_subjects:
    'les matières sont un ensemble : « voilà les miennes » veut dire en ' +
    'ajouter ET retirer les autres, ce qu’une écriture ligne par ligne ne sait ' +
    'pas exprimer. Utiliser POST /teacher/competences, qui remplace tout d’un ' +
    'bloc.',
  teacher_levels:
    'même raison que teacher_subjects, et les niveaux se déclarent par ' +
    'matière : POST /teacher/competences.',
  video_course:
    'un cours vidéo porte un prix et des fichiers : route dédiée, qui relit le ' +
    'prix côté serveur.',
  course_chapter:
    'un chapitre fait partie d’un cours vidéo, qui porte un prix : il passe par ' +
    'la route du cours, qui relit ce prix côté serveur.',
  course_item:
    'un élément de cours porte le chemin d’un fichier payé. Le laisser écrire ' +
    'depuis un client permettrait de pointer vers n’importe quoi.',
  course_comment: 'route dédiée : la modération a ses règles.',
  conversation:
    'une conversation naît d’une mise en relation, qui a ses conditions (§30).',
  message: 'un message s’envoie par la route de messagerie, qui notifie.',
}

/** Ce qu'il faut faire d'un élément poussé. */
export type Plan =
  | {
      kind: 'upsert'
      table: string
      row: Record<string, unknown>
      /** Colonnes reçues mais non retenues : utile pour journaliser. */
      ignored: string[]
    }
  | { kind: 'delete'; table: string; id: string }
  | { kind: 'refuse'; status: SyncStatus; message: string }

/**
 * Décide quoi faire d'un élément, sans toucher à la base.
 *
 * Fonction **pure** : c'est ce qui permet d'éprouver toutes les règles de refus
 * sans Postgres, et donc de les éprouver vraiment. La route, elle, n'a plus qu'à
 * exécuter le plan.
 */
export function planWrite(item: SyncPushItem): Plan {
  const refus = REFUSED[item.entity]
  if (refus) {
    return {
      kind: 'refuse',
      status: 'failed',
      message: `« ${item.entity} » ne se synchronise pas : ${refus}`,
    }
  }

  const regle = WRITABLE[item.entity]
  if (!regle) {
    return {
      kind: 'refuse',
      status: 'failed',
      message:
        `Entité « ${item.entity} » inconnue du serveur. Si elle doit remonter, ` +
        'elle s’ajoute à WRITABLE avec ses colonnes — jamais en bloc.',
    }
  }

  if (!item.entityId) {
    return {
      kind: 'refuse',
      status: 'failed',
      message: 'Élément sans identifiant : rien à écrire.',
    }
  }

  if (item.operation === 'DELETE') {
    if (!regle.deletable) {
      /*
       * Un refus de suppression est un `conflict`, pas un `failed`.
       *
       * La distinction compte pour le client : `failed` se remet en file et se
       * réessaie, `conflict` s'arrête. Réessayer une suppression que le serveur
       * refusera toujours occuperait la file indéfiniment.
       */
      return {
        kind: 'refuse',
        status: 'conflict',
        message: `« ${item.entity} » ne se supprime pas depuis un client.`,
      }
    }
    return { kind: 'delete', table: regle.table, id: item.entityId }
  }

  if (item.operation === 'UPLOAD') {
    return {
      kind: 'refuse',
      status: 'conflict',
      message:
        'Un fichier ne passe pas par la synchronisation JSON : utiliser la ' +
        'route de téléversement.',
    }
  }

  if (item.operation !== 'CREATE' && item.operation !== 'UPDATE') {
    return {
      kind: 'refuse',
      status: 'failed',
      message: `Opération « ${item.operation} » inconnue.`,
    }
  }

  const permises = new Set(regle.columns)
  const row: Record<string, unknown> = {}
  const ignored: string[] = []

  for (const [cle, valeur] of Object.entries(item.payload ?? {})) {
    if (permises.has(cle)) row[cle] = valeur
    else ignored.push(cle)
  }

  // L'identifiant vient de `entityId` et non du corps : c'est lui que le client
  // suit, et laisser le corps le contredire ferait écrire une autre ligne que
  // celle qu'il croit modifier.
  row.id = item.entityId

  if (Object.keys(row).length <= 1) {
    return {
      kind: 'refuse',
      status: 'failed',
      message:
        'Aucune colonne reconnue dans la charge utile. Reçu : ' +
        (ignored.join(', ') || '(rien)'),
    }
  }

  return { kind: 'upsert', table: regle.table, row, ignored }
}

/**
 * Les entités que le client connaît et que le serveur ne traite pas encore.
 *
 * Sert au contrôle du dépôt : la liste doit rester vide une fois WRITABLE et
 * REFUSED complets. Tant qu'elle ne l'est pas, elle dit exactement ce qui
 * manque — plutôt que de laisser croire que la synchronisation est finie.
 */
export function unhandled(entities: readonly string[]): string[] {
  return entities.filter((e) => !(e in WRITABLE) && !(e in REFUSED))
}
