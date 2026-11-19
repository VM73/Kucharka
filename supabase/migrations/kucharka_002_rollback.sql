-- kucharka_002_rollback – mtb-servis (klpcgnivfvczvvyoqzal)
-- Vrátí stav po kucharka_001: mazání stránek a fotek opět jen správce, bez pingu.
begin;
drop policy if exists "kucharka - mazani clen rozpracovane" on storage.objects;
drop policy if exists "clen maze u rozpracovanych" on kucharka.stranky;
drop policy if exists "clen maze u rozpracovanych" on kucharka.fotky_pokrmu;
drop function if exists kucharka.clen_smi_mazat(text);
drop function if exists kucharka.ping();
commit;
