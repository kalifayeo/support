-- À exécuter une fois dans l'éditeur SQL de Supabase.

-- 1) Modification d'une fiche déjà établie (admin ou créateur de la fiche).
--    Le statut n'est jamais modifié ici ; chaque modification est journalisée.
create or replace function modifier_fiche(
  p_form_id uuid, p_direction_id uuid, p_service_id uuid,
  p_utilisateur_id uuid, p_contenu jsonb
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_form forms%rowtype;
  v_ancien jsonb;
begin
  select * into v_form from forms where id = p_form_id;
  if not found then raise exception 'Fiche introuvable'; end if;
  if not (is_admin() or v_form.cree_par = auth.uid()) then
    raise exception 'Vous n''avez pas le droit de modifier cette fiche';
  end if;

  select contenu into v_ancien from form_data where form_id = p_form_id;

  update forms
     set direction_id = p_direction_id, service_id = p_service_id,
         utilisateur_concerne_id = p_utilisateur_id, updated_at = now()
   where id = p_form_id;

  insert into form_data (form_id, contenu, updated_at)
  values (p_form_id, p_contenu, now())
  on conflict (form_id) do update set contenu = excluded.contenu, updated_at = now();

  insert into audit_logs (acteur_id, action, cible_type, cible_id, ancien_etat, nouvel_etat)
  values (auth.uid(), 'modification_fiche', 'form', p_form_id,
          jsonb_build_object('contenu', v_ancien, 'direction_id', v_form.direction_id, 'service_id', v_form.service_id, 'utilisateur_id', v_form.utilisateur_concerne_id),
          jsonb_build_object('contenu', p_contenu, 'direction_id', p_direction_id, 'service_id', p_service_id, 'utilisateur_id', p_utilisateur_id));
end;
$$;
revoke all on function modifier_fiche(uuid, uuid, uuid, uuid, jsonb) from public;
grant execute on function modifier_fiche(uuid, uuid, uuid, uuid, jsonb) to authenticated;

-- 2) La page publique de vérification (QR code) ne doit PAS exposer la clé
--    d'activation du système : on la retire du matériel renvoyé.
create or replace function verifier_document(p_code text)
returns table(
  numero text, statut form_status, type_fiche text,
  cree_le timestamptz, valide_le timestamptz,
  direction text, service text,
  etabli_par_nom text, etabli_par_prenom text, etabli_par_matricule text, etabli_par_fonction text,
  beneficiaire_nom text, beneficiaire_prenom text, beneficiaire_matricule text, beneficiaire_fonction text,
  materiel jsonb, observations text
)
language sql stable security definer set search_path = public as $$
  select
    f.numero, f.statut, ft.nom,
    f.created_at,
    (select fv.created_at from form_validations fv where fv.form_id = f.id and fv.nouveau_statut = 'validee' order by fv.created_at desc limit 1),
    dir.nom, srv.nom,
    cp.nom, cp.prenom, cp.matricule, cp.fonction,
    ag.nom, ag.prenom, ag.matricule, ag.fonction,
    (fd.contenu->'materiel') - 'cle_activation', fd.contenu->>'observations'
  from documents d
  join forms f on f.id = d.form_id
  left join form_types ft on ft.id = f.form_type_id
  left join directions dir on dir.id = f.direction_id
  left join services srv on srv.id = f.service_id
  left join profiles cp on cp.id = f.cree_par
  left join agents ag on ag.id = f.utilisateur_concerne_id
  left join form_data fd on fd.form_id = f.id
  where d.code_verification = p_code
  limit 1;
$$;
revoke all on function verifier_document(text) from public;
grant execute on function verifier_document(text) to anon, authenticated;
