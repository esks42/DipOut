# DipOut — App Store Submission Reference

## App Store Listing Copy

### Description (4,000 char max — paste as-is)
```
DipOut scans your restaurant receipt and catches a sneaky trick: tip suggestions calculated on the post-tax total, so you're quietly tipping on the tax itself.

HOW IT WORKS
Point your camera at any receipt. DipOut reads the subtotal, tax, and printed tip suggestions, then checks whether the restaurant ran those percentages against the pre-tax subtotal or the inflated post-tax total. If they tipped on tax, it flags it, recalculates a fair tip on the subtotal, and splits the bill evenly between however many people you choose.

FEATURES
• Instant OCR receipt scanning using Apple Vision — no upload, no account
• Detects post-tax tip inflation across all common tip percentages (18%, 20%, 22%, 25%)
• Recalculates the correct tip amount on the pre-tax subtotal
• Even bill splitting with exact-cent reconciliation so shares always sum correctly
• Tip history saved on-device so you can look back at past meals
• Pro unlock: unlimited scanning, one-time purchase, no subscription

PRIVACY
Everything runs on your device. Receipt images are processed by Apple's Vision framework and immediately discarded — never uploaded. No analytics. No trackers. No account required.
```

### Promotional Text (170 char max — editable anytime without re-review)
```
Stop tipping on tax. Scan any receipt, instantly check if the suggested tip is inflated, recalculate the fair amount on the subtotal, and split the bill.
```

### Keywords (100 char max, comma-separated, no spaces after commas)
```
tip,calculator,receipt,bill,split,tax,gratuity,scanner,dinner,restaurant,fair,share,checkbill
```
(93 characters — fits)

### Support URL
```
https://esks42.github.io/DipOut/support.html
```
Replace with your actual GitHub Pages URL after publishing.

### Privacy Policy URL
```
https://esks42.github.io/DipOut/
```
Replace with your actual GitHub Pages URL after publishing.

### Category
- **Primary:** Finance
- **Secondary:** Utilities (optional)

### Age Rating
Answer **None / No** to every question in the questionnaire → result: **4+**

---

## IAP Details

| Field | Value |
|---|---|
| Type | Non-Consumable |
| Reference Name | DipOut Pro Lifetime |
| Product ID | `com.esks42.dipout.premium.lifetime` |
| Price Tier | $2.99 USD |
| Display Name (EN US) | DipOut Pro |
| Description (EN US) | Unlimited receipt scanning, forever. |

---

## Step-by-Step Portal Checklist

### PHASE 1 — Apple Developer Portal
**URL:** https://developer.apple.com/account/resources/identifiers/list

- [ ] **1.1** Identifiers → **+** → App IDs → App → Continue
- [ ] **1.2** Description: `DipOut`
- [ ] **1.3** Bundle ID: **Explicit** → `com.esks42.dipoutapp`
- [ ] **1.4** Capabilities: leave defaults (In-App Purchase is on by default) → **Register**

---

### PHASE 2 — App Store Connect: Create App Record
**URL:** https://appstoreconnect.apple.com/apps

- [ ] **2.1** Apps → **+** → New App
- [ ] **2.2** Platform: **iOS**
- [ ] **2.3** Name: `DipOut` (Note: App Store names must be globally unique. If "DipOut" is taken, register it as "DipOut - Stop Tipping on Tax" or "DipOut - Tip Calculator", keeping the bundle display name on-device as "DipOut")
- [ ] **2.4** Primary language: **English (U.S.)**
- [ ] **2.5** Bundle ID: select **com.esks42.dipoutapp** (appears after step 1.4)
- [ ] **2.6** SKU: `dipout002`
- [ ] **2.7** User Access: **Full Access** → Create

---

