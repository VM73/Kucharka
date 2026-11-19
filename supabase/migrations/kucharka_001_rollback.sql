-- kucharka_001_rollback – mtb-servis (klpcgnivfvczvvyoqzal)
-- Vrátí stav před kucharka_001_init. Použít JEN před přepnutím appky
-- (po nahrání dat by se smazala i data Kuchařky v mtb-servis).
-- Ostatní appky (mtb_*, fplyny) se nemění. Rozšíření unaccent se ponechá.

drop policy if exists "kucharka - cteni"   on storage.objects;
drop policy if exists "kucharka - nahrani" on storage.objects;
drop policy if exists "kucharka - zmena"   on storage.objects;
drop policy if exists "kucharka - mazani"  on storage.objects;

-- Buckety jdou smazat jen prázdné. Pokud už obsahují soubory nebo Supabase
-- mazání přes SQL odmítne: Dashboard → Storage → bucket → Empty → Delete.
delete from storage.buckets where id in ('kucharka-stranky','kucharka-pokrmy');

drop schema if exists kucharka cascade;
