# App Store Connect + RevenueCat setup

## 1. App Store Connect
1. **Apps → + New App**: platform iOS, name (must be unique, e.g. "PetTrack: Pet Health Passport"),
   primary language English (U.S.), bundle ID `com.pettrack.app` (register it under Certificates, IDs & Profiles
   first; if it is taken, tell Claude the new one), SKU `pettrack-ios`.
2. **Monetization → Subscriptions → Subscription group** "PetTrack Premium" with two auto-renewable subscriptions:

   | Reference name | Product ID | Duration | Price | Introductory offer |
   |---|---|---|---|---|
   | Premium Monthly | `pettrack_premium_monthly` | 1 month | $4.99 (tier) | Free trial, 3 days, new subscribers |
   | Premium Yearly | `pettrack_premium_yearly` | 1 year | $34.99 (tier) | Free trial, 3 days, new subscribers |

   Add a display name + description (EN, ES, DE, FR, NL), and a review screenshot of the paywall
   (Settings → Upgrade to Premium).
3. **App Privacy** (see table below), **Age rating**: answer "Yes" to user-generated content → usually 12+.
4. **App Information**: Privacy Policy URL `https://pettrack.bagce.dev/privacy`, Support URL
   `https://pettrack.bagce.dev/support`, Marketing URL `https://pettrack.bagce.dev`.
   License agreement: Apple standard EULA, plus our terms at `https://pettrack.bagce.dev/terms` in the description.
5. **Users and Access → Integrations → In-App Purchase** key (for RevenueCat) and **App Store Connect API**
   key with "App Manager" role (for EAS Build/Submit). Download both .p8 files.

## 2. RevenueCat (done via API on 19 Nov 2026)
Project `projb5c3510d` "PetTrack": App Store app `app414ee2a7df` (bundle `com.pettrack.app`), products
`pettrack_premium_monthly` / `pettrack_premium_yearly`, entitlement `pettrack_pro`, offering `default`
with `$rc_monthly` / `$rc_annual`. Public iOS key is in `app.json → extra.revenueCatIosKey`.
Still needed in the RevenueCat dashboard: App Store app → upload the **In-App Purchase key (.p8)** so RevenueCat
can validate purchases.

Original manual steps, for reference:
1. New project "PetTrack" → add **App Store** app with bundle ID `com.pettrack.app`, upload the In-App Purchase key.
2. **Entitlements**: `pettrack_pro` – attach both products.
3. **Offerings**: `default` (current) with packages **$rc_monthly** → `pettrack_premium_monthly`
   and **$rc_annual** → `pettrack_premium_yearly`.
4. Copy the **public iOS SDK key** (starts with `appl_`) and give it to Claude – it is safe to put in the app.

## 3. EAS Build & Submit
1. expo.dev → project **pettrack** → Credentials → iOS → add the App Store Connect API key.
2. Then Claude can run `eas build -p ios --profile production` and `eas submit -p ios` for TestFlight.

## App Privacy answers
| Data type | Collected | Linked to user | Tracking | Purpose |
|---|---|---|---|---|
| Name (first name shown in family sharing) | Yes – only if family sharing is used | No | No | App functionality |
| Photos (pet photo on a public collar page; report photo for text recognition, not stored) | Yes | No | No | App functionality |
| Other user content (pet details on collar page, feeding events, finder messages) | Yes | No | No | App functionality |
| Phone number (finder's number in a message, owner's number on lost-pet page) | Yes | No | No | App functionality |
| Purchases (via Apple/RevenueCat) | Yes | No | No | App functionality |
| Health, location, contacts, identifiers, usage data, diagnostics | No | – | – | – |

Everything else (records, documents, reminders) stays on the device.

## App Store Connect – done via API (Nov 2026)

- Subscription group **PetTrack Premium** (id 22597028), localized en-US/es-ES/de-DE/fr-FR/nl-NL.
- `pettrack_premium_monthly` (6836920254) – 1 month, $4.99 · `pettrack_premium_yearly` (6836920268) – 1 year, $34.99.
- Prices set in all 175 territories (Apple equalized from the USA price), available in all territories incl. new ones.
- Introductory offer: 3-day free trial in every territory.
- Review screenshot (paywall) uploaded → both subscriptions are **Ready to Submit**.
- First subscriptions must be attached to the first app version in App Store Connect ("In-App Purchases and Subscriptions" section of the version page) when submitting for review.
- EAS credentials (distribution certificate + App Store provisioning profile) created and stored on Expo servers.

## TestFlight via GitHub Actions

`.github/workflows/testflight.yml` builds on a macOS runner and uploads with the App Store Connect API key.
Secrets: `EXPO_TOKEN`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`. Put `[testflight]` in a commit message for a full
build, `[testflight-upload]` to upload the latest finished EAS cloud build, or run it from the Actions tab.
