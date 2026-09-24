# Sensory SafeScape V1: design review, tool-set critique and locked decisions

Reviewed against `docs/product-design-document-v1.md` (the owner's PDD). Where the two disagree, **§0 below wins**.

## 0. Locked decisions

| # | Decision | Why |
|---|---|---|
| L1 | Package `com.homilabs.safescape`, app name **Sensory SafeScape** (launcher label "SafeScape"). Never change the package after the first Play upload. | Matches the owner's other apps (`com.homilabs.*`). |
| L2 | Flutter, **Android only**, English, portrait (`sensorPortrait`), phones and tablets. | A fixed layout is predictable for autistic children and halves layout testing. |
| L3 | **Local-first data.** A JSON file on the device is the source of truth; Firestore is a mirror. The app never waits on the network. | Anonymous sign-in fails offline on first launch; the PDD's Firestore-only model would have nowhere to write. |
| L4 | Firestore tree is `users/{uid}` → `children/{childId}` → `routines/{id}` and `sessions/{id}`. No `parent_email` field. | Owner-only rules become one line; the email already lives in Firebase Auth (data minimisation). |
| L5 | Account upgrade uses **email + password linking** (the anonymous UID is kept). Signing in on a new device merges the cloud copy into the device. Google sign-in deferred to V1.1. | Google sign-in needs the Play app-signing SHA-1, which only exists after the first upload. |
| L6 | **Cloud backup can be switched off** by the parent; onboarding says plainly what is stored. Custom step **photos never leave the device**. | Families Policy / COPPA: disclose and minimise children's data; photos may show the child or home. |
| L7 | In-app **"Delete account and all cloud data"**, plus a public deletion page on Firebase Hosting. | Play's account-deletion policy applies once accounts can be created. |
| L8 | No Firebase Analytics, Crashlytics, ads or tracking SDKs. | Families Policy; the app needs none of them. |
| L9 | **Sammy the Turtle is drawn in code** (`CustomPainter`), not Lottie. The Flow Canvas uses `CustomPainter` + a ticker, not Flame. | No art pipeline (Gemini exhausted); Lottie needs After Effects JSON that doesn't exist. Code-drawn Sammy can breathe with the breathing ring. Flame adds a game loop and 2 MB for what one painter does. |
| L10 | Routine pictograms are bundled **Noto Color Emoji** PNGs (Apache 2.0), plus optional parent photos. | Consistent, clear, openly licensed pictures with no generative art; real photos of the actual dentist or school help most. |
| L11 | All audio is **synthesised in code** (`scripts/make_audio.py`), low-pass filtered and rendered at three cutoffs (**6 kHz / 4 kHz / 2.5 kHz**). The "Mute high pitch" toggle and the parent pitch slider pick the variant. | Guarantees the PDD's >6 kHz rule by construction; no stock-audio licences. Just_audio has no low-pass filter on Android, so the filtering happens at build time. |
| L12 | Step titles and micro-stories are read by the device's **text-to-speech**, slowed (rate ~0.42), and can be switched off. | Pre-readers need to hear the step; no voice-generation service is available. |
| L13 | **Errorless**: no buzzers, crosses, scores or countdown alarms. An unfinished routine simply waits. | PDD §3, kept. |
| L14 | Parent Zone is behind a **multiplication gate** (not the 3-second hold). | Children hold buttons for 3 s easily; Play's Families Policy expects a real adult check. |
| L15 | Positioned as **calming play and visual routines**, not a medical device or therapy. The OT report says "usage summary", not "assessment". | Play health-app policy; avoids medical-claim review. |
| L16 | Motion defaults are calm: **Low Motion on by default for ages 2–4**, no screen-wide flashes, star bursts are small and slow (≥600 ms). | PDD's forbidden-visuals list; photosensitivity. |

## 1. What the PDD gets right

- Guest mode first with no forced account removes the biggest drop-off for a stressed parent.
- Combining self-regulation (Flow Canvas, sounds) with transition support (routines) matches how meltdowns actually happen: most start at a transition.
- Dark, low-glare canvas, pastel accents, 72 dp targets and zero negative reinforcement.
- Multi-child profiles and an OT export make the app useful to therapists, not just families.

## 2. Improvements made

1. **First / Then strip** at the top of every routine ("First: brush teeth → Then: story time"). First/Then boards are the most widely used visual support for transitions and cost nothing to add.
2. **Micro-stories per step.** Each step can carry one or two short sentences ("The dentist counts my teeth. It might tickle.") read aloud on tap. This is the "social micro-story" the PDD's summary promises but its screens don't show.
3. **Gentle "wait" timer** (visual only): a slowly shrinking pastel disc for "5 more minutes" before a transition, ending with a single soft marimba note. No numbers counting down, no alarm.
4. **Sammy breathes with the child.** The breathing ring (4 s in / 6 s out) is mirrored by Sammy's shell rising and falling; the ring can be hidden.
5. **Soothing Sounds sleep fade.** Sounds can fade out over 10/20/30 minutes for bedtime instead of stopping abruptly.
6. **Palette choice on the canvas** (Lavender, Mint, Sand, Powder Blue) feeds the PDD's "Sensory Preference Matrix": the dashboard shows which palette and sound give the longest calm sessions.
7. **Eight ready-made routines** (Morning, Bedtime, School, Doctor, Dentist, Haircut, Bath, Shopping) so the app is useful in the first minute; parents can edit or copy them.
8. **Touch-rhythm label** for sessions (slow & rhythmic / steady / busy) computed on the device from touch rate, as the PDD's `avg_touch_frequency` suggests. Raw touches are never stored.

## 3. Tool-set critique

| PDD choice | Verdict | Used instead / why |
|---|---|---|
| Flutter (Dart) | ✅ Keep | Proven on the owner's machine (Sound Painter, EchoSteps). |
| CustomPainter / Flame | ✅ CustomPainter only | See L9. |
| Firebase Firestore + anonymous Auth | ✅ Keep, with L3–L7 | Firestore's offline cache alone can't cover a first launch with no network. |
| Lottie | ❌ Replace | No authored JSON exists; code-drawn Sammy (L9). |
| fl_chart | ✅ Keep | Weekly calm-minutes bars in the dashboard. |
| flutter_riverpod | ✅ Keep | App state (profile, settings, store) as providers. |
| (missing) PDF export | ➕ Add | `pdf` builds the OT summary; `share_plus` hands it to email/WhatsApp/Drive. |
| (missing) Audio playback | ➕ Add | `just_audio` for loops and chimes (L11). |
| (missing) TTS | ➕ Add | `flutter_tts` (L12). |
| (missing) Photos for steps | ➕ Add | `image_picker` (Android photo picker: no storage permission needed). |

## 4. Risks and open items

- **Real children.** Everything is tested on an emulator and by automated tests; a supervised real-device pass (see `docs/testing.md`) is the most valuable next input.
- **Play developer account type:** personal accounts created after Nov 2023 need a 14-day closed test with 12 testers before production.
- **Firebase API key restriction** (to the Android package and signing SHA-1s) should be applied in Google Cloud Console once the Play app-signing key exists.
- **Contact email** in the privacy policy is `info@homilabs.org`; change it in `firebase/hosting/` if another address is preferred.