### PHASE 3 — GitHub Pages (unblocks Privacy Policy + Support URLs)
- [ ] **3.1** Create a **public** GitHub repo named **DipOut** (case-sensitive to match the URLs below)
- [ ] **3.2** Push `index.html` and `support.html` from this folder to `main` branch
- [ ] **3.3** Repo → Settings → Pages → Source: **Deploy from branch** → `main` / `/ (root)` → Save
- [ ] **3.4** Wait ~1 min; verify `https://esks42.github.io/DipOut/` loads
- [ ] **3.5** Copy both URLs — you'll need them in Phases 6 and 7

---

### PHASE 4 — App Information (General)
**App Store Connect → your app → General → App Information**

- [ ] **4.1** Primary Category → **Finance**
- [ ] **4.2** Secondary Category → **Utilities** (optional) → **Save**
- [ ] **4.3** **Content Rights** → Scroll down to Content Rights section → click **Edit** (or Set Up) → Select **"No, this app does not contain, show, or access third-party content"** (since the app is a custom tool with no third-party copyrighted material) → **Save**

---

### PHASE 4.5 — Pricing and Availability
**App Store Connect → your app → General → Pricing and Availability**

- [ ] **4.5a** **Price Schedule** → Click **Add Pricing** (or select the price tier dropdown) → select **Free** (or `$0.00` USD) since the app is free to download with IAP → **Save**
- [ ] **4.5b** **App Availability** → Click **Set Up Availability** → select **"All countries or regions"** (or select specific ones) → **Done / Save**

---

### PHASE 5 — In-App Purchase
**App Store Connect → your app → Monetization → In-App Purchases → +**

- [ ] **5.1** Type: **Non-Consumable** → Create
- [ ] **5.2** Reference Name: `DipOut Pro Lifetime`
- [ ] **5.3** Product ID: `com.esks42.dipout.premium.lifetime`
- [ ] **5.4** Availability: all territories (default)
- [ ] **5.5** Price Schedule: **$2.99 USD** tier
- [ ] **5.6** App Store Localization → **+** → English (U.S.)
  - Display Name: `DipOut Pro`
  - Description: `Unlimited receipt scanning, forever.`
- [ ] **5.7** Review Information → Screenshot: upload one paywall screenshot (run app in simulator, navigate to paywall, ⌘S to save, upload here)
- [ ] **5.8** **Save** → status shows "Ready to Submit"
- [ ] **5.9** **Generate Promo Codes** (Optional) → App Store Connect → Services → Promo Codes (or inside your In-App Purchase detail page, click **Promo Codes**) to generate up to 100 free redemption codes for reviewers, friends, or family.


---

### PHASE 6 — Version Page (1.0) — Screenshots & Metadata
**App Store Connect → your app → iOS App → 1.0 Prepare for Submission**

