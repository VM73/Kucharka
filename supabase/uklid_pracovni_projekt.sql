-- =====================================================================
-- Úklid Kuchařky z PRACOVNÍHO projektu „servisní záznamy“ (pqehuuamgecmdmrdhmza)
-- SPUŠTĚNO 19. 11. 2026 jako migrace kucharka_uklid_po_presunu (v pracovním projektu).
-- Buckety stranky/pokrmy smazány předtím v Dashboardu; Edge Function kucharka
-- a secrety ANTHROPIC_API_KEY a AI_PROVIDER smazány v Dashboardu po SQL.
-- Průzkum 19. 11. 2026: tabulky/funkce níže používá jen Kuchařka;
-- opravneni/kalibrace mají vlastní funkce ve svých schématech, novy_uzivatel
-- ani klima/servis na tyto tabulky nesahají; FK vedou jen mezi tabulkami Kuchařky.
--
-- KROK 0 (před SQL): buckety „stranky“ (23 souborů) a „pokrmy“ (1 soubor)
--   smazat v Dashboardu → Storage (SQL mazání ze storage tabulek Supabase blokuje).
-- =====================================================================
begin;

-- Storage politiky Kuchařky
drop policy "kucharka cte"      on storage.objects;
drop policy "kucharka nahrava"  on storage.objects;
drop policy "kucharka upravuje" on storage.objects;
drop policy "kucharka maze"     on storage.objects;

-- hledej_recepty vrací typ recepty → musí jít před tabulkou
drop function public.hledej_recepty(text);

-- Tabulky (pořadí podle cizích klíčů, bez CASCADE)
drop table public.suroviny;
drop table public.stranky;
drop table public.fotky_pokrmu;
drop table public.recepty;
drop table public.kategorie;
drop table public.osoby;
drop table public.zdroje;
drop table public.clenove;

-- Funkce
drop function public.recepty_hledani();
drop function public.suroviny_obnov_recept();
drop function public.je_clen();
drop function public.je_spravce();
drop function public.kucharka_smi();

-- Přístup do appky
update public.profily set aplikace = array_remove(aplikace, 'kucharka')
 where 'kucharka' = any(aplikace);

commit;
