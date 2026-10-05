-- Les lots mis de cote (04/10) — complement a D2.
--
-- --- Pourquoi une table, et pas un reglage local -------------------------
--
-- Un favori pourrait vivre dans SQLite, sur le telephone. Mais l'APK circule par
-- Bluetooth et se reinstalle souvent : la liste disparaitrait a la premiere
-- reinstallation, sans que personne comprenne pourquoi. Et l'ecran de la
-- boutique a de toute facon besoin du serveur — le solde en vient — donc un
-- favori local s'afficherait sur une page qui ne se charge pas hors ligne.
--
-- --- Ce que cette table a de different des points -----------------------
--
-- `point_ledger` n'a aucune politique d'ecriture : les points se gagnent par
-- une decision du serveur. Ici, au contraire, **le client ecrit lui-meme**. Un
-- favori n'a aucune valeur, ne donne droit a rien, et n'appartient qu'a la
-- personne : le lui faire demander au serveur serait une ceremonie inutile.
--
-- La difference est deliberee, et c'est la question a se poser pour toute table
-- suivante : ceci donne-t-il droit a quelque chose ? Si oui, le serveur decide.

create table if not exists shop_favorites (
  user_id     uuid not null references auth.users (id) on delete cascade,
  item_id     text not null references shop_items (id) on delete cascade,
  created_at  timestamptz not null default now(),

  -- La cle est la paire : mettre deux fois le meme lot de cote n'a pas de sens,
  -- et une contrainte evite d'avoir a verifier avant d'ecrire.
  primary key (user_id, item_id)
);

-- Les favoris d'une personne, du plus recent au plus ancien : c'est la seule
-- lecture que fait l'ecran d'accueil.
create index if not exists shop_favorites_user_idx
  on shop_favorites (user_id, created_at desc);

alter table shop_favorites enable row level security;

create policy "favoris : les siens" on shop_favorites
  for select using (user_id = auth.uid());

create policy "favoris : mettre de cote le sien" on shop_favorites
  for insert with check (user_id = auth.uid());

-- Et pouvoir le retirer. Sans cette politique, un favori serait definitif :
-- l'ecran proposerait un coeur qui ne s'eteint jamais.
create policy "favoris : retirer le sien" on shop_favorites
  for delete using (user_id = auth.uid());

-- **Aucune politique de mise a jour** : il n'y a rien a modifier dans une paire
-- (compte, lot). On ajoute ou on retire.

comment on table shop_favorites is
  'Lots mis de cote. Le client ecrit lui-meme, contrairement a point_ledger : '
  'un favori ne donne droit a rien.';
