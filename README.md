# Support — Plateforme numérique DSI

Digitalisation des fiches papier (affectation de matériel, restitution...) et
gestion du parc informatique de la DSI. Nuxt 3 + Supabase, web + mobile via Capacitor.

## 1. Installation

```powershell
cd support
npm install
```

## 2. Configuration Supabase

1. Créez un projet sur https://supabase.com
2. Copiez `.env.example` vers `.env` et renseignez `SUPABASE_URL`, `SUPABASE_KEY`
   (Project Settings → API → Project URL / anon public key) **et** `SUPABASE_SERVICE_ROLE_KEY`
   (Project Settings → API → service_role secret — nécessaire pour que l'administrateur
   puisse créer des comptes utilisateurs depuis l'application ; cette clé n'est jamais
   envoyée au navigateur, elle n'est lue que par le serveur Nuxt dans `server/api/`)
3. Dans l'éditeur SQL de Supabase, exécutez le contenu de `supabase/schema.sql`
   (crée toutes les tables, les policies RLS, les triggers de numérotation, etc.)
4. Créez votre tout premier compte super admin (les suivants se créeront directement
   depuis l'application, voir section 6) :
   - Inscrivez-vous via Supabase Auth (dashboard → Authentication → Add user,
     cochez "Auto Confirm User")
   - Insérez sa ligne dans `profiles` avec `role = 'super_admin'`, `status = 'actif'`
     et `doit_changer_mdp = false`

## 3. Lancer en développement

```powershell
npm run dev
```

L'application est disponible sur http://localhost:3000

## 4. Build mobile (Capacitor)

```powershell
npm run generate          # build statique dans .output/public
npx cap add android        # première fois seulement
npx cap add ios             # première fois seulement (nécessite macOS + Xcode)
npm run cap:android         # sync + ouvre Android Studio
npm run cap:ios              # sync + ouvre Xcode
```

## 5. Mise à jour du projet (workflow avec dossier "support-nouveau")

Quand vous recevez un nouveau zip dans `support-nouveau`, remplacez le dossier
concerné puis relancez :

```powershell
# 1. Remplacer le dossier concerné (exemple : pages)
Remove-Item -Recurse -Force "C:\Users\kalif\Desktop\support\pages" -ErrorAction SilentlyContinue
Copy-Item -Recurse -Force "C:\Users\kalif\Documents\support-nouveau\support\pages" "C:\Users\kalif\Desktop\support\pages"

# 2. Vider le cache et relancer
Set-Location "C:\Users\kalif\Desktop\support"
Remove-Item -Recurse -Force ".nuxt" -ErrorAction SilentlyContinue
npm install
npm run dev
```

## 6. Créer les autres comptes (depuis l'application)

Une fois connecté en super admin, allez dans **Administration → Utilisateurs → Créer un utilisateur**.
Renseignez matricule, nom, email professionnel, rôle, direction/service, puis un mot de
passe temporaire (généré automatiquement, modifiable). Communiquez matricule + mot de
passe temporaire à la personne concernée.

À sa première connexion, l'utilisateur verra une proposition : garder ce mot de passe
ou le modifier immédiatement (3 champs : mot de passe actuel, nouveau, confirmation).

## 7. Ce qui est livré dans ce zip (MVP)

- Authentification par matricule + mot de passe (Supabase Auth)
- Rôles et permissions (super_admin, admin, directeur, chef_service, technicien, stagiaire, agent)
- RLS complet : chaque fiche n'est visible que par son créateur, l'utilisateur concerné,
  la hiérarchie de validation, ou une personne explicitement autorisée — sauf admin/super_admin
  qui voient tout sans restriction
- Tableau de bord adapté au rôle
- Module Fiches : création (sélection intelligente direction → service → utilisateur,
  recherche par matricule), soumission, validation/rejet, historique, génération PDF + QR code
- Module Parc informatique : liste, fiche détaillée, historique des mouvements
- Recherche globale (fiches, matricule, n° série, IMEI, n° inventaire)
- Espace Administration : statistiques, gestion utilisateurs (création avec mot de passe
  temporaire, rôles/statuts), directions/services, catégories de matériel, types de fiches,
  paramètres — chacun avec création **et suppression**
- Données de référence enrichies : 18 catégories de matériel, 9 types de fiches
  (affectation, restitution, maintenance, incident, transfert, prêt, réforme, inventaire,
  mise à disposition), 20 équipements de démonstration prêts à consulter/supprimer
- Interface responsive mobile-first (sidebar desktop / navigation basse mobile)
- Structure Capacitor prête pour Android et iOS

## 7. À développer ensuite (voir cahier des charges)

- Édition de fiche en brouillon (formulaire pré-rempli)
- Workflow de validation multi-étapes configurable par type de fiche (directeur inclus)
- Signature manuscrite sur écran
- Autres types de fiches (maintenance, incident, transfert, prêt, réforme...)
- Journal d'audit détaillé côté UI (table `audit_logs` déjà en place)
- Notifications automatiques déclenchées par les triggers de changement de statut

## Structure du projet

```
support/
├── pages/           # Routes de l'application
├── components/       # Composants réutilisables
├── composables/       # useProfile, etc.
├── middleware/         # auth.global.ts, role.ts
├── layouts/             # default (app), auth (login)
├── supabase/             # schema.sql — schéma complet + RLS
├── capacitor.config.ts    # config mobile
└── nuxt.config.ts          # config Nuxt
```
