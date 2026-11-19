# ZADANI – Kuchařka v1.4: přepnutí na projekt mtb-servis

## Kontext (hotovo v chatu 19. 11. 2026)
Kuchařka se stěhuje z pracovního Supabase projektu „servisní záznamy“ (pqehuuamgecmdmrdhmza) do osobního projektu **mtb-servis** (`klpcgnivfvczvvyoqzal`), aby pracovní projekt zůstal čistě pracovní.
V mtb-servis už je hotové a ověřené (kontrolní součty 1:1):
- schéma **`kucharka`** (migrace `kucharka_001_init`): tabulky clenove, osoby, zdroje, kategorie, recepty, suroviny, stranky, fotky_pokrmu, ai_log; funkce `je_clen`, `je_spravce`, `hledej_recepty`; RLS; schéma je v Exposed schemas
- data: 23 receptů, 228 surovin, 28 kategorií, 5 osob, 23 stránek, 1 foto, správce Vladan
- buckety **`kucharka-stranky`**, **`kucharka-pokrmy`** (soukromé, jen image/jpeg, max 3 MB) – 24 souborů přeneseno, cesty stejné
- Edge Function **`kucharka` v4** (soubor `index.ts` vedle tohoto zadání), secret `ANTHROPIC_API_KEY` (workspace kucharka, limit $5/měs.)

Pravidla přístupu (RLS): člen čte / přidává / upravuje, smí mazat suroviny; mazání receptů, stránek, fotek, osob, zdrojů a kategorií a souborů ve Storage jen **správce**; hlavní kategorie (rodic_id null) zakládá a mění jen správce. Edge Function: člen max. 20 AI přepisů za 24 h.

## Úkol (jedna etapa, malé chirurgické změny)
1. `index.html`
   - `SUPABASE_URL = 'https://klpcgnivfvczvvyoqzal.supabase.co'`
   - `SUPABASE_KEY = 'sb_publishable_6mo7Xg3GQ4GTi9Qu7AAeKw_HKPSXacV'`
   - v `supabase.createClient(...)` přidat `db: { schema: 'kucharka' }` a změnit `storageKey: 'kucharka-auth'` na **`'kucharka-auth-2'`** (všechna zařízení se tím odhlásí a musí se přihlásit znovu – záměr)
   - buckety: všude, kde se volá `sb.storage.from(...)`, používat `kucharka-stranky` místo `stranky` a `kucharka-pokrmy` místo `pokrmy`. Nejjednodušeji jedna mapa `const BUCKET = { stranky: 'kucharka-stranky', pokrmy: 'kucharka-pokrmy' }` použitá jen uvnitř volání `sb.storage.from(BUCKET[bucket] ?? bucket)`; volání tabulek (`sb.from('stranky')` apod.) beze změny
   - tlačítka **Smazat stránku** (`data-a="smazStranu"`) a **Smazat fotku** (`data-a="smazFotku"`) zobrazit jen správci (`S.clen?.role === 'spravce'`), stejně jako už je to u „Smazat recept“
   - `VERZE = '1.4'`
   - demo režim (`?demo`) a `?debug` ponechat funkční
2. `sw.js`: `CACHE = 'kucharka-v1-4'`
3. `index.ts` v repu nahradit souborem `index.ts` z této složky (Edge Function v4 – už je nasazená v mtb-servis, do Supabase nic nenasazovat)
4. `CLAUDE.md` (založit, pokud není) – zapsat:
   - Supabase: projekt mtb-servis `klpcgnivfvczvvyoqzal`, schéma `kucharka`, buckety `kucharka-stranky` / `kucharka-pokrmy`, Edge Function `kucharka` (v4), secret `ANTHROPIC_API_KEY` (Anthropic workspace kucharka, limit $5)
   - pravidla rolí (viz výše), rodinný účet `vladanmarekcooking@gmail.com` = role clen
   - secrety v mtb-servis jsou společné pro celý projekt; další appky musí mít secrety s prefixem slugu
   - migrace: `kucharka_001_init` (uložená v `supabase/migrations/` – soubor dodá chat později)
   - otevřené body: kucharka_002 (člen nemůže smazat špatnou fotku stránky u rozpracovaného receptu – rozhodnout), týdenní ping proti uspání + záloha, úklid pracovního projektu
5. `NAKLADY.md` – přidat řádek etapy „Přesun do mtb-servis (chat 19. 11.)“: chat ~240 tis. tokenů, Supabase mtb-servis +0,6 MB DB, +13,8 MB Storage, +1 Edge Function, Anthropic 0 Kč (zatím bez volání), GitHub 0 min.

## Ověření (kritérium hotovo)
- `node --check` na skript z `index.html` (vytáhnout obsah `<script>` do dočasného souboru) projde
- `grep` v `index.html`: žádný výskyt `pqehuuamgecmdmrdhmza`, žádné `storage.from('stranky'` ani `storage.from('pokrmy'`
- Playwright (pokud je k dispozici): otevřít `index.html?demo` na iPhone 13 a 320 px – načte se seznam receptů, v patičce „verze 1.4“, bez chyb v konzoli
- commit `Kuchařka v1.4 – přepnutí na mtb-servis (schéma kucharka)` a push do `main`

Po pushi napiš krátké shrnutí (co se změnilo, výsledky kontrol, hash commitu). Ověření živé appky na iPhonu udělá Vladan s chatem.
