-- =====================================================================
-- kucharka_001_init  –  projekt mtb-servis (klpcgnivfvczvvyoqzal)
-- Kuchařka ve vlastním schématu „kucharka“ (přesun z pracovního projektu).
-- Struktura 1:1 s public.* v pracovním projektu + úpravy přístupu:
--   * role: spravce (Vladan) / clen (obecný rodinný účet)
--   * člen: čte, přidává, upravuje; smí mazat SUROVINY (oprava zdvojení)
--   * mazání receptů, stránek, fotek, kategorií, osob, zdrojů a souborů jen správce
--   * hlavní kategorie (rodic_id null) zakládá a mění jen správce
--   * ai_log pro denní strop AI přepisů (zapisuje jen Edge Function)
--   * buckety kucharka-stranky / kucharka-pokrmy: jen image/jpeg, max 3 MB
-- Data (vč. řádků clenove) se nahrají zvlášť v kroku A2.
-- =====================================================================

create extension if not exists unaccent with schema extensions;

create schema kucharka;
comment on schema kucharka is 'Kuchařka – rodinné recepty – VM73/Kucharka';

-- ---------- tabulky ----------
create table kucharka.clenove (
  user_id   uuid primary key references auth.users(id) on delete cascade,
  jmeno     text not null,
  role      text not null default 'clen' check (role in ('spravce','clen')),
  vytvoreno timestamptz not null default now()
);

create table kucharka.osoby (
  id        uuid primary key default gen_random_uuid(),
  jmeno     text not null unique,
  vztah     text,
  vytvoreno timestamptz not null default now()
);

create table kucharka.zdroje (
  id        uuid primary key default gen_random_uuid(),
  nazev     text not null unique,
  vytvoreno timestamptz not null default now()
);

create table kucharka.kategorie (
  id       uuid primary key default gen_random_uuid(),
  nazev    text not null,
  rodic_id uuid references kucharka.kategorie(id) on delete cascade,
  poradi   integer not null default 0,
  unique nulls not distinct (rodic_id, nazev)
);

create table kucharka.recepty (
  id           uuid primary key default gen_random_uuid(),
  nazev        text not null default 'Nový recept',
  kategorie_id uuid references kucharka.kategorie(id) on delete set null,
  autor_id     uuid references kucharka.osoby(id) on delete set null,
  poslal_id    uuid references kucharka.osoby(id) on delete set null,
  zdroj_id     uuid references kucharka.zdroje(id) on delete set null,
  porce        text,
  postup       jsonb not null default '[]'::jsonb,
  poznamky     text,
  upozorneni   jsonb not null default '[]'::jsonb,
  nejista      jsonb not null default '[]'::jsonb,
  nakup        jsonb,
  navrh        jsonb,
  stitky       text[] not null default '{}'::text[],
  stav         text not null default 'ke_kontrole' check (stav in ('ke_kontrole','hotovo')),
  ai_model     text,
  ai_cena_kc   numeric,
  pridal       uuid default auth.uid() references auth.users(id) on delete set null,
  vytvoreno    timestamptz not null default now(),
  upraveno     timestamptz not null default now(),
  hledani      text
);
create index recepty_autor_idx     on kucharka.recepty (autor_id);
create index recepty_kategorie_idx on kucharka.recepty (kategorie_id);

create table kucharka.suroviny (
  id        uuid primary key default gen_random_uuid(),
  recept_id uuid not null references kucharka.recepty(id) on delete cascade,
  skupina   text,
  poradi    integer not null default 0,
  mnozstvi  text,
  cislo     numeric,
  jednotka  text,
  surovina  text not null,
  gramy     numeric
);
create index suroviny_recept_idx on kucharka.suroviny (recept_id, poradi);

create table kucharka.stranky (
  id        uuid primary key default gen_random_uuid(),
  recept_id uuid not null references kucharka.recepty(id) on delete cascade,
  poradi    integer not null default 0,
  cesta     text not null,
  vytvoreno timestamptz not null default now()
);
create index stranky_recept_idx on kucharka.stranky (recept_id, poradi);

