# The Hole Pro - Google Play launch checklist

Files: `TheHolePro.aab` (signed release bundle, in the folder above `hole-rush`) and the signing key in
`%LOCALAPPDATA%\Android\keys\` (**back up `release.keystore` and `release_credentials.txt` somewhere safe - losing them means you can never update the app**).

## 1. Play Console - create the app
1. Play Console > **Create app**: name **The Hole Pro**, language, **Game**, **Free**.
2. Accept the policies. Package name will be `com.gamics.theholepro` (taken from the uploaded bundle - it cannot be changed later).
3. Turn on **Play App Signing** when uploading (recommended). Upload `TheHolePro.aab` to **Testing > Internal testing** first.

## 2. In-app products (IDs must match exactly)
Monetize > Products > **In-app products** (create as *Managed products*, status Active):

| Product ID | Name | Price | Type |
|---|---|---|---|
| `remove_ads` | Remove Ads | $2.99 | one-time |
| `pass_premium` | Pro Pass - Premium | $4.99 | one-time |
| `starter` | Starter Pack | $1.99 | one-time |
| `coins_s` | 500 Coins | $0.99 | consumable (the game consumes it) |
| `coins_m` | 3,000 Coins | $4.99 | consumable |
| `coins_l` | 8,000 Coins | $9.99 | consumable |

Monetize > Products > **Subscriptions**: product ID **`vip`**, one base plan with ID **`monthly`** (auto-renewing, 1 month, $4.99), Active.
(The game calls `purchase_subscription("vip", "monthly")`; the ids are in `scripts/monetization.gd`.)
Prices shown in the game's shop are fixed text - keep the Play Console prices identical.

## 3. Test before release
- Setup > License testing: add your Gmail as a license tester.
- Install the app from the **Internal testing** link (purchases only work for builds installed from Play).
- Test: buy Remove Ads, a coin pack (coins arrive, can buy again), VIP, Pro Pass, Starter pack; reinstall and check purchases are restored.

## 4. AdMob
- Link the app in AdMob (Apps > The Hole Pro > App settings > link to Google Play) once published.
- **Privacy & messaging**: create the **GDPR** consent message (EEA/UK) and, if you want, US-states message. Without it the consent form shows "no forms configured".
- Payments: add payment details in AdMob.
- The release build uses your real ad units; debug builds use Google test ads. Never tap your own live ads.
- Optional: publish `app-ads.txt` on your developer website.

## 5. Store listing
- **Short description (max 80)**: `Swallow the whole city! Grow your hole, beat rivals, win the arena.`
- **Full description**:
  > Become THE HOLE PRO! Slide your hole around a busy city and swallow cars, trees, benches and even skyscrapers - the more you eat, the bigger you grow.
  >
  > - Fast 90-second rounds with combo chains, power-ups and gold bonuses
  > - Battle rival holes - eat them before they eat you
  > - Royale mode: the arena shrinks until one hole is left
  > - Unlock skins, level up, finish daily missions and climb the Pro Pass
  > - Beautiful low-poly cities: sunny day, golden hour, neon night and frost
  >
  > Free to play with optional ads and in-app purchases.
- **Graphics needed**: app icon 512x512 PNG, **feature graphic 1024x500**, at least 2 phone screenshots (landscape is fine; take them in-game).
- Category: Game > Action (or Casual). Tags: casual, arcade.

## 6. Policy forms
- **Privacy policy URL**: host `PRIVACY_POLICY.md` as a web page (GitHub Pages / Google Sites) and paste the link. Replace `[YOUR CONTACT EMAIL]` first.
- **Ads**: declare "Yes, the app contains ads".
- **Data safety**: collects *Device or other IDs* (advertising ID) and *App activity / diagnostics* via Google AdMob (shared, used for advertising/analytics); *Purchase history* handled by Google Play. No account, no location, no contacts. Data is encrypted in transit; users cannot request deletion in-app (no account data stored on servers).
- **Content rating**: IARC questionnaire - cartoon, no realistic violence, no gambling, no user-generated content, contains ads + in-app purchases.
- **Target audience**: choose **13+** (or 18+). Do **not** pick under-13 unless you add COPPA/Families compliance (kid-safe ad settings, no personalised ads).
- **App access**: all functionality available without login.

## 7. Release
- New personal developer accounts may need a **closed test with 12+ testers for 14 days** before production access - check the Dashboard "Test and release" tasks.
- Then promote to Production.

## What is NOT verified yet
Real billing and the consent form could not be tested here (they only work for builds installed from Google Play). Test them in Internal testing before going to production.
