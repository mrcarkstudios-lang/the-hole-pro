# The Hole Pro - Monetization

## What is already built (works in debug builds with TEST ads / free test purchases)
| Feature | Where | Player-facing rule |
|---|---|---|
| Rewarded: **Revive** (Royale) | `main.gd` `_offer_revive` | Once per round, VIP gets it free |
| Rewarded: **x2 coins** after a round | result screen | Optional, not shown to VIP |
| Rewarded: **Free boost** (speed + magnet) | home screen | Optional; VIP gets it every round |
| **Interstitial** between rounds | `main.gd` `_with_interstitial` | Never during play, never in first 3 rounds, at most every 3 rounds and 90 s, off for VIP / Remove Ads |
| **Remove Ads** | shop | $2.99 one-time |
| **VIP membership** | shop | $4.99/month: no ads, 2x coins, free boost + revive |
| **Pro Pass** (20 tiers, free + premium lanes, exclusive "Pro Gold" skin) | pass panel | $4.99 premium lane; XP from rounds |
| **Starter pack** (48 h one-time offer) | popup after round 2 | $1.99 |
| **Coin packs** | shop | $0.99 / $4.99 / $9.99 |
| Daily reward, missions, skins, upgrades | existing | free retention |

No paid random loot boxes (on purpose: policy + fairness).

## Safety design
`scripts/monetization.gd`
- Debug build (`test_mode`): ads are a labelled "TEST AD" screen, purchases are free so flows can be tested.
- Release build with no SDK plugin (`real_sdk == false`): **fails closed** - no rewards, no free purchases.

## What is left to go live (needs your accounts)
1. **AdMob**: create the app in AdMob, copy the *App ID* and create 2 ad units (Rewarded, Interstitial). Put them in `monetization.gd` (`ADMOB_APP_ID`, `AD_REWARDED`, `AD_INTERSTITIAL`; they currently hold Google's public TEST ids).
2. **Godot plugins** (need Godot's Android *custom (gradle) build*): an AdMob plugin and the Google Play Billing plugin. Wire them into `_real_show_rewarded`, `_real_show_interstitial`, `_real_buy` and set `real_sdk = true`.
3. **Play Console products** (same ids as `PRODUCTS`): `remove_ads`, `pass_premium`, `starter`, `coins_s`, `coins_m`, `coins_l` (managed/in-app) and `vip` (subscription).
4. **Release signing key** + `.aab` export (the current APK is debug-signed).
5. **Store compliance**: privacy policy URL, Data safety form, content rating, ads declaration, consent (UMP) for EU/UK, target audience (do NOT target children without COPPA/Families compliance).
6. Server-side receipt check is recommended before treating purchases as final for a real launch.