create table kucharka.fotky_pokrmu (
  id        uuid primary key default gen_random_uuid(),
  recept_id uuid not null references kucharka.recepty(id) on delete cascade,
  cesta     text not null,
  poradi    integer not null default 0,
  pridal    uuid default auth.uid() references auth.users(id) on delete set null,
  vytvoreno timestamptz not null default now()
);
create index fotky_recept_idx on kucharka.fotky_pokrmu (recept_id, poradi);

-- nové: log AI přepisů (denní strop pro členy, přehled nákladů)
create table kucharka.ai_log (
  id        bigint generated always as identity primary key,
  user_id   uuid references auth.users(id) on delete set null,
  kdy       timestamptz not null default now(),
  model     text,
  tokeny_vstup  integer,
  tokeny_vystup integer,
  cena_kc   numeric,
  ok        boolean not null default true
);
create index ai_log_user_kdy_idx on kucharka.ai_log (user_id, kdy);

-- ---------- funkce ----------
create function kucharka.je_clen() returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from kucharka.clenove where user_id = (select auth.uid())); $$;

create function kucharka.je_spravce() returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from kucharka.clenove where user_id = (select auth.uid()) and role = 'spravce'); $$;

-- unaccent se dvěma argumenty: s prázdným search_path jednoargumentová verze nenajde slovník
create function kucharka.hledej_recepty(dotaz text) returns setof kucharka.recepty
language sql stable set search_path = ''
as $$
  select * from kucharka.recepty
  where hledani like '%' || lower(extensions.unaccent('extensions.unaccent'::regdictionary, dotaz)) || '%'
  order by nazev;
$$;

create function kucharka.recepty_hledani() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  new.upraveno := now();
  new.hledani := lower(extensions.unaccent('extensions.unaccent'::regdictionary,
       coalesce(new.nazev, '') || ' ' ||
       coalesce(new.poznamky, '') || ' ' ||
       coalesce((select string_agg(value, ' ') from jsonb_array_elements_text(new.postup)), '') || ' ' ||
       array_to_string(new.stitky, ' ') || ' ' ||
       coalesce((select string_agg(s.surovina, ' ') from kucharka.suroviny s where s.recept_id = new.id), '')
  ));
  return new;
end $$;

create function kucharka.suroviny_obnov_recept() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  update kucharka.recepty set upraveno = now() where id = coalesce(new.recept_id, old.recept_id);
  return null;
end $$;

create trigger recepty_hledani_trg before insert or update on kucharka.recepty
  for each row execute function kucharka.recepty_hledani();
create trigger suroviny_obnov_trg after insert or update or delete on kucharka.suroviny
  for each row execute function kucharka.suroviny_obnov_recept();

-- ---------- RLS ----------
alter table kucharka.clenove      enable row level security;
alter table kucharka.osoby        enable row level security;
alter table kucharka.zdroje       enable row level security;
alter table kucharka.kategorie    enable row level security;
alter table kucharka.recepty      enable row level security;
alter table kucharka.suroviny     enable row level security;
alter table kucharka.stranky      enable row level security;
alter table kucharka.fotky_pokrmu enable row level security;
alter table kucharka.ai_log       enable row level security;

-- clenove: člen čte (appka zjišťuje roli), spravuje jen správce
create policy "clen cte"        on kucharka.clenove for select to authenticated using ((select kucharka.je_clen()));
create policy "spravce spravuje" on kucharka.clenove for all to authenticated
  using ((select kucharka.je_spravce())) with check ((select kucharka.je_spravce()));

-- osoby, zdroje, recepty, stranky, fotky_pokrmu: člen čte/přidává/upravuje, maže správce
do $$
declare t text;
begin
  foreach t in array array['osoby','zdroje','recepty','stranky','fotky_pokrmu'] loop
    execute format('create policy "clen cte" on kucharka.%I for select to authenticated using ((select kucharka.je_clen()))', t);
    execute format('create policy "clen pridava" on kucharka.%I for insert to authenticated with check ((select kucharka.je_clen()))', t);
    execute format('create policy "clen upravuje" on kucharka.%I for update to authenticated using ((select kucharka.je_clen())) with check ((select kucharka.je_clen()))', t);
    execute format('create policy "spravce maze" on kucharka.%I for delete to authenticated using ((select kucharka.je_spravce()))', t);
  end loop;
