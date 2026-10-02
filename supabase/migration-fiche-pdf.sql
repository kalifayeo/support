-- À exécuter une fois dans l'éditeur SQL de Supabase.
-- Bucket PRIVÉ pour le téléchargement des PDF depuis l'application mobile.
insert into storage.buckets (id, name, public)
values ('fiches', 'fiches', false)
on conflict (id) do nothing;

drop policy if exists fiches_insert on storage.objects;
create policy fiches_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'fiches');

drop policy if exists fiches_select on storage.objects;
create policy fiches_select on storage.objects for select to authenticated
  using (bucket_id = 'fiches');