Screenshots:
- [ ] **6.1** Run simulator and capture screenshots:
  - **[MANDATORY]** Run on **iPhone 16/17 Pro Max** simulator (produces **1320×2868** screenshots for the **6.9" Display** slot).
  - **[OPTIONAL]** All other sizes (6.7", 6.5", 6.3", 6.1", 5.5", 4.7") will automatically inherit and scale down from the **6.9"** screenshots by default. You do not need to upload them unless you want pixel-perfect custom designs for those sizes.
  - **[IPAD - IF SUPPORTED]** If your app supports iPad, run on **iPad Pro 13-inch (M4)** simulator (produces **2064×2752** screenshots for the **13" Display** slot). All other iPad sizes will inherit from this slot. (If you only want to support iPhone, you can disable iPad in Xcode target settings).
- [ ] **6.2** Capture 3–5 screens for the 6.9" size: Scan screen, Review screen, Results/verdict, Paywall.
  - Simulator: Device → Screenshot (⌘S) saves to Desktop.
- [ ] **6.3** Drag screenshots into the **6.9" Display** (and **13" Display** if supporting iPad) slots in App Store Connect. (Double-check that other slots like 6.5", 6.3", 5.5", 4.7" are set to "Use 6.9\" Display" or "Use 6.5\" Display" by default).

Metadata:
- [ ] **6.4** Description → paste from the copy block above
- [ ] **6.5** Promotional Text → `Stop tipping on tax. Scan any receipt, instantly check if the suggested tip is inflated, recalculate the fair amount on the subtotal, and split the bill.`
- [ ] **6.6** Keywords → paste from the copy block above
- [ ] **6.7** Support URL → paste your GitHub Pages support.html URL (`https://esks42.github.io/DipOut/support.html`)
- [ ] **6.8** Marketing URL → **Leave blank** (or paste `https://esks42.github.io/DipOut/` — it is optional)
- [ ] **6.8b** Copyright → Enter in format: `Year Owner` (e.g., `2026 esks42` or `2026 sk`)
- [ ] **6.8c** Routing App Coverage File → **Leave blank / do not upload anything** (this is only for navigation/maps apps providing routing directions)

App Review Information:
- [ ] **6.8d** **Sign-In Information** → **Uncheck "Sign-in required"** (⚠️ critical: DipOut runs fully locally and has no account/login system. If left checked, Apple will ask for credentials and reject the app).
- [ ] **6.8e** **Contact Information** → Fill in your First/Last name, Phone number, and Email.
- [ ] **6.8f** **Notes** → Paste this note for the Apple reviewer to help them test the In-App Purchase:
  ```
  The app runs entirely on-device and does not require a user account or sign-in. To test the In-App Purchase ("DipOut Pro Lifetime"), please use the App Store Sandbox environment. No real money or login credentials are required.
  ```

In-App Purchase attachment (⚠️ critical — prevents rejection):
- [ ] **6.9** Scroll to **In-App Purchases** section on version page → **+** → select `DipOut Pro Lifetime`
  This bundles the IAP with the binary so reviewers can test the purchase flow.

---

### PHASE 7 — App Privacy
**App Store Connect → your app → App Store → TRUST & SAFETY → App Privacy**

- [ ] **7.1** Privacy Policy → Click **Edit** next to Privacy Policy → paste your GitHub Pages index URL (`https://esks42.github.io/DipOut/`) → **Save** (as seen in your screenshot, this is done!)
- [ ] **7.2** Data Collection → Click **Get Started** → select **"No, we do not collect data from this app"** → **Save**
- [ ] **7.3** Click **Publish** in the top right → status: Published

---

### PHASE 8 — Age Rating
**App Store Connect → your app → General → App Information**

- [ ] **8.1** Scroll down to the **Age Rating** section and click **Edit** (or **Set Up Age Rating**)
- [ ] **8.2** Answer **None / No** to all questions in the questionnaire → **Done** (result: **4+**)

---

### PHASE 9 — Build Upload (Xcode)
- [ ] **9.1** Xcode: set target to **Any iOS Device (arm64)**
- [ ] **9.2** Product → **Archive** (takes a few minutes)
- [ ] **9.3** Organizer → your archive → **Distribute App** → **App Store Connect** → **Upload**
- [ ] **9.4** Wait 15–30 min for build to finish processing in App Store Connect

---

### PHASE 10 — Final Submission
**App Store Connect → your app → iOS App → 1.0 Prepare for Submission**

- [ ] **10.1** Build → **+** → select the uploaded build
- [ ] **10.2** Verify IAP is listed in the In-App Purchases section (from step 6.9)
- [ ] **10.3** Review any remaining yellow warnings in the sidebar
- [ ] **10.4** **Add for Review** → Submit to App Review (Note: Since `ITSAppUsesNonExemptEncryption` is configured as `NO` in target build settings, App Store Connect will automatically skip the export compliance popup question)

---

## Quick Reference: Copy-Paste Values

| Field | Value |
|---|---|
| Bundle ID | `com.esks42.dipoutapp` |
| SKU | `dipout002` |
| IAP Product ID | `com.esks42.dipout.premium.lifetime` |
| IAP Price | $2.99 (Non-Consumable) |
| Category | Finance / Utilities |
| Age Rating | 4+ |
| Contact Email | dipout.app@gmail.com |
