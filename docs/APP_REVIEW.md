# App Store review checklist

| Guideline | How PetTrack handles it |
|---|---|
| 1.4.1 Physical harm / medical | No diagnosis, treatment or first-aid procedures. Disclaimer accepted before first use, repeated on calculators, food list, travel, alerts. SOS only offers calls, maps search, emergency card and general “while you get help” notes. |
| 2.1 Completeness | Deploy `server/` before submission so family sharing, collar tags and scanning work for the reviewer. Provide review notes with a demo household invite code. |
| 2.3 Accurate metadata | Screenshots from the real app; no claims of veterinary accuracy. |
| 3.1.1 / 3.1.2 Subscriptions | StoreKit via RevenueCat; paywall shows price, period, trial, auto-renew terms, Apple ID billing text, Restore, Terms and Privacy links. |
| 4.0 Design | Testing tools (Simulate Premium, demo data, delete all) are hidden in release builds (`__DEV__`). |
| 5.1.1 Data collection & deletion | No accounts. “Delete my data on the server” removes everything the device created (`DELETE /api/devices/me`). Export available for free. |
| 5.1.2 Data use | No tracking, no third-party analytics/ads. Privacy manifest in `app.json` (`ios.privacyManifests`). |
| 1.2 User-generated content | Finder messages go only to the pet owner, are rate limited and can be removed with server-data deletion. |
| Permissions | Camera & photo library usage strings explain the purpose; notifications requested only when the user sets a reminder. |
