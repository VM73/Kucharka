-- =====================================================================
-- Úklid Kuchařky z PRACOVNÍHO projektu „servisní záznamy“ (pqehuuamgecmdmrdhmza)
-- NEspouštět v mtb-servis! Spustit až po ověření v1.4/v1.5 v mtb-servis.
-- Průzkum 19. 11. 2026: tabulky/funkce níže používá jen Kuchařka;
-- opravneni/kalibrace mají vlastní funkce ve svých schématech, novy_uzivatel
-- ani klima/servis na tyto tabulky nesahají; FK vedou jen mezi tabulkami Kuchařky.
--
-- KROK 0 (před SQL): buckety „stranky“ (23 souborů) a „pokrmy“ (1 soubor)
--   vyprázdnit a smazat v Dashboardu → Storage (SQL mazání souborů Supabase blokuje).
-- =====================================================================
begin;

-- Storage politiky Kuchařky
drop policy "kucharka cte"      on storage.objects;
drop policy "kucharka nahrava"  on storage.objects;
drop policy "kucharka upravuje" on storage.objects;
drop policy "kucharka maze"     on storage.objects;

-- Tabulky (pořadí podle cizích klíčů, bez CASCADE – kdyby na ně něco jiného
-- nečekaně odkazovalo, migrace spadne a nic se nesmaže)
drop table public.suroviny;
drop table public.stranky;
drop table public.fotky_pokrmu;
drop table public.recepty;
drop table public.kategorie;
drop table public.osoby;
drop table public.zdroje;
drop table public.clenove;

-- Funkce
drop function public.hledej_recepty(text);
drop function public.recepty_hledani();
drop function public.suroviny_obnov_recept();
drop function public.je_clen();
drop function public.je_spravce();
drop function public.kucharka_smi();

-- Přístup do appky
update public.profily set aplikace = array_remove(aplikace, 'kucharka')
 where 'kucharka' = any(aplikace);

-- Buckety (projdou jen prázdné – viz KROK 0)
delete from storage.buckets where id in ('stranky','pokrmy');

commit;

-- Po SQL ručně / přes konektor: smazat Edge Function „kucharka“ v pracovním projektu
-- (Dashboard → Edge Functions → kucharka → Delete) a její secret ANTHROPIC_API_KEY,
-- pokud ho nepoužívá jiná appka.
