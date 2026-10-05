-- LiveKit et Bunny Stream : ce que le schéma doit retenir (02/10).
--
-- Deux fournisseurs retenus, et une seule chose à en garder : leurs
-- identifiants. Ni les URL, ni les jetons.
--
-- --- Pourquoi aucune URL n'est stockée ------------------------------------
--
-- Une URL de lecture Bunny est **signée et expire**. La mettre en base
-- reviendrait à conserver un laissez-passer périmé : au mieux inutile, au pire
-- recopié tel quel dans une réponse et servi à quelqu'un qui n'a pas payé.
--
-- Ce qui est stocké est l'identifiant de la vidéo chez Bunny. L'URL est
-- recalculée à chaque lecture, **après** vérification de l'achat, et pour
-- quelques heures seulement.
--
-- Même raison pour le jeton LiveKit : nominatif, court, recalculé. Rien à
-- garder.

-- --- Les vidéos d'un cours -------------------------------------------------

alter table course_items
  -- L'identifiant de la vidéo chez Bunny Stream. `remote_url` existe encore et
  -- reste utilisable pour un lien externe — une annale sur un site public, par
  -- exemple — mais une vidéo de cours passe désormais par le fournisseur, qui
  -- la transcode en plusieurs débits. Un MP4 brut sur une ligne guinéenne ne se
  -- regarde pas.
  add column if not exists provider_video_id text,

  -- L'état du transcodage, tel que Bunny le rend. Une vidéo déposée n'est pas
  -- une vidéo lisible : il faut quelques minutes, et l'écran doit pouvoir dire
  -- « en préparation » au lieu d'ouvrir un lecteur noir.
  add column if not exists provider_status text;

create index if not exists course_items_provider_idx
  on course_items (provider_video_id)
  where provider_video_id is not null;

-- --- L'enregistrement d'une séance ----------------------------------------

alter table live_sessions
  -- L'egress LiveKit en cours. Conservé le temps de la séance pour pouvoir
  -- arrêter l'enregistrement : sans cet identifiant, un egress oublié continue
  -- de tourner et d'être facturé.
  add column if not exists egress_id text,

  -- La vidéo Bunny issue de l'enregistrement, une fois récupérée et transcodée.
  add column if not exists recording_video_id text,

  add column if not exists recording_status text
    check (
      recording_status is null
      or recording_status in ('RECORDING', 'TRANSFERRING', 'READY', 'FAILED')
    ),

  -- Quand la salle a réellement ouvert et fermé. `starts_at` est l'horaire
  -- prévu ; ces deux colonnes sont ce qui s'est passé. L'écart entre les deux
  -- est la seule façon de constater qu'un professeur commence en retard.
  add column if not exists opened_at timestamptz,
  add column if not exists closed_at timestamptz;

create index if not exists live_sessions_recording_idx
  on live_sessions (recording_status)
  where recording_status is not null;

comment on column course_items.provider_video_id is
  'Identifiant Bunny Stream. L''URL de lecture est signee a la demande, '
  'apres verification de l''achat, et expire.';
comment on column live_sessions.egress_id is
  'Egress LiveKit en cours. Sans lui, un enregistrement oublie continue '
  'd''etre facture.';
