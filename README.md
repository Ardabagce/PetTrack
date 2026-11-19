# PetTrack — pet health passport & care tracker

Expo (React Native + TypeScript) app for iPhone, built for the US and European markets.
Languages: English, Spanish, German, French, Dutch. Layout adapts to the unfolded iPhone Duo (two columns, symptom-diary "vet mode").

## Try it

**On your iPhone (no Mac needed)**

```bash
npm install
```

```bash
npx expo start
```

Install **Expo Go** from the App Store and scan the QR code shown in the terminal.

**In the browser:** `npm run web`

## Features

| | Free | Premium |
|---|---|---|
| Today: meals/water check-off with “who fed”, coming up, weight trend | ✓ | ✓ |
| Vaccines with booster notifications, vet journal, weight, expenses | ✓ | ✓ |
| Food safety lookup (51 items, offline, poison hotlines) | ✓ | ✓ |
| Visit preparation (summary + questions for the vet) | ✓ | PDF |
| Symptom photo diary with day-by-day viewer | 1 case | unlimited + PDF |
| Family sharing – “Who fed the dog?”, double-feeding warning | – | ✓ |
| Scan vet reports → visit record (5 languages) | – | ✓ |
| Shareable PDF health passport | preview | ✓ |
| US ⇄ Europe travel planner (USDA/EU/UK/CDC rules, countdown reminders) | – | ✓ |
| Insurance claim pack (invoice + report + symptom diary PDF, claim tracking) | – | ✓ |
| Collar QR tag, lost-pet mode, printable poster, finder messages | – | ✓ |
| Food transition planner, cost insights, unlimited pets/reminders | – | ✓ |

Promise: data is never locked – viewing and JSON export stay free.

Subscriptions: monthly $4.99 / yearly $34.99, 3-day free trial. Expo Go and web use a simulated store
(`src/lib/premium.ts`); the App Store build plugs in RevenueCat with products `premium.monthly` / `premium.yearly`.

## Project layout

- `src/app` – screens (Expo Router). `(tabs)` = Today, Health, Nutrition, Passport + floating icon-only tab bar
- `src/lib` – data store (zustand + AsyncStorage), domain logic (parser, travel rules, diet plan, food safety), PDF templates, notifications
- `src/components` – design system (“Linen & Forest”), charts, date fields
- `src/i18n` – generated translations. Edit `tools/translations*.py`, then `npm run strings`
- `server/` – FastAPI backend for Coolify: household sync, collar-tag pages `/p/<slug>`, lost mode, finder messages, Tesseract OCR

## Checks

```bash
npm run typecheck && npm test
```

```bash
cd server && pip install -r requirements.txt pytest httpx && pytest
```

## Backend on Coolify

1. New resource → your GitHub repo → build pack **Dockerfile**. Base Directory `/` (repo root),
   Dockerfile Location `/Dockerfile` or `/server/Dockerfile` (identical; both expect the repo root as context).
2. Ports Exposes `8000`. Storage: persistent volume mounted at `/data`. Attach a domain (e.g. `api.pettrack.app`).
3. Health check path `/health`.
4. Build the app with `EXPO_PUBLIC_API_URL=https://api.pettrack.app`.

Hosting is in the EU if you pick an EU server – recommended for GDPR. The server stores no names or e-mails
except the first name family members choose to show.

## Not yet done

- Widgets & Apple Watch app (native Swift targets via `expo-apple-targets`, need an EAS development build)
- RevenueCat wiring and App Store Connect products
- App icon, privacy policy & terms pages
- Translations of the 51 food-safety notes (names are translated)
