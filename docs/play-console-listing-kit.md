# Play Console listing kit: Sensory SafeScape v1.0.0

Everything needed to fill in Play Console for the first upload. Upload file: `releases/v1.0.0-1/safescape-1.0.0-1.aab`.

## App details
| Field | Value |
|---|---|
| App name (30) | Sensory SafeScape |
| Package | com.homilabs.safescape |
| Default language | English (United States) – en-US |
| App or game | App |
| Free or paid | Free |
| Category | Education (alternative: Parenting) |
| Tags | Education, Parenting, Kids, Calm, Autism support |
| Email | homilabs.smc@gmail.com |
| Website | https://safescape.homilabs.org |
| Privacy policy | https://safescape.homilabs.org/privacy.html |
| Account deletion URL | https://safescape.homilabs.org/delete-account.html |
| Terms and conditions | https://safescape.homilabs.org/terms.html |

## Short description (80)
Calm sensory play and picture routines for autistic and sensitive children.

## Full description (≤4000)
Sensory SafeScape is a quiet, predictable place for autistic and sensory-sensitive children (ages 2–10) to calm down and get ready for what comes next.

CALMING CANVAS
Touch and drag anywhere to make soft, glowing waves that drift and fade. Use one finger, both hands or a whole palm. A slow breathing ring (4 seconds in, 6 seconds out) and Sammy the Turtle breathe along with your child.

MY VISUAL ROUTINES
Break big moments into small picture steps: going to the doctor, the dentist, a haircut, school, bath time, shopping and bedtime are ready to use. A First / Then strip shows what is happening now and what comes next. Each card can read itself aloud with a short, reassuring story ("The doctor listens to my heart. It might feel cold. That is okay."). Finishing a step brings a gentle chime and a small burst of stars.

SOOTHING SOUNDS
Warm hum, soft rain, ocean waves and a marimba lullaby. Every sound is filtered to remove sharp, high pitches, and can fade out slowly at bedtime.

WAIT TIMER
A soft disc slowly shrinks to show "a few more minutes", with a picture of what comes next. No numbers counting down, no alarm: just one low, gentle note at the end.

DESIGNED TO BE SENSORY-SAFE
• Dark, low-glare colours with soft pastels; no white screens, no flashing
• Low Motion mode, soft warm lighting and high-pitch filtering
• Large, easy buttons and one-tap mute on every screen
• No timers that buzz, no scores, no "wrong" answers

FOR PARENTS AND THERAPISTS
Behind a grown-up check you can adjust motion speed, particle density, colour warmth and sound filtering; build your own routines with your own photos; set up several children; and see the "Calm & Focus Horizon": calm minutes each day, favourite calming modes and routine steps completed. Export a one-page PDF summary to share with an occupational therapist.

PRIVATE BY DESIGN
No sign-up needed. No ads, no analytics, no tracking. Photos you add stay on your device. An optional private cloud backup keeps settings, routines and progress safe if you change phones, and you can switch it off or delete everything at any time.

Sensory SafeScape is an educational and calming tool. It is not a medical device and does not diagnose or treat any condition.

## Graphics
| Asset | File |
|---|---|
| App icon 512×512 | `store-assets/icon-512.png` |
| Feature graphic 1024×500 | `store-assets/feature-graphic-1024x500.png` |
| Phone screenshots (upload these) | `store-assets/screenshots-play/phone/` (10 × 800×1600, from a Samsung Galaxy A12 at font size ×1.3; status bar blanked, padded to Play's 2:1 limit) |
| Raw captures | `store-assets/screenshots/phone/` (720×1600; regenerate the Play set with `python3 scripts/make_store_assets.py`) |
| Tablet screenshots | Optional; not captured. Only needed to be featured on tablets. `scripts/take_screenshots.sh` accepts a `wm size` for a tablet-sized capture. |

## App content (Policy) answers
| Section | Answer |
|---|---|
| Privacy policy | https://safescape.homilabs.org/privacy.html |
| App access | **All functionality is available without special access.** No login is required; the grown-ups area uses a simple multiplication question (shown on screen). |
| Ads | No, the app does not contain ads |
| Content rating (IARC) | Category: Reference, News, or Educational. No violence, sexuality, language, controlled substances, gambling, user interaction/communication, sharing of location, or purchases. Expected: Everyone / PEGI 3 |
| Target audience | Ages 5 and under, 6–8, 9–12 **and** 18+ (parents/therapists). Because children are included, the Families Policy applies. |
| Appeals to children | Yes |
| News app | No |
| COVID-19 app | No |
| Data safety | See below |
| Government app | No |
| Financial features | None |
| Health | Not a health app (select "My app does not have any health features" if asked; it's an educational calming tool, not medical). |
| Account deletion | In-app (Grown-ups area → Backup & account → Delete account and all cloud data) and web URL above |

### Data safety form
- **Does your app collect or share any of the required user data types?** Yes (collects; does not share).
- **Is all data encrypted in transit?** Yes.
- **Do you provide a way for users to request deletion?** Yes (in-app and web).
- **Data collected** (all: *Collected, not shared, processed ephemerally: No, required: No (user can turn cloud backup off)*, purpose: *App functionality*; *Account management* where noted):
  - Personal info → **Name** (child's nickname, optional) – App functionality.
  - Personal info → **Email address** (only if a parent links an email) – Account management.
  - Personal info → **User IDs** (random Firebase ID) – App functionality, Account management.
  - App activity → **App interactions** (time in each calming activity, routine steps completed) – App functionality.
  - App activity → **Other user-generated content** (routine titles and stories) – App functionality.
- **Not collected**: location, contacts, photos/videos (photos stay on the device), audio, messages, health, financial, device IDs, advertising ID, crash logs, diagnostics.

## Families Policy checklist
- No ads SDKs, no analytics, no Crashlytics; `AD_ID` permission removed in the manifest.
- Only permission: `INTERNET` (for the optional cloud backup). No camera/storage permission: photos use the system photo picker / camera intent.
- Parent gate before settings, account, external links and sharing.
- Email/password sign-in is optional and only offered to the parent, behind the gate.
- Android device backup excluded for child data (`data_extraction_rules.xml`); the app's own backup is opt-out.

## Release notes (v1.0.0)
First release: Calming Canvas with breathing guide, eight ready-made visual routines with First/Then and spoken stories, Soothing Sounds with high-pitch filtering, Wait Timer, and a grown-ups area with sensory settings, routine builder, progress and PDF export.

## Testing track reminder
Personal developer accounts created after Nov 2023 must run a **closed test with at least 12 testers for 14 days** before applying for production. Upload the AAB to **Internal testing** first to get Google's pre-launch report on real devices.

## After the first upload
1. Play Console → Setup → App signing: copy the **App signing key SHA-1 and SHA-256**.
2. Firebase console → Project settings → Android app `com.homilabs.safescape` → add both fingerprints (and the upload key's, below).
3. Google Cloud console → APIs & Services → Credentials → the Android API key: restrict to package `com.homilabs.safescape` + those SHA-1s.

Upload key (for reference): SHA-1 `FA:1B:C8:2D:40:22:16:C8:53:9F:9E:C2:10:FC:19:79:89:95:21:53`, SHA-256 `66:AD:F5:4F:1B:21:14:96:71:BF:90:D0:D0:A9:5B:74:08:43:5A:19:FE:C4:4F:E3:00:84:F2:A1:EC:B7:EA:D3`.
