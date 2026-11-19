# Kuchařka – poznámky pro Claude Code

Mobilní webová appka (PWA na GitHub Pages) pro digitalizaci rodinných receptů z fotek: `index.html` (celá appka), `sw.js` (service worker – při změně zvýšit `CACHE`), `index.ts` (Supabase Edge Function).

## Supabase
- Projekt **mtb-servis** (`klpcgnivfvczvvyoqzal`) – osobní projekt, od v1.4 (19. 11. 2026). Dříve pracovní projekt „servisní záznamy“ (`pqehuuamgecmdmrdhmza`) – už nepoužívat.
- Schéma **`kucharka`** (v klientovi `db: { schema: 'kucharka' }`, schéma je v Exposed schemas): tabulky clenove, osoby, zdroje, kategorie, recepty, suroviny, stranky, fotky_pokrmu, ai_log; funkce `je_clen`, `je_spravce`, `hledej_recepty`; RLS.
- Storage buckety **`kucharka-stranky`** / **`kucharka-pokrmy`** (soukromé, jen image/jpeg, max 3 MB). V `index.html` mapa `BUCKET` převádí interní názvy `stranky` / `pokrmy`.
- Edge Function **`kucharka`** (v4, soubor `index.ts`). Secret `ANTHROPIC_API_KEY` (Anthropic workspace kucharka, limit $5/měs.).
- Secrety v mtb-servis jsou společné pro celý projekt – další appky musí mít secrety s prefixem svého slugu.
- Do Supabase nasazovat jen na výslovný pokyn.

## Role a pravidla (RLS)
- Člen čte / přidává / upravuje, smí mazat suroviny.
- Mazání receptů, stránek, fotek, osob, zdrojů, kategorií a souborů ve Storage jen **správce**.
- Hlavní kategorie (`rodic_id` null) zakládá a mění jen správce.
- Edge Function: člen max. 20 AI přepisů za 24 h.
- Rodinný účet `vladanmarekcooking@gmail.com` = role `clen`.

## Migrace (`supabase/migrations/`)
- `kucharka_001_init.sql` – schéma, tabulky, funkce, RLS, buckety (spuštěno v mtb-servis).
- `kucharka_001_rollback.sql` – rollback k 001.
- `kucharka_002_clen_maze_rozpracovane.sql` – člen smí mazat stránky a fotky pokrmu u receptů `ke_kontrole` (tabulky i Storage) + `kucharka.ping()` pro týdenní ping (anon, vrací jen true). Rollback `kucharka_002_rollback.sql`.
- `kucharka_002b_ping_usage` – grant usage on schema kucharka to anon (spuštěno samostatně v Supabase 19. 11.; v souboru 002 je grant uveden také).

## Ping
- `.github/workflows/ping.yml` – po a čt volá `rpc/ping` (schéma kucharka) s publishable klíčem; drží mtb-servis aktivní.

## Otevřené body
- v1.5 nasazena 19. 11. – ověřit na rodinném účtu (vladanmarekcooking@gmail.com) mazání stránky u rozpracovaného receptu.
- Záloha (pg_dump) mtb-servis – zatím není.
- Úklid pracovního projektu (`pqehuuamgecmdmrdhmza`) po přesunu – průzkum hotový 19. 11.