end $$;

-- suroviny: člen smí i mazat (appka při uložení receptu suroviny smaže a vloží znovu)
create policy "clen cte"      on kucharka.suroviny for select to authenticated using ((select kucharka.je_clen()));
create policy "clen pridava"  on kucharka.suroviny for insert to authenticated with check ((select kucharka.je_clen()));
create policy "clen upravuje" on kucharka.suroviny for update to authenticated using ((select kucharka.je_clen())) with check ((select kucharka.je_clen()));
create policy "clen maze"     on kucharka.suroviny for delete to authenticated using ((select kucharka.je_clen()));

-- kategorie: člen jen podkategorie (rodic_id není null), hlavní kategorie jen správce
create policy "clen cte" on kucharka.kategorie for select to authenticated using ((select kucharka.je_clen()));
create policy "pridava podkategorie" on kucharka.kategorie for insert to authenticated
  with check ((select kucharka.je_spravce()) or ((select kucharka.je_clen()) and rodic_id is not null));
create policy "upravuje podkategorie" on kucharka.kategorie for update to authenticated
  using ((select kucharka.je_spravce()) or ((select kucharka.je_clen()) and rodic_id is not null))
  with check ((select kucharka.je_spravce()) or ((select kucharka.je_clen()) and rodic_id is not null));
create policy "spravce maze" on kucharka.kategorie for delete to authenticated using ((select kucharka.je_spravce()));

-- ai_log: zapisuje jen Edge Function (service_role obchází RLS), číst smí správce
create policy "spravce cte" on kucharka.ai_log for select to authenticated using ((select kucharka.je_spravce()));

-- ---------- granty ----------
grant usage on schema kucharka to authenticated, service_role;
grant select, insert, update, delete on all tables in schema kucharka to authenticated;
revoke insert, update, delete on kucharka.ai_log from authenticated;
grant all on all tables in schema kucharka to service_role;
grant usage on all sequences in schema kucharka to service_role;

revoke execute on all functions in schema kucharka from public, anon, authenticated;
grant execute on function kucharka.je_clen(), kucharka.je_spravce(), kucharka.hledej_recepty(text) to authenticated;

-- ---------- Storage ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('kucharka-stranky', 'kucharka-stranky', false, 3145728, array['image/jpeg']),
  ('kucharka-pokrmy',  'kucharka-pokrmy',  false, 3145728, array['image/jpeg']);

create policy "kucharka - cteni" on storage.objects for select to authenticated
  using (bucket_id in ('kucharka-stranky','kucharka-pokrmy') and (select kucharka.je_clen()));
create policy "kucharka - nahrani" on storage.objects for insert to authenticated
  with check (bucket_id in ('kucharka-stranky','kucharka-pokrmy') and (select kucharka.je_clen()));
create policy "kucharka - zmena" on storage.objects for update to authenticated
  using (bucket_id in ('kucharka-stranky','kucharka-pokrmy') and (select kucharka.je_clen()))
  with check (bucket_id in ('kucharka-stranky','kucharka-pokrmy') and (select kucharka.je_clen()));
create policy "kucharka - mazani" on storage.objects for delete to authenticated
  using (bucket_id in ('kucharka-stranky','kucharka-pokrmy') and (select kucharka.je_spravce()));

-- ---------- kontrola: žádná funkce ve schématu nesmí být spustitelná pro PUBLIC/anon ----------
do $$
declare f text;
begin
  select string_agg(p.oid::regprocedure::text, ', ') into f
  from pg_proc p
  where p.pronamespace = 'kucharka'::regnamespace
    and (has_function_privilege('anon', p.oid, 'execute')
         or exists (select 1 from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a where a.grantee = 0 and a.privilege_type = 'EXECUTE'));
  if f is not null then
    raise exception 'kucharka_001: funkce spustitelné pro PUBLIC/anon: %', f;
  end if;
end $$;
