-- =====================================================================
-- kucharka_002_clen_maze_rozpracovane  –  projekt mtb-servis (klpcgnivfvczvvyoqzal)
-- 1) Člen smí smazat stránku (fotku originálu) a fotku pokrmu, ale jen
--    u receptu ve stavu 'ke_kontrole'. U hotových receptů maže dál jen správce.
--    Platí pro řádky v tabulkách i pro soubory ve Storage
--    (cesta souboru = <recept_id>/<soubor>.jpg – ověřeno na všech 24 souborech).
-- 2) kucharka.ping() – týdenní ping z GitHub Actions proti uspání projektu.
--    Vědomá výjimka z pravidla „anon nic“: vrací jen true, nečte žádná data.
-- =====================================================================
begin;

-- ---------- 1) mazání u rozpracovaných receptů ----------
create function kucharka.clen_smi_mazat(recept text) returns boolean
language sql stable security definer set search_path = ''
as $$
  select (select kucharka.je_clen())
     and exists (select 1 from kucharka.recepty r
                 where r.id::text = recept and r.stav = 'ke_kontrole');
$$;

create policy "clen maze u rozpracovanych" on kucharka.stranky for delete to authenticated
  using ((select kucharka.clen_smi_mazat(recept_id::text)));
create policy "clen maze u rozpracovanych" on kucharka.fotky_pokrmu for delete to authenticated
  using ((select kucharka.clen_smi_mazat(recept_id::text)));

create policy "kucharka - mazani clen rozpracovane" on storage.objects for delete to authenticated
  using (bucket_id in ('kucharka-stranky','kucharka-pokrmy')
         and kucharka.clen_smi_mazat((storage.foldername(name))[1]));

-- ---------- 2) ping ----------
create function kucharka.ping() returns boolean
language sql stable set search_path = ''
as $$ select true; $$;

-- ---------- granty ----------
revoke execute on all functions in schema kucharka from public, anon, authenticated;
grant execute on function kucharka.je_clen(), kucharka.je_spravce(), kucharka.hledej_recepty(text),
  kucharka.clen_smi_mazat(text) to authenticated;
grant execute on function kucharka.ping() to anon, authenticated;

-- ---------- kontrola: PUBLIC nic, anon jen ping ----------
do $$
declare f text;
begin
  select string_agg(p.oid::regprocedure::text, ', ') into f
  from pg_proc p
  where p.pronamespace = 'kucharka'::regnamespace
    and p.proname <> 'ping'
    and (has_function_privilege('anon', p.oid, 'execute')
         or exists (select 1 from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
                    where a.grantee = 0 and a.privilege_type = 'EXECUTE'));
  if f is not null then
    raise exception 'kucharka_002: funkce spustitelné pro PUBLIC/anon: %', f;
  end if;
end $$;

commit;
