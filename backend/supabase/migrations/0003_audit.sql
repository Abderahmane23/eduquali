-- Journal d'audit (§5 du code_skill, §51).
--
-- « Qui a fait quoi, quand, depuis ou. » Une plateforme qui delivre des
-- certifications et manipule des pieces d'identite doit pouvoir le dire :
-- sans ce journal, une certification contestee est indefendable.
--
-- Ce que la table ne contient jamais : mots de passe, jetons, codes OTP et
-- reponses de test. L'assainissement a lieu dans l'API (api/_lib/audit.ts)
-- avant l'ecriture et avant le calcul de l'empreinte.

create table audit_events (
  id              bigserial primary key,
  method          text not null,
  path            text not null,
  status          integer not null,
  -- Nul pour un appel non authentifie : on garde la trace quand meme.
  user_id         uuid references profiles (id) on delete set null,
  ip              text,
  user_agent      text,
  duration_ms     integer not null default 0,
  -- Charge utile deja assainie, bornee cote API.
  payload         jsonb,
  -- Empreinte de la charge assainie : detecte une alteration a posteriori.
  payload_sha256  text not null,
  created_at      timestamptz not null default now()
);

create index audit_events_created_idx on audit_events (created_at desc);
create index audit_events_user_idx on audit_events (user_id, created_at desc);
create index audit_events_path_idx on audit_events (path, created_at desc);

-- Personne ne lit ce journal depuis un client. L'ecriture passe par la cle de
-- service, la lecture par le back-office administrateur (§57).
alter table audit_events enable row level security;
create policy "audit : ferme aux clients" on audit_events for select using (false);

-- La table ne fait que grossir : §4.6 demande une purge. A brancher sur un
-- cron une fois le back-office en place (retention 12 mois).
create or replace function purge_audit_events(retention_months integer default 12)
returns integer as $$
declare removed integer;
begin
  delete from audit_events
  where created_at < now() - make_interval(months => retention_months);
  get diagnostics removed = row_count;
  return removed;
end;
$$ language plpgsql security definer set search_path = public, pg_temp;
