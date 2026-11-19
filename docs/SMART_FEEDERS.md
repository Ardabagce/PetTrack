# Smart feeder & fountain integrations

**Status (Nov 2026):** PETLIBRO, Sure Petcare (SureFeed / Felaqua) and PetSafe do **not** offer an official public developer API.
Community projects (e.g. `surepy`, PETLIBRO Home Assistant integration) use reverse-engineered, undocumented endpoints
and the user's account password. Shipping that in a paid App Store app is risky (breaks without notice, ToS, password handling).

## What v1 ships
1. `SmartFeederProvider` protocol + `FeederSyncService` (dedupes by `externalID`, imports into `FeedingLog` with source `.device`).
2. A **Demo feeder** so users and App Review can see the flow.
3. **Siri / Shortcuts action “Log a feeding”**: any device that can trigger a Shortcut or Home automation can log events today.
4. Vendor cards marked “Coming soon”.

## Plan
1. Contact business development at PETLIBRO, Sure Petcare (Antelliq/MSD), PetSafe, Petkit for partner API access (OAuth preferred).
2. Implement one provider per partner behind the same protocol; tokens in Keychain, never passwords.
3. Optional backend (webhooks) for real-time events instead of polling on app open.
