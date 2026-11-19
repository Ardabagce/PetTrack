# PetTrack — Pet Health Passport & Care Tracker (iOS)

Native SwiftUI app for the US & European markets. Languages: English, Spanish, German, French, Dutch.

## Features (v1)

| Area | Free | Premium |
|---|---|---|
| Pets | 1 | Unlimited |
| Today: meals/water check-off, upcoming, weight trend | ✓ | ✓ |
| Vaccines + booster notifications (7 days before & on the day) | ✓ | ✓ |
| Vet journal (manual), weight chart, expenses list | ✓ | ✓ |
| Feeding times | 3 | Unlimited |
| Custom reminders (meds, flea & tick, grooming…) | 3 open | Unlimited |
| Symptom photo diary (day-by-day photos, severity, compare) | 1 open case | Unlimited + PDF report |
| **Scan vet reports → visit record** (on-device OCR, 5 languages) | – | ✓ |
| **Shareable PDF health passport** | preview | ✓ |
| Food transition planner (7/10/14 days + daily notifications) | – | ✓ |
| Smart feeder sync | – | ✓ |
| Cost insights chart | – | ✓ |

Also: Siri / Shortcuts action “Log a feeding”, welcome tour, TipKit hints, “What's new” screen per release.

Subscriptions: `com.pettrack.premium.monthly` and `com.pettrack.premium.yearly`, both with a **3-day free trial** (introductory offer), in one subscription group. A local `Configuration/PetTrack.storekit` lets you test purchases in the simulator.

## Getting started (Mac)

```bash
brew install xcodegen
xcodegen generate
open PetTrack.xcodeproj
```

Requirements: Xcode 16+ (Xcode 26 enables the on-device Apple Intelligence report extraction), iOS 17+.
Set your team in `project.yml` (`DEVELOPMENT_TEAM`) and change the bundle ID if needed.

In Debug builds, Settings → Developer → “Simulate Premium” unlocks everything without a purchase.

## Architecture

- SwiftUI + SwiftData (CloudKit-compatible schema), Swift Charts, StoreKit 2, TipKit, VisionKit/Vision OCR, App Intents.
- `PetTrack/Models` – data model · `Services` – store, notifications, OCR parser, PDF, feeders
- `DesignSystem` – “Linen & Forest” palette, serif display type, floating tab bar
- `Features/*` – one folder per area
- Localization: `tools/translations.py` → `python3 tools/build_strings.py` generates `Localizable.xcstrings`.

## Before App Store submission

- App icon (1024×1024) in `Assets.xcassets/AppIcon`
- Host privacy policy & terms; update `AppLinks` in `PaywallView.swift`
- Create the subscription group + 2 products + 3-day free trial in App Store Connect
- Localized App Store screenshots & metadata (5 languages)

See `docs/` for the smart-feeder integration notes and the competitor analysis.
