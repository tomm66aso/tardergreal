# TraderGuardians — Guida Deploy Completa

## Struttura file da caricare su GitHub

```
traderguardians/
├── index.html                  ← Homepage
├── login.html                  ← Login con codice invito
├── market-intel.html           ← Market Intelligence
├── segnali.html                ← Segnali Operativi
├── news.html                   ← News & Mercati
├── trader-card.html            ← Trader Card
├── mobile-preview.html         ← Preview mobile (opzionale)
├── vercel.json                 ← Configurazione Vercel
├── supabase-schema.sql         ← Schema database (non caricare su GitHub pubblico)
└── api/
    ├── invoke-llm.js           ← Proxy Gemini AI
    └── update-news-snapshots.js ← Cron job notizie
```

---

## STEP 1 — GitHub

1. Vai su github.com → Sign up (se non hai account)
2. Clicca "+" → "New repository"
3. Nome: `traderguardians` → Public → Create
4. Clicca "uploading an existing file"
5. Trascina tutti i file HTML + vercel.json
6. Per la cartella api: clicca "Add file" → "Create new file"
   - Nome: `api/invoke-llm.js` → incolla il contenuto
   - Nome: `api/update-news-snapshots.js` → incolla il contenuto
7. Commit changes dopo ogni upload

---

## STEP 2 — Supabase

1. Vai su supabase.com → New project
2. Scegli nome, password database, regione Europe (Frankfurt)
3. Aspetta ~2 minuti che si avvii
4. Vai su "SQL Editor" → "New query"
5. Incolla tutto il contenuto di `supabase-schema.sql`
6. Clicca "Run" → vedrai "Success"
7. Vai su Settings → API → copia:
   - Project URL → sarà SUPABASE_URL
   - anon/public key → sarà SUPABASE_ANON_KEY
   - service_role key → sarà SUPABASE_SERVICE_KEY

---

## STEP 3 — Gemini API (gratis)

1. Vai su aistudio.google.com
2. Accedi con Google
3. Clicca "Get API Key" → "Create API key"
4. Copia la chiave (inizia con AIza...)

---

## STEP 4 — Vercel

1. Vai su vercel.com → "Continue with GitHub"
2. Autorizza Vercel
3. "Add New Project" → seleziona repo `traderguardians`
4. Framework Preset: **Other** (IMPORTANTE)
5. Clicca Deploy → aspetta 60 secondi

### Aggiungi variabili d'ambiente:
Settings → Environment Variables → aggiungi una per una:

| Nome                  | Valore                        |
|-----------------------|-------------------------------|
| GEMINI_API_KEY        | AIza... (da Google AI Studio) |
| SUPABASE_URL          | https://xxx.supabase.co       |
| SUPABASE_SERVICE_KEY  | eyJ... (service_role)         |
| CRON_SECRET           | una password a caso lunga     |

Dopo aver aggiunto le variabili → clicca Redeploy

---

## STEP 5 — Attiva la AI reale

In ogni file HTML cambia:
```js
const API_MODE = 'demo';
// in:
const API_MODE = 'production';
```

Poi ricarica i file su GitHub → Vercel si aggiorna da solo.

---

## STEP 6 — Google OAuth (per login con Google)

1. Vai su console.cloud.google.com
2. Crea progetto → API & Services → Credentials
3. Create OAuth 2.0 Client ID → Web application
4. Authorized redirect URIs: `https://xxx.supabase.co/auth/v1/callback`
5. Copia Client ID e Client Secret
6. In Supabase → Authentication → Providers → Google → abilita e incolla

---

## URL finale

Il sito sarà live su: `https://traderguardians.vercel.app`

Pagine:
- / → index.html (homepage)
- /login.html
- /market-intel.html
- /segnali.html
- /news.html
- /trader-card.html
