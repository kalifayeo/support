-- ============================================================================
-- UTRAKO — Schéma Supabase / PostgreSQL
-- Plateforme de gestion des fiches et du parc informatique de la DSI
-- ============================================================================
-- À exécuter dans l'éditeur SQL de Supabase (ou via `supabase db push`)
-- ============================================================================

create extension if not exists "pgcrypto";

-- ----------------------------------------------------------------------------
-- 1. RÉFÉRENTIELS
-- ----------------------------------------------------------------------------

create table directions (
  id uuid primary key default gen_random_uuid(),
  nom text not null unique,
  created_at timestamptz not null default now()
);

create table services (
  id uuid primary key default gen_random_uuid(),
  nom text not null,
  direction_id uuid references directions(id) on delete restrict,
  -- Les 3 services de la DSI : Support informatique, Étude et développement, Exploitation
  created_at timestamptz not null default now(),
  unique (nom, direction_id)
);

-- Rôles fixes de la plateforme (table de référence, pas de création libre par l'admin)
create type app_role as enum (
  'super_admin',
  'admin',
  'directeur',
  'chef_service',
  'technicien',
  'stagiaire',
  'agent'
);

create type user_status as enum (
  'en_attente',
  'actif',
  'suspendu',
  'desactive',
  'archive'
);

-- ----------------------------------------------------------------------------
-- 2. AGENTS — répertoire de TOUT le personnel pouvant recevoir du matériel
--    ou être bénéficiaire d'une fiche, qu'il ait ou non un compte de connexion
--    à la plateforme (un chef de service politique qui reçoit un téléphone
--    n'a pas forcément besoin de se connecter à l'application).
-- ----------------------------------------------------------------------------

create table agents (
  id uuid primary key default gen_random_uuid(),
  matricule text unique,
  nom text not null,
  prenom text not null,
  telephone text,
  email text,
  direction_id uuid references directions(id),
  service_id uuid references services(id),
  fonction text,
  a_un_compte boolean not null default false, -- true si synchronisé depuis un profil (compte de connexion)
  created_by uuid, -- référence profiles(id), ajoutée après création de la table profiles
  created_at timestamptz not null default now()
);

alter table agents add constraint agent_matricule_format
  check (matricule is null or matricule ~ '^[A-Z][0-9]{3,5}$');

create index idx_agents_service on agents(service_id);
create index idx_agents_direction on agents(direction_id);

-- ----------------------------------------------------------------------------
-- 3. UTILISATEURS (comptes de connexion)
-- ----------------------------------------------------------------------------
-- profiles étend auth.users (Supabase Auth gère l'authentification elle-même)

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  matricule text not null unique,               -- format contrôlé ex: I001
  nom text not null,
  prenom text not null,
  telephone text,
  email_pro text not null,
  direction_id uuid references directions(id),
  service_id uuid references services(id),
  fonction text,
  role app_role not null default 'agent',
  status user_status not null default 'en_attente',
  date_inscription timestamptz not null default now(),
  date_activation timestamptz,
  derniere_connexion timestamptz,
  doit_changer_mdp boolean not null default true, -- forcé à true quand un admin crée le compte avec un mot de passe temporaire
  created_by uuid references profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table agents add constraint agents_created_by_fkey foreign key (created_by) references profiles(id);

-- format matricule : une lettre + 3 à 5 chiffres, soit 4 à 6 caractères au total (ex I001, I00512)
alter table profiles add constraint matricule_format
  check (matricule ~ '^[A-Z][0-9]{3,5}$');

create index idx_profiles_direction on profiles(direction_id);
create index idx_profiles_service on profiles(service_id);
create index idx_profiles_role on profiles(role);

-- Synchronise automatiquement un agent avec le MÊME id qu'un profil, pour que
-- les membres de la DSI ayant un compte soient eux aussi sélectionnables comme
-- bénéficiaires sans double saisie (agents.id = profiles.id pour ces cas-là,
-- ce qui garde "mon matériel" / "mes fiches" cohérent pour un utilisateur connecté).
create or replace function sync_agent_from_profile() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into agents (id, matricule, nom, prenom, telephone, email, direction_id, service_id, fonction, a_un_compte, created_by)
  values (new.id, new.matricule, new.nom, new.prenom, new.telephone, new.email_pro, new.direction_id, new.service_id, new.fonction, true, new.created_by)
  on conflict (id) do update set
    matricule = excluded.matricule, nom = excluded.nom, prenom = excluded.prenom,
    telephone = excluded.telephone, email = excluded.email,
    direction_id = excluded.direction_id, service_id = excluded.service_id,
    fonction = excluded.fonction, a_un_compte = true;
  return new;
end;
$$;

create trigger trg_sync_agent_from_profile
  after insert or update on profiles
  for each row execute function sync_agent_from_profile();

-- ----------------------------------------------------------------------------
-- 4. PARC INFORMATIQUE
-- ----------------------------------------------------------------------------

create table equipment_categories (
  id uuid primary key default gen_random_uuid(),
  nom text not null unique,          -- Ordinateur, Téléphone, Tablette, Imprimante, Écran, Routeur, Switch, Accessoire...
  necessite_imei boolean not null default false
);

create type equipment_state as enum (
  'neuf', 'bon_etat', 'usage', 'defectueux', 'en_reparation', 'reforme'
);

create table equipments (
  id uuid primary key default gen_random_uuid(),
  numero_inventaire text not null unique,
  numero_serie text unique,
  imei text,
  categorie_id uuid references equipment_categories(id),
  marque text,
  modele text,
  reference text,
  capacite text,
  ram text,
  stockage text,
  os text,
  etat equipment_state not null default 'bon_etat',
  localisation text,
  utilisateur_actuel_id uuid references agents(id) on delete set null,  -- dénormalisé pour lecture rapide, vérité = equipment_assignments
  date_acquisition date,
  garantie_fin date,
  observations text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_equipments_categorie on equipments(categorie_id);
create index idx_equipments_utilisateur on equipments(utilisateur_actuel_id);
create index idx_equipments_serie on equipments(numero_serie);
create index idx_equipments_imei on equipments(imei);

-- Historique complet des mouvements (affectation, restitution, maintenance, transfert...)
create type movement_type as enum (
  'affectation', 'restitution', 'transfert', 'maintenance_envoi',
  'maintenance_retour', 'reforme', 'perte'
);

create table equipment_movements (
  id uuid primary key default gen_random_uuid(),
  equipment_id uuid not null references equipments(id) on delete cascade,
  type movement_type not null,
  utilisateur_id uuid references agents(id) on delete set null,      -- agent concerné par le mouvement
  effectue_par uuid references profiles(id) not null, -- qui a enregistré l'opération
  form_id uuid,                                       -- fiche liée si applicable (voir plus bas)
  observations text,
  created_at timestamptz not null default now()
);

create index idx_movements_equipment on equipment_movements(equipment_id);

-- ----------------------------------------------------------------------------
-- 4. FICHES — architecture générique (un seul jeu de tables pour tous les types)
-- ----------------------------------------------------------------------------

create table form_types (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,          -- FA (affectation), RE (restitution), MA (maintenance)...
  nom text not null,                   -- "Fiche d'affectation de matériel"
  prefixe_numero text not null,        -- "FA"
  workflow jsonb not null default '[]', -- ex: ["technicien","chef_service","directeur"]
  schema jsonb not null default '{}',   -- structure des champs attendus dans form_data.contenu
  actif boolean not null default true,
  created_at timestamptz not null default now()
);

create type form_status as enum (
  'brouillon', 'en_attente', 'en_validation', 'validee', 'rejetee', 'annulee', 'archivee'
);

create table forms (
  id uuid primary key default gen_random_uuid(),
  numero text not null unique,          -- FA-2026-00001, généré par trigger
  form_type_id uuid not null references form_types(id),
  statut form_status not null default 'brouillon',
  direction_id uuid references directions(id),
  service_id uuid references services(id),
  utilisateur_concerne_id uuid references agents(id) on delete set null, -- l'agent bénéficiaire de la fiche (avec ou sans compte)
  cree_par uuid not null references profiles(id),
  etape_courante int not null default 0,   -- index dans le workflow du form_type
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  archived_by uuid references profiles(id),
  archive_raison text
);

create index idx_forms_type on forms(form_type_id);
create index idx_forms_statut on forms(statut);
create index idx_forms_cree_par on forms(cree_par);
create index idx_forms_utilisateur on forms(utilisateur_concerne_id);
create index idx_forms_direction on forms(direction_id);
create index idx_forms_service on forms(service_id);

alter table equipment_movements
  add constraint fk_movement_form foreign key (form_id) references forms(id) on delete set null;

-- Contenu métier de la fiche (JSON flexible : matériel, caractéristiques, observations...)
create table form_data (
  form_id uuid primary key references forms(id) on delete cascade,
  contenu jsonb not null default '{}',
  equipment_id uuid references equipments(id),
  updated_at timestamptz not null default now()
);

-- Historique des changements de statut (workflow)
create table form_validations (
  id uuid primary key default gen_random_uuid(),
  form_id uuid not null references forms(id) on delete cascade,
  etape text not null,                 -- ex: "chef_service"
  ancien_statut form_status,
  nouveau_statut form_status not null,
  validateur_id uuid references profiles(id),
  commentaire text,
  created_at timestamptz not null default now()
);

create index idx_validations_form on form_validations(form_id);

-- Signatures liées à une fiche
create type signature_type as enum ('manuscrite', 'numerique', 'compte_utilisateur');

create table signatures (
  id uuid primary key default gen_random_uuid(),
  form_id uuid not null references forms(id) on delete cascade,
  signataire_id uuid references profiles(id) not null,
  role_signataire text not null,       -- "gestionnaire_parc", "utilisateur", "chef_service"...
  type signature_type not null default 'compte_utilisateur',
  image_url text,                       -- si signature manuscrite scannée (Supabase Storage)
  signed_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- 5. DOCUMENTS GÉNÉRÉS (PDF)
-- ----------------------------------------------------------------------------

create table documents (
  id uuid primary key default gen_random_uuid(),
  form_id uuid not null references forms(id) on delete cascade,
  fichier_url text not null,            -- chemin Supabase Storage
  code_verification text unique,        -- utilisé par le QR code
  genere_par uuid references profiles(id),
  created_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- 6. AUTORISATIONS D'ACCÈS PONCTUELLES AUX FICHES
-- ----------------------------------------------------------------------------
-- Une fiche n'est visible que par : son créateur, l'utilisateur concerné,
-- la hiérarchie de validation, admin/super_admin, OU une personne autorisée
-- explicitement par le créateur (section 32 du cahier des charges).

create table form_access_grants (
  id uuid primary key default gen_random_uuid(),
  form_id uuid not null references forms(id) on delete cascade,
  beneficiaire_id uuid not null references profiles(id),
  accorde_par uuid not null references profiles(id),
  created_at timestamptz not null default now(),
  unique (form_id, beneficiaire_id)
);

-- ----------------------------------------------------------------------------
-- 7. NOTIFICATIONS
-- ----------------------------------------------------------------------------

create table notifications (
  id uuid primary key default gen_random_uuid(),
  destinataire_id uuid not null references profiles(id) on delete cascade,
  titre text not null,
  message text not null,
  lien text,                            -- ex: /fiches/{id}
  lu boolean not null default false,
  created_at timestamptz not null default now()
);

create index idx_notifications_destinataire on notifications(destinataire_id, lu);

-- ----------------------------------------------------------------------------
-- 8. AUDIT / JOURNAL D'ACTIVITÉ
-- ----------------------------------------------------------------------------

create table audit_logs (
  id uuid primary key default gen_random_uuid(),
  acteur_id uuid references profiles(id),
  action text not null,                 -- "creation_fiche", "validation_fiche", "desactivation_compte"...
  cible_type text not null,             -- "form", "equipment", "profile"...
  cible_id uuid,
  ancien_etat jsonb,
  nouvel_etat jsonb,
  created_at timestamptz not null default now()
);

create index idx_audit_acteur on audit_logs(acteur_id);
create index idx_audit_cible on audit_logs(cible_type, cible_id);

-- ----------------------------------------------------------------------------
-- 9. PARAMÈTRES GLOBAUX
-- ----------------------------------------------------------------------------

create table settings (
  cle text primary key,
  valeur jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references profiles(id)
);

-- valeurs par défaut
insert into settings (cle, valeur) values
  ('organisation', '{"nom": "DSI", "logo_url": null}'),
  ('conditions_generales_utilisation', '{"texte": "À compléter par l''administrateur."}'),
  ('numerotation', '{"format": "{PREFIXE}-{ANNEE}-{SEQ5}"}');

-- ============================================================================
-- FONCTIONS UTILITAIRES
-- ============================================================================

-- Résout un matricule vers l'email pro associé, pour permettre la connexion
-- par matricule (le matricule n'est jamais un mot de passe, section 4).
-- SECURITY DEFINER + accès restreint à la seule colonne nécessaire : ne fuite
-- aucune autre donnée du profil à un utilisateur non authentifié.
create or replace function email_from_matricule(p_matricule text) returns text
language sql stable security definer set search_path = public as $$
  select email_pro from profiles where matricule = p_matricule and status = 'actif' limit 1;
$$;
revoke all on function email_from_matricule(text) from public;
grant execute on function email_from_matricule(text) to anon, authenticated;

-- Rôle et service de l'utilisateur courant (utilisés massivement par les policies RLS)
create or replace function current_role_app() returns app_role
language sql stable security definer set search_path = public as $$
  select role from profiles where id = auth.uid();
$$;

create or replace function current_service_id() returns uuid
language sql stable security definer set search_path = public as $$
  select service_id from profiles where id = auth.uid();
$$;

create or replace function current_direction_id() returns uuid
language sql stable security definer set search_path = public as $$
  select direction_id from profiles where id = auth.uid();
$$;

create or replace function is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select current_role_app() in ('admin', 'super_admin');
$$;

-- Vérifie si l'utilisateur courant est actif, sans provoquer de récursion RLS
-- (contrairement à un select direct sur profiles depuis une policy de profiles).
create or replace function current_user_active() returns boolean
language sql stable security definer set search_path = public as $$
  select status = 'actif' from profiles where id = auth.uid();
$$;

-- Numérotation automatique des fiches (empêche les doublons via séquence par type/année)
create table form_sequences (
  form_type_id uuid references form_types(id),
  annee int not null,
  dernier_numero int not null default 0,
  primary key (form_type_id, annee)
);

create or replace function generate_form_number() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_prefixe text;
  v_annee int := extract(year from now());
  v_seq int;
begin
  select prefixe_numero into v_prefixe from form_types where id = new.form_type_id;

  insert into form_sequences (form_type_id, annee, dernier_numero)
  values (new.form_type_id, v_annee, 1)
  on conflict (form_type_id, annee)
  do update set dernier_numero = form_sequences.dernier_numero + 1
  returning dernier_numero into v_seq;

  new.numero := v_prefixe || '-' || v_annee || '-' || lpad(v_seq::text, 5, '0');
  return new;
end;
$$;

create trigger trg_generate_form_number
  before insert on forms
  for each row
  when (new.numero is null)
  execute function generate_form_number();

-- Journalisation automatique des changements de statut de fiche
create or replace function log_form_status_change() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (tg_op = 'UPDATE' and old.statut is distinct from new.statut) then
    insert into form_validations (form_id, etape, ancien_statut, nouveau_statut, validateur_id)
    values (new.id, coalesce(new.etape_courante::text, ''), old.statut, new.statut, auth.uid());

    insert into audit_logs (acteur_id, action, cible_type, cible_id, ancien_etat, nouvel_etat)
    values (auth.uid(), 'changement_statut_fiche', 'form', new.id,
            jsonb_build_object('statut', old.statut), jsonb_build_object('statut', new.statut));
  end if;
  return new;
end;
$$;

create trigger trg_log_form_status
  after update on forms
  for each row execute function log_form_status_change();

-- Notifications automatiques (section 21) : soumission, validation, rejet d'une fiche.
create or replace function form_notify() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  -- Nouvelle soumission : notifier les chefs de service du service concerné
  if (new.statut = 'en_attente' and (tg_op = 'INSERT' or old.statut is distinct from new.statut)) then
    insert into notifications (destinataire_id, titre, message, lien)
    select p.id, 'Fiche à valider', 'La fiche ' || new.numero || ' attend votre validation.', '/fiches/' || new.id
    from profiles p
    where p.service_id = new.service_id and p.role = 'chef_service' and p.status = 'actif';
  end if;

  if (tg_op = 'UPDATE' and old.statut is distinct from new.statut) then
    if new.statut = 'validee' then
      insert into notifications (destinataire_id, titre, message, lien)
      values (new.cree_par, 'Fiche validée', 'Votre fiche ' || new.numero || ' a été validée.', '/fiches/' || new.id);
    elsif new.statut = 'rejetee' then
      insert into notifications (destinataire_id, titre, message, lien)
      values (new.cree_par, 'Fiche rejetée', 'Votre fiche ' || new.numero || ' a été rejetée.', '/fiches/' || new.id);
    end if;
  end if;

  return new;
end;
$$;

create trigger trg_form_notify
  after insert or update on forms
  for each row execute function form_notify();

-- Notification quand un équipement est affecté à un agent qui possède un
-- compte de connexion (les agents sans compte ne peuvent pas être notifiés).
create or replace function equipment_notify() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.type = 'affectation' and new.utilisateur_id is not null then
    insert into notifications (destinataire_id, titre, message, lien)
    select p.id, 'Matériel affecté', 'Un équipement vous a été affecté.', '/parc/' || new.equipment_id
    from profiles p where p.id = new.utilisateur_id and p.status = 'actif';
  end if;
  return new;
end;
$$;

create trigger trg_equipment_notify
  after insert on equipment_movements
  for each row execute function equipment_notify();

-- Mise à jour automatique de updated_at
create or replace function set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_profiles_updated before update on profiles for each row execute function set_updated_at();
create trigger trg_equipments_updated before update on equipments for each row execute function set_updated_at();
create trigger trg_forms_updated before update on forms for each row execute function set_updated_at();

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================

alter table profiles enable row level security;
alter table agents enable row level security;
alter table directions enable row level security;
alter table services enable row level security;
alter table equipment_categories enable row level security;
alter table equipments enable row level security;
alter table equipment_movements enable row level security;
alter table form_types enable row level security;
alter table forms enable row level security;
alter table form_data enable row level security;
alter table form_validations enable row level security;
alter table signatures enable row level security;
alter table documents enable row level security;
alter table form_access_grants enable row level security;
alter table notifications enable row level security;
alter table audit_logs enable row level security;
alter table settings enable row level security;

-- ---- PROFILES ----
-- Tout utilisateur actif peut lire les profils de base (nécessaire pour la sélection
-- intelligente utilisateur/matricule, section 9 du cahier des charges).
-- On autorise toujours la lecture de sa propre ligne (id = auth.uid()) pour permettre
-- à l'app de vérifier son propre statut, et on utilise current_user_active() plutôt
-- qu'un select direct sur profiles pour éviter toute récursion RLS.
create policy profiles_select_all on profiles for select
  using (id = auth.uid() or current_user_active());

create policy profiles_update_self on profiles for update
  using (id = auth.uid())
  with check (id = auth.uid() and role = (select role from profiles where id = auth.uid())); -- ne peut pas s'auto-promouvoir

create policy profiles_admin_all on profiles for all
  using (is_admin()) with check (is_admin());

-- ---- AGENTS ----
-- Lisible par tout utilisateur actif (nécessaire pour la sélection intelligente
-- de bénéficiaire, section 9). Créable/modifiable par ceux qui créent des fiches ;
-- suppression réservée aux admins.
create policy agents_select on agents for select using (
  id = auth.uid() or current_user_active()
);
create policy agents_insert on agents for insert with check (
  current_role_app() in ('admin','super_admin','technicien','stagiaire','chef_service')
);
create policy agents_update on agents for update using (
  current_role_app() in ('admin','super_admin','technicien','chef_service')
);
create policy agents_delete on agents for delete using (is_admin());

-- ---- DIRECTIONS / SERVICES / CATEGORIES / FORM_TYPES : lecture large, écriture admin ----
create policy referentiels_select on directions for select using (true);
create policy referentiels_admin on directions for all using (is_admin()) with check (is_admin());

create policy services_select on services for select using (true);
create policy services_admin on services for all using (is_admin()) with check (is_admin());

create policy categories_select on equipment_categories for select using (true);
create policy categories_admin on equipment_categories for all using (is_admin()) with check (is_admin());

create policy form_types_select on form_types for select using (true);
create policy form_types_admin on form_types for all using (is_admin()) with check (is_admin());

-- ---- EQUIPMENTS ----
-- Lecture : admin/directeur voient tout ; chef_service voit son service ;
-- technicien/stagiaire voient ce qu'ils gèrent ; agent voit son propre matériel.
create policy equipments_select on equipments for select using (
  is_admin()
  or current_role_app() in ('directeur', 'technicien', 'chef_service')
  or utilisateur_actuel_id = auth.uid()
);

create policy equipments_write on equipments for insert with check (
  current_role_app() in ('admin', 'super_admin', 'technicien')
);
create policy equipments_update on equipments for update using (
  current_role_app() in ('admin', 'super_admin', 'technicien')
);
create policy equipments_delete on equipments for delete using (is_admin());

-- ---- EQUIPMENT_MOVEMENTS ----
create policy movements_select on equipment_movements for select using (
  is_admin() or current_role_app() in ('directeur', 'chef_service', 'technicien')
  or utilisateur_id = auth.uid()
);
create policy movements_insert on equipment_movements for insert with check (
  current_role_app() in ('admin', 'super_admin', 'technicien', 'chef_service')
);

-- ---- FORMS ----
-- Règle centrale (section 32) : une fiche n'est visible que par :
--  - son créateur
--  - l'utilisateur concerné par la fiche
--  - un bénéficiaire d'une autorisation explicite (form_access_grants)
--  - le validateur de l'étape courante (chef_service de son service / directeur)
--  - admin / super_admin (accès total, sans autorisation)
create policy forms_select on forms for select using (
  is_admin()
  or cree_par = auth.uid()
  or utilisateur_concerne_id = auth.uid()
  or exists (select 1 from form_access_grants g where g.form_id = forms.id and g.beneficiaire_id = auth.uid())
  or (current_role_app() = 'chef_service' and service_id = current_service_id() and statut in ('en_attente','en_validation'))
  or (current_role_app() = 'directeur' and direction_id = current_direction_id() and statut in ('en_attente','en_validation'))
);

create policy forms_insert on forms for insert with check (
  current_role_app() in ('admin','super_admin','technicien','stagiaire','chef_service')
  and cree_par = auth.uid()
);

create policy forms_update on forms for update using (
  is_admin()
  or (cree_par = auth.uid() and statut in ('brouillon','rejetee'))
  or (current_role_app() = 'chef_service' and service_id = current_service_id() and statut in ('en_attente','en_validation'))
  or (current_role_app() = 'directeur' and direction_id = current_direction_id() and statut in ('en_attente','en_validation'))
);

-- Suppression réservée aux admins (la fiche papier peut être archivée par
-- erreur ou en doublon ; les modules liés (form_data, signatures, documents,
-- form_validations, form_access_grants) sont supprimés en cascade).
create policy forms_delete on forms for delete using (is_admin());

-- ---- FORM_DATA (suit les mêmes droits que la fiche parente) ----
create policy form_data_select on form_data for select using (
  exists (select 1 from forms f where f.id = form_data.form_id)
);
create policy form_data_write on form_data for all using (
  exists (
    select 1 from forms f
    where f.id = form_data.form_id
      and (is_admin() or f.cree_par = auth.uid())
  )
);

-- ---- FORM_VALIDATIONS : lecture liée à la fiche, écriture uniquement système/trigger ----
create policy form_validations_select on form_validations for select using (
  exists (select 1 from forms f where f.id = form_validations.form_id)
);

-- ---- SIGNATURES ----
create policy signatures_select on signatures for select using (
  exists (select 1 from forms f where f.id = signatures.form_id)
);
create policy signatures_insert on signatures for insert with check (signataire_id = auth.uid());

-- ---- DOCUMENTS ----
create policy documents_select on documents for select using (
  exists (select 1 from forms f where f.id = documents.form_id)
);
-- Manquait : sans cette policy, l'enregistrement du code de vérification lors
-- de la génération d'un PDF échouait silencieusement (RLS refuse par défaut
-- toute opération sans policy explicite), rendant la vérification QR impossible.
create policy documents_insert on documents for insert with check (auth.uid() is not null);

-- ---- FORM_ACCESS_GRANTS : seul le créateur de la fiche (ou un admin) peut autoriser ----
create policy grants_select on form_access_grants for select using (
  is_admin() or accorde_par = auth.uid() or beneficiaire_id = auth.uid()
);
create policy grants_insert on form_access_grants for insert with check (
  is_admin() or exists (select 1 from forms f where f.id = form_id and f.cree_par = auth.uid())
);
create policy grants_delete on form_access_grants for delete using (
  is_admin() or accorde_par = auth.uid()
);

-- ---- NOTIFICATIONS ----
create policy notifications_select on notifications for select using (destinataire_id = auth.uid());
create policy notifications_update on notifications for update using (destinataire_id = auth.uid());

-- ---- AUDIT_LOGS : lecture admin uniquement ----
create policy audit_select on audit_logs for select using (is_admin());

-- ---- SETTINGS : lecture large, écriture admin ----
create policy settings_select on settings for select using (true);
create policy settings_admin on settings for all using (is_admin()) with check (is_admin());

-- ============================================================================
-- DONNÉES DE BASE (types de fiches + service DSI)
-- ============================================================================

insert into directions (nom) values ('Direction des Systèmes d''Information');

insert into services (nom, direction_id) values
  ('Support informatique', (select id from directions where nom = 'Direction des Systèmes d''Information')),
  ('Étude et développement', (select id from directions where nom = 'Direction des Systèmes d''Information')),
  ('Exploitation', (select id from directions where nom = 'Direction des Systèmes d''Information'));

insert into equipment_categories (nom, necessite_imei) values
  ('Ordinateur portable', false), ('Ordinateur de bureau', false), ('Téléphone', true),
  ('Tablette', true), ('Imprimante', false), ('Scanner', false), ('Écran', false),
  ('Routeur', false), ('Switch', false), ('Onduleur', false), ('Vidéoprojecteur', false),
  ('Webcam', false), ('Casque audio', false), ('Clavier / Souris', false),
  ('Disque dur externe', false), ('Clé USB', false), ('Accessoire', false), ('Autre', false);

-- Types de fiches : architecture générique, évolutive (section 27 du cahier des charges).
-- Chaque type définit son propre préfixe de numérotation et son propre workflow de validation.
insert into form_types (code, nom, prefixe_numero, workflow) values
  ('FA', 'Fiche d''affectation de matériel', 'FA', '["technicien","chef_service"]'),
  ('RE', 'Fiche de restitution de matériel', 'RE', '["technicien","chef_service"]'),
  ('MA', 'Fiche de maintenance', 'MA', '["technicien","chef_service"]'),
  ('IN', 'Fiche d''incident informatique', 'IN', '["technicien","chef_service"]'),
  ('TR', 'Fiche de transfert de matériel', 'TR', '["technicien","chef_service"]'),
  ('PR', 'Fiche de prêt de matériel', 'PR', '["technicien","chef_service"]'),
  ('RF', 'Fiche de réforme', 'RF', '["technicien","chef_service","directeur"]'),
  ('IV', 'Fiche d''inventaire', 'IV', '["technicien"]'),
  ('MD', 'Fiche de mise à disposition', 'MD', '["technicien","chef_service"]');

-- Équipements de démonstration (non affectés) — à supprimer librement depuis
-- Administration > Matériel ou Parc informatique une fois vos vrais équipements saisis.
insert into equipments (numero_inventaire, numero_serie, categorie_id, marque, modele, etat, capacite, ram, stockage, os) values
  ('INV-2026-0001', 'SN-LAP-0001', (select id from equipment_categories where nom = 'Ordinateur portable'), 'Dell', 'Latitude 5440', 'neuf', null, '16GB', '512GB SSD', 'Windows 11 Pro'),
  ('INV-2026-0002', 'SN-LAP-0002', (select id from equipment_categories where nom = 'Ordinateur portable'), 'HP', 'ProBook 450', 'bon_etat', null, '8GB', '256GB SSD', 'Windows 11 Pro'),
  ('INV-2026-0003', 'SN-LAP-0003', (select id from equipment_categories where nom = 'Ordinateur portable'), 'Lenovo', 'ThinkPad E14', 'bon_etat', null, '16GB', '512GB SSD', 'Windows 11 Pro'),
  ('INV-2026-0004', 'SN-DESK-0001', (select id from equipment_categories where nom = 'Ordinateur de bureau'), 'Dell', 'OptiPlex 7010', 'usage', null, '8GB', '1TB HDD', 'Windows 10 Pro'),
  ('INV-2026-0005', null, (select id from equipment_categories where nom = 'Téléphone'), 'Tecno', 'Camon 40 Pro', 'neuf', '256GB', '16GB', null, 'Android 14'),
  ('INV-2026-0006', null, (select id from equipment_categories where nom = 'Téléphone'), 'Samsung', 'Galaxy A55', 'neuf', '128GB', '8GB', null, 'Android 14'),
  ('INV-2026-0007', null, (select id from equipment_categories where nom = 'Tablette'), 'Samsung', 'Galaxy Tab A9', 'bon_etat', '64GB', '4GB', null, 'Android 14'),
  ('INV-2026-0008', 'SN-IMP-0001', (select id from equipment_categories where nom = 'Imprimante'), 'HP', 'LaserJet Pro M404', 'bon_etat', null, null, null, null),
  ('INV-2026-0009', 'SN-IMP-0002', (select id from equipment_categories where nom = 'Imprimante'), 'Canon', 'imageCLASS MF445dw', 'neuf', null, null, null, null),
  ('INV-2026-0010', 'SN-ECR-0001', (select id from equipment_categories where nom = 'Écran'), 'Dell', 'P2422H 24"', 'neuf', null, null, null, null),
  ('INV-2026-0011', 'SN-ECR-0002', (select id from equipment_categories where nom = 'Écran'), 'HP', 'P24h G5 24"', 'bon_etat', null, null, null, null),
  ('INV-2026-0012', 'SN-RTR-0001', (select id from equipment_categories where nom = 'Routeur'), 'TP-Link', 'Archer AX55', 'bon_etat', null, null, null, null),
  ('INV-2026-0013', 'SN-SW-0001', (select id from equipment_categories where nom = 'Switch'), 'Cisco', 'Catalyst 1000 24P', 'bon_etat', null, null, null, null),
  ('INV-2026-0014', 'SN-OND-0001', (select id from equipment_categories where nom = 'Onduleur'), 'APC', 'Back-UPS 950VA', 'bon_etat', null, null, null, null),
  ('INV-2026-0015', 'SN-VP-0001', (select id from equipment_categories where nom = 'Vidéoprojecteur'), 'Epson', 'EB-X51', 'bon_etat', null, null, null, null),
  ('INV-2026-0016', 'SN-KM-0001', (select id from equipment_categories where nom = 'Clavier / Souris'), 'Logitech', 'MK270', 'neuf', null, null, null, null),
  ('INV-2026-0017', 'SN-HDD-0001', (select id from equipment_categories where nom = 'Disque dur externe'), 'Seagate', 'Expansion 2TB', 'neuf', '2TB', null, null, null),
  ('INV-2026-0018', null, (select id from equipment_categories where nom = 'Clé USB'), 'SanDisk', 'Ultra 64GB', 'neuf', '64GB', null, null, null),
  ('INV-2026-0019', 'SN-LAP-0004', (select id from equipment_categories where nom = 'Ordinateur portable'), 'Dell', 'Latitude 5440', 'defectueux', null, '16GB', '512GB SSD', 'Windows 11 Pro'),
  ('INV-2026-0020', 'SN-SCN-0001', (select id from equipment_categories where nom = 'Scanner'), 'Epson', 'WorkForce ES-400', 'bon_etat', null, null, null, null);

-- ============================================================================
-- INTERVENTIONS — support technique de la DSI sur le terrain
-- ============================================================================
-- Les "types d'intervention" sont administrables (Administration > Types
-- d'intervention), pour que la DSI puisse ajouter/retirer des catégories
-- au fil du temps sans modification de code.

create table intervention_types (
  id uuid primary key default gen_random_uuid(),
  nom text not null unique,
  actif boolean not null default true,
  created_at timestamptz not null default now()
);

insert into intervention_types (nom) values
  ('Dépannage poste de travail'),
  ('Problème réseau / Internet'),
  ('Installation logicielle'),
  ('Maintenance imprimante'),
  ('Assistance téléphonie'),
  ('Formation utilisateur'),
  ('Sécurité / Virus'),
  ('Récupération de données'),
  ('Autre');

create type intervention_priorite as enum ('basse', 'normale', 'haute', 'urgente');
create type intervention_statut as enum ('nouvelle', 'en_cours', 'en_attente_piece', 'resolue', 'annulee');

create table interventions (
  id uuid primary key default gen_random_uuid(),
  numero text not null unique,
  type_id uuid references intervention_types(id),
  priorite intervention_priorite not null default 'normale',
  statut intervention_statut not null default 'nouvelle',
  titre text not null,
  description text,
  solution text,
  agent_concerne_id uuid references agents(id) on delete set null,   -- l'utilisateur qui a le problème
  equipment_id uuid references equipments(id),     -- équipement concerné, si applicable
  technicien_id uuid references profiles(id),       -- qui intervient
  direction_id uuid references directions(id),
  service_id uuid references services(id),
  cree_par uuid not null references profiles(id),
  date_ouverture timestamptz not null default now(),
  date_cloture timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_interventions_statut on interventions(statut);
create index idx_interventions_technicien on interventions(technicien_id);
create index idx_interventions_agent on interventions(agent_concerne_id);
create index idx_interventions_equipment on interventions(equipment_id);

create trigger trg_interventions_updated before update on interventions for each row execute function set_updated_at();

-- Numérotation automatique INT-2026-00001
create table intervention_sequences (
  annee int primary key,
  dernier_numero int not null default 0
);

create or replace function generate_intervention_number() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_annee int := extract(year from now());
  v_seq int;
begin
  insert into intervention_sequences (annee, dernier_numero) values (v_annee, 1)
  on conflict (annee) do update set dernier_numero = intervention_sequences.dernier_numero + 1
  returning dernier_numero into v_seq;
  new.numero := 'INT-' || v_annee || '-' || lpad(v_seq::text, 5, '0');
  return new;
end;
$$;

create trigger trg_generate_intervention_number
  before insert on interventions
  for each row when (new.numero is null)
  execute function generate_intervention_number();

-- Notifications : assignation à un technicien, et résolution pour le créateur
create or replace function intervention_notify() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (tg_op = 'INSERT' or old.technicien_id is distinct from new.technicien_id) and new.technicien_id is not null then
    insert into notifications (destinataire_id, titre, message, lien)
    values (new.technicien_id, 'Intervention assignée', 'L''intervention ' || new.numero || ' vous a été assignée.', '/interventions/' || new.id);
  end if;
  if tg_op = 'UPDATE' and old.statut is distinct from new.statut and new.statut = 'resolue' then
    insert into notifications (destinataire_id, titre, message, lien)
    values (new.cree_par, 'Intervention résolue', 'L''intervention ' || new.numero || ' a été résolue.', '/interventions/' || new.id);
  end if;
  return new;
end;
$$;

create trigger trg_intervention_notify
  after insert or update on interventions
  for each row execute function intervention_notify();

-- ---- RLS ----
alter table intervention_types enable row level security;
alter table interventions enable row level security;

create policy intervention_types_select on intervention_types for select using (true);
create policy intervention_types_admin on intervention_types for all using (is_admin()) with check (is_admin());

-- Visible par : créateur, technicien assigné, chef de service/directeur du
-- service concerné, ou admin (accès total).
create policy interventions_select on interventions for select using (
  is_admin()
  or cree_par = auth.uid()
  or technicien_id = auth.uid()
  or (current_role_app() = 'chef_service' and service_id = current_service_id())
  or (current_role_app() = 'directeur' and direction_id = current_direction_id())
);

create policy interventions_insert on interventions for insert with check (
  current_role_app() in ('admin', 'super_admin', 'technicien', 'stagiaire', 'chef_service')
  and cree_par = auth.uid()
);

create policy interventions_update on interventions for update using (
  is_admin() or cree_par = auth.uid() or technicien_id = auth.uid()
);

create policy interventions_delete on interventions for delete using (is_admin());

-- ============================================================================
-- RAPPORTS DE TRAVAIL — synthèse périodique des interventions d'un technicien
-- ============================================================================

create type rapport_statut as enum ('brouillon', 'soumis', 'valide');

create table rapports_travail (
  id uuid primary key default gen_random_uuid(),
  numero text not null unique,
  technicien_id uuid not null references profiles(id),
  titre text not null,
  periode_debut date not null,
  periode_fin date not null,
  activites_realisees text not null,
  difficultes text,
  recommandations text,
  statut rapport_statut not null default 'brouillon',
  direction_id uuid references directions(id),
  service_id uuid references services(id),
  valide_par uuid references profiles(id),
  date_validation timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Interventions rattachées à un rapport (une intervention peut figurer dans
-- plusieurs rapports si elle chevauche deux périodes, ce qui reste rare)
create table rapport_interventions (
  rapport_id uuid not null references rapports_travail(id) on delete cascade,
  intervention_id uuid not null references interventions(id) on delete cascade,
  primary key (rapport_id, intervention_id)
);

create index idx_rapports_technicien on rapports_travail(technicien_id);
create index idx_rapports_statut on rapports_travail(statut);
create index idx_rapports_service on rapports_travail(service_id);

drop trigger if exists trg_rapports_updated on rapports_travail;
create trigger trg_rapports_updated before update on rapports_travail for each row execute function set_updated_at();

-- Numérotation automatique RT-2026-00001
create table rapport_sequences (
  annee int primary key,
  dernier_numero int not null default 0
);

create or replace function generate_rapport_number() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_annee int := extract(year from now());
  v_seq int;
begin
  insert into rapport_sequences (annee, dernier_numero) values (v_annee, 1)
  on conflict (annee) do update set dernier_numero = rapport_sequences.dernier_numero + 1
  returning dernier_numero into v_seq;
  new.numero := 'RT-' || v_annee || '-' || lpad(v_seq::text, 5, '0');
  return new;
end;
$$;

drop trigger if exists trg_generate_rapport_number on rapports_travail;
create trigger trg_generate_rapport_number
  before insert on rapports_travail
  for each row when (new.numero is null)
  execute function generate_rapport_number();

-- Notifications : soumission au chef de service, validation pour le technicien
create or replace function rapport_notify() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (tg_op = 'UPDATE' and old.statut is distinct from new.statut) then
    if new.statut = 'soumis' then
      insert into notifications (destinataire_id, titre, message, lien)
      select p.id, 'Rapport à valider', 'Le rapport ' || new.numero || ' attend votre validation.', '/rapports/' || new.id
      from profiles p where p.service_id = new.service_id and p.role = 'chef_service' and p.status = 'actif';
    elsif new.statut = 'valide' then
      insert into notifications (destinataire_id, titre, message, lien)
      values (new.technicien_id, 'Rapport validé', 'Votre rapport ' || new.numero || ' a été validé.', '/rapports/' || new.id);
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_rapport_notify on rapports_travail;
create trigger trg_rapport_notify
  after update on rapports_travail
  for each row execute function rapport_notify();

-- ---- RLS ----
alter table rapports_travail enable row level security;
alter table rapport_interventions enable row level security;

create policy rapports_select on rapports_travail for select using (
  is_admin()
  or technicien_id = auth.uid()
  or (current_role_app() = 'chef_service' and service_id = current_service_id())
  or (current_role_app() = 'directeur' and direction_id = current_direction_id())
);

create policy rapports_insert on rapports_travail for insert with check (
  current_role_app() in ('admin', 'super_admin', 'technicien', 'stagiaire', 'chef_service')
  and technicien_id = auth.uid()
);

create policy rapports_update on rapports_travail for update using (
  is_admin()
  or (technicien_id = auth.uid() and statut = 'brouillon')
  or (current_role_app() = 'chef_service' and service_id = current_service_id() and statut = 'soumis')
  or (current_role_app() = 'directeur' and direction_id = current_direction_id() and statut = 'soumis')
);

create policy rapports_delete on rapports_travail for delete using (is_admin());

create policy rapport_interventions_select on rapport_interventions for select using (
  exists (select 1 from rapports_travail r where r.id = rapport_interventions.rapport_id)
);
create policy rapport_interventions_write on rapport_interventions for all using (
  exists (select 1 from rapports_travail r where r.id = rapport_interventions.rapport_id and (is_admin() or r.technicien_id = auth.uid()))
);

-- ============================================================================
-- TYPES DE RAPPORT — catégories configurables (même principe que les types
-- d'intervention et de fiches)
-- ============================================================================

create table rapport_types (
  id uuid primary key default gen_random_uuid(),
  nom text not null unique,
  actif boolean not null default true,
  created_at timestamptz not null default now()
);

insert into rapport_types (nom) values
  ('Rapport hebdomadaire'), ('Rapport mensuel'), ('Rapport de mission'),
  ('Rapport de fin de projet'), ('Rapport d''incident majeur'), ('Autre');

alter table rapports_travail add column if not exists type_id uuid references rapport_types(id);

alter table rapport_types enable row level security;
create policy rapport_types_select on rapport_types for select using (true);
create policy rapport_types_admin on rapport_types for all using (is_admin()) with check (is_admin());

-- ============================================================================
-- STOCKAGE — bucket public pour les images administrables (logo, badge...)
-- ============================================================================

insert into storage.buckets (id, name, public)
values ('assets', 'assets', true)
on conflict (id) do nothing;

create policy assets_public_read on storage.objects for select
  using (bucket_id = 'assets');

create policy assets_admin_write on storage.objects for insert to authenticated
  with check (bucket_id = 'assets' and (select role from profiles where id = auth.uid()) in ('admin', 'super_admin'));

create policy assets_admin_update on storage.objects for update to authenticated
  using (bucket_id = 'assets' and (select role from profiles where id = auth.uid()) in ('admin', 'super_admin'));

create policy assets_admin_delete on storage.objects for delete to authenticated
  using (bucket_id = 'assets' and (select role from profiles where id = auth.uid()) in ('admin', 'super_admin'));

-- Nouveaux paramètres administrables : badge, annonce, apparence
insert into settings (cle, valeur) values
  ('badge', '{"url": "/badge-61ans.png", "actif": true}'),
  ('annonce', '{"texte": "", "actif": false}'),
  ('apparence', '{"animations": true}')
on conflict (cle) do nothing;

-- ============================================================================
-- VÉRIFICATION PUBLIQUE DE DOCUMENT (QR code) — accessible sans authentification
-- ============================================================================
-- Choix explicite du client : la page /verifier affiche l'intégralité des
-- informations de la fiche (établisseur, bénéficiaire, matériel, dates),
-- reproduisant ce qui figure déjà sur le document papier correspondant.

drop function if exists verifier_document(text);

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


-- Voir aussi supabase/migration-modifier-fiche.sql (fonction modifier_fiche)
