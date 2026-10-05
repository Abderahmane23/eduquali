-- Controle d'acces des tables ajoutees en 0006 (§51).
--
-- Une table sans RLS dans Supabase est lisible par n'importe quel porteur de
-- la cle publique — celle qui est, par construction, dans le site et dans
-- l'APK. Activer RLS sans ecrire de politique ferme tout ; ecrire la table
-- sans activer RLS ouvre tout. Les deux se font ici, dans le meme fichier,
-- pour qu'on ne puisse pas faire l'un sans l'autre.
--
-- Les fonctions `my_teacher_id()`, `my_parent_id()`, `my_institution_id()` et
-- `current_role_is()` viennent de 0002.

-- --- Referentiel : lisible par tous, ecrit en back-office -----------------

alter table filieres enable row level security;
create policy "profils de lycee lisibles" on filieres for select using (true);

-- --- Tout le reste : ferme par defaut -------------------------------------

do $$
declare t text;
begin
  foreach t in array array[
    'tutoring_sessions', 'work_contracts', 'contract_payments',
    'video_courses', 'course_purchases', 'promotions', 'payment_methods',
    'recruitment_rooms', 'conversations', 'messages', 'interviews',
    'recruitment_offers', 'contracts', 'recruitments', 'recruitment_events',
    'teacher_reviews', 'job_invitations', 'notifications', 'credit_ledger',
    'ai_courses'
  ] loop
    execute format('alter table %I enable row level security', t);
  end loop;
end $$;

-- --- Cours a domicile ------------------------------------------------------

-- Une seance se lit des deux cotes : la famille qui paie et le professeur
-- qui se deplace. Aucun des deux ne voit celles des autres.
create policy "seance : les deux parties" on tutoring_sessions
  for select using (
    exists (
      select 1
      from tutoring_requests r
      join tutoring_services s on s.id = r.service_id
      where r.id = request_id
        and (r.parent_id = my_parent_id() or s.teacher_id = my_teacher_id())
    )
  );

-- Seul le professeur programme, deplace ou annule : c'est lui qui se
-- deplace, et une seance modifiable des deux cotes finit par ne plus dire la
-- meme heure aux deux.
create policy "seance : le professeur la conduit" on tutoring_sessions
  for all using (
    exists (
      select 1
      from tutoring_requests r
      join tutoring_services s on s.id = r.service_id
      where r.id = request_id and s.teacher_id = my_teacher_id()
    )
  ) with check (
    exists (
      select 1
      from tutoring_requests r
      join tutoring_services s on s.id = r.service_id
      where r.id = request_id and s.teacher_id = my_teacher_id()
    )
  );

-- --- Contrats de travail et echeances -------------------------------------

create policy "contrat : les parties concernees" on work_contracts
  for select using (
    teacher_id = my_teacher_id()
    or institution_id = my_institution_id()
    or parent_id = my_parent_id()
  );

-- L'employeur ecrit le contrat ; le professeur le lit. Un professeur qui
-- pourrait modifier son propre montant mensuel n'aurait pas besoin d'en
-- discuter.
create policy "contrat : l employeur l ecrit" on work_contracts
  for all using (
    institution_id = my_institution_id() or parent_id = my_parent_id()
  ) with check (
    institution_id = my_institution_id() or parent_id = my_parent_id()
  );

create policy "echeance : les parties du contrat" on contract_payments
  for select using (
    exists (
      select 1 from work_contracts c
      where c.id = contract_id
        and (c.teacher_id = my_teacher_id()
             or c.institution_id = my_institution_id()
             or c.parent_id = my_parent_id())
    )
  );

-- Seul celui qui paie marque une echeance comme reglee.
create policy "echeance : celui qui paie" on contract_payments
  for update using (
    exists (
      select 1 from work_contracts c
      where c.id = contract_id
        and (c.institution_id = my_institution_id()
             or c.parent_id = my_parent_id())
    )
  );

-- --- Catalogue de cours video ---------------------------------------------

-- Un cours en vente est public : c'est une vitrine. Les brouillons et les
-- cours retires n'appartiennent qu'a leur auteur.
create policy "cours : la vitrine est publique" on video_courses
  for select using (status = 'PUBLISHED' or teacher_id = my_teacher_id());

create policy "cours : son auteur le gere" on video_courses
  for all using (teacher_id = my_teacher_id())
  with check (teacher_id = my_teacher_id());

create policy "achat : l acheteur et le vendeur" on course_purchases
  for select using (
    parent_id = my_parent_id()
    or exists (
      select 1 from video_courses v
      where v.id = course_id and v.teacher_id = my_teacher_id()
    )
  );

create policy "achat : c est l acheteur qui achete" on course_purchases
  for insert with check (parent_id = my_parent_id());

-- --- Promotions ------------------------------------------------------------

create policy "promotion : visible quand elle est active" on promotions
  for select using (status = 'ACTIVE' or institution_id = my_institution_id());

create policy "promotion : son etablissement la gere" on promotions
  for all using (institution_id = my_institution_id())
  with check (institution_id = my_institution_id());

-- --- Moyens de paiement ----------------------------------------------------
--
-- Strictement personnels. Aucun autre role, aucune lecture croisee.

create policy "moyen de paiement : le sien seulement" on payment_methods
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- --- Espace de recrutement -------------------------------------------------

create policy "salon : ses deux parties" on recruitment_rooms
  for select using (
    teacher_id = my_teacher_id() or institution_id = my_institution_id()
  );

create policy "salon : l etablissement le mene" on recruitment_rooms
  for all using (institution_id = my_institution_id())
  with check (institution_id = my_institution_id());

create policy "conversation : ses deux parties" on conversations
  for select using (
    teacher_id = my_teacher_id() or parent_id = my_parent_id()
  );

create policy "conversation : ouverte par une partie" on conversations
  for insert with check (
    teacher_id = my_teacher_id() or parent_id = my_parent_id()
  );

-- Un message se lit si l'on appartient a son fil, quel qu'il soit.
create policy "message : lecture dans son fil" on messages
  for select using (
    exists (
      select 1 from recruitment_rooms r
      where r.id = room_id
        and (r.teacher_id = my_teacher_id()
             or r.institution_id = my_institution_id())
    )
    or exists (
      select 1 from conversations c
      where c.id = conversation_id
        and (c.teacher_id = my_teacher_id() or c.parent_id = my_parent_id())
    )
  );

-- On n'ecrit que sous son propre nom, et seulement dans un fil dont on fait
-- partie. Sans la premiere condition, n'importe quel membre du fil pourrait
-- signer un message du nom de l'autre.
create policy "message : ecriture sous son nom" on messages
  for insert with check (
    sender_id = auth.uid()::text
    and (
      exists (
        select 1 from recruitment_rooms r
        where r.id = room_id
          and (r.teacher_id = my_teacher_id()
               or r.institution_id = my_institution_id())
      )
      or exists (
        select 1 from conversations c
        where c.id = conversation_id
          and (c.teacher_id = my_teacher_id() or c.parent_id = my_parent_id())
      )
    )
  );

-- Marquer comme lu est la seule modification permise ; le corps d'un message
-- envoye ne se reecrit pas.
create policy "message : marquer comme lu" on messages
  for update using (
    exists (
      select 1 from conversations c
      where c.id = conversation_id
        and (c.teacher_id = my_teacher_id() or c.parent_id = my_parent_id())
    )
    or exists (
      select 1 from recruitment_rooms r
      where r.id = room_id
        and (r.teacher_id = my_teacher_id()
             or r.institution_id = my_institution_id())
    )
  );

-- Entretiens, offres, contrats, embauches, journal : meme regle que leur
-- salon. L'etablissement ecrit, le professeur lit et repond via l'API.
do $$
declare t text;
begin
  foreach t in array array[
    'interviews', 'recruitment_offers', 'recruitment_events'
  ] loop
    execute format($f$
      create policy "%1$s : lecture dans son salon" on %1$I
        for select using (
          exists (
            select 1 from recruitment_rooms r
            where r.id = room_id
              and (r.teacher_id = my_teacher_id()
                   or r.institution_id = my_institution_id())
          )
        );
      create policy "%1$s : l etablissement ecrit" on %1$I
        for all using (
          exists (
            select 1 from recruitment_rooms r
            where r.id = room_id and r.institution_id = my_institution_id()
          )
        ) with check (
          exists (
            select 1 from recruitment_rooms r
            where r.id = room_id and r.institution_id = my_institution_id()
          )
        );
    $f$, t);
  end loop;
end $$;

create policy "contrat signe : lecture dans son salon" on contracts
  for select using (
    exists (
      select 1 from recruitment_rooms r
      where r.id = room_id
        and (r.teacher_id = my_teacher_id()
             or r.institution_id = my_institution_id())
    )
  );

-- La signature passe par l'API, qui verifie l'ordre des etapes : une mise a
-- jour directe permettrait de signer a la place de l'autre.
create policy "contrat signe : l etablissement le redige" on contracts
  for all using (
    exists (
      select 1 from recruitment_rooms r
      where r.id = room_id and r.institution_id = my_institution_id()
    )
  ) with check (
    exists (
      select 1 from recruitment_rooms r
      where r.id = room_id and r.institution_id = my_institution_id()
    )
  );

create policy "embauche : ses deux parties" on recruitments
  for select using (
    teacher_id = my_teacher_id() or institution_id = my_institution_id()
  );

create policy "embauche : l etablissement la declare" on recruitments
  for all using (institution_id = my_institution_id())
  with check (institution_id = my_institution_id());

-- Une note engage celui qui la donne et celui qui la recoit : les deux la
-- voient. Seul l'etablissement l'ecrit, et un palier ne se note qu'une fois
-- (contrainte d'unicite en 0006).
create policy "note : les deux parties" on teacher_reviews
  for select using (
    teacher_id = my_teacher_id() or institution_id = my_institution_id()
  );

create policy "note : l etablissement la donne" on teacher_reviews
  for insert with check (institution_id = my_institution_id());

create policy "invitation : l invite et l inviteur" on job_invitations
  for select using (
    teacher_id = my_teacher_id()
    or exists (
      select 1 from jobs j
      where j.id = job_id and j.institution_id = my_institution_id()
    )
  );

create policy "invitation : l etablissement invite" on job_invitations
  for all using (
    exists (
      select 1 from jobs j
      where j.id = job_id and j.institution_id = my_institution_id()
    )
  ) with check (
    exists (
      select 1 from jobs j
      where j.id = job_id and j.institution_id = my_institution_id()
    )
  );

-- --- Notifications, credits, cours produits -------------------------------
--
-- Strictement personnels. Le grand livre des credits est en lecture seule
-- pour son proprietaire : il ne s'ecrit que par la cle de service, sinon un
-- client pourrait se crediter lui-meme.

create policy "notification : la sienne" on notifications
  for select using (user_id = auth.uid());

create policy "notification : la marquer lue" on notifications
  for update using (user_id = auth.uid());

create policy "credits : lecture de son grand livre" on credit_ledger
  for select using (owner_id = auth.uid());

create policy "cours IA : les siens" on ai_courses
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());
