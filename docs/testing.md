# Testing Sensory SafeScape

## Automated suites

| Suite | Command | What it proves |
|---|---|---|
| Unit + widget (47) | `flutter test` | Models tolerate corrupt/malformed data; the store saves atomically, never clashes under rapid saves, recovers from a corrupt file, caps history, merges cloud copies (newest wins, local photos kept) and wipes cleanly; the Firestore mirror writes under `users/{uid}`, never uploads photos, writes nothing when backup is off, and account deletion removes every document; breathing guide timing (4 s in / 6 s out, smooth); the canvas simulation stays inside its particle budget under 10-finger stress, never produces NaN/out-of-bounds particles, settles when untouched, resets gently; stats and the OT PDF; every pictogram and every sound variant is bundled. Widget flows: onboarding without typing, parent gate (wrong → new question), errorless routine with chime/celebration, global mute, filtered sound variants, multi-touch canvas, wait timer, routine builder, sensory settings, progress, several children. |
| End-to-end on device | `flutter test integration_test/app_flow_test.dart -d <device>` | Real plugins and the **real Firebase project**: onboarding → 12 s two-finger canvas play → full routine with celebration → 11 s of rain → parent gate → all dashboard tabs; then checks silent anonymous sign-in, that sessions reached Firestore, and that the security rules refuse another user's data. |
| Account lifecycle on device | `flutter test integration_test/account_flow_test.dart -d <device>` | Against real Firebase: link an email to the anonymous account → sign out (welcome page) → sign in on a "new device" and get the child and progress back → delete the account (welcome page; the account no longer exists). Uses a throwaway `safescape.e2e.*@example.com` address. |
| Offline first launch | `bash scripts/offline_check.sh <device>` | Turns Wi-Fi and mobile data off (restoring them afterwards), then onboards, completes a routine step, uses the canvas and a sound; the backup shows "Waiting for an internet connection". |
| Store screenshots | `bash scripts/take_screenshots.sh <device> store-assets/screenshots/phone` | Drives every main screen (wipes app data first). |
| Stress ("monkey") | `adb shell monkey -p com.homilabs.safescape --pct-syskeys 0 --throttle 100 -v 3000` | Thousands of random taps and swipes, like a child mashing the screen. |
| Audio safety | `python3 scripts/make_audio.py` | Fails if any file has energy above its cutoff (6 / 4 / 2.5 kHz; effects 4 kHz). Measured: ≤6e-8 of energy above cutoff. |

## Results for v1.0.0 (24–25 Sep 2026)
| Check | Android 15 emulator (Pixel 6) | Samsung Galaxy A12, Android 12, font ×1.3, 340 dp |
|---|---|---|
| `flutter analyze` | no issues | n/a |
| `flutter test` (47) | all pass | includes a test that reproduces this phone's size, text scale and system bars |
| End-to-end vs real Firebase | pass | pass (final code) |
| Monkey, 3,000 events, release build | no crash / ANR | no crash / ANR; app alive, ~179 MB PSS |
| Store screenshot run | pass | pass; used for the Play listing |
| Account lifecycle vs real Firebase | n/a | pass |
| Offline first launch | n/a | pass; same timings as online (the app never waits for the network) |
| Release cold start | n/a | 0.76 s (3.7 s on the very first launch after install) |

Found and fixed during device testing: a provider change during `dispose()` (crash when leaving the canvas), "Back to Hub" returning to the routine list, headers scrolling away on small phones, text truncated or overflowing at font ×1.3 on a 340 dp screen (routine title, hub cards, step cards, First/Then), canvas colour targets below 72 dp on narrow phones, particles piling up at the canvas edge, a blank screen after sign-out or account deletion, the delete confirmation silently cancelling when the email was not retyped, and the email dialog disposing its fields during its closing animation.

After testing, all test accounts and test data were removed from Firebase (0 accounts, 0 documents), so the project starts clean.

Release APK permissions: `INTERNET`, `ACCESS_NETWORK_STATE`, plus two added by Google Play services (`READ_GSERVICES`, a non-exported receiver permission). No `AD_ID`, microphone, camera, storage or location.

## Emulator notes (this NAS: 4 CPU cores, no GPU)
- Start with `-gpu swangle_indirect -memory 3072`; use `-cores 2` if you will build at the same time. Running Gradle or the host test suite alongside a 4-core emulator trips the emulator's hang watchdog ("QEMU2 main loop … No response") and it exits. That is an emulator limit, not an app fault.
- The on-screen keyboard shrinks the onboarding list on real devices, so device tests dismiss it before tapping further down.
- Never `pkill -f` with a pattern that also appears in your own command line.

## Manual check on a real phone or tablet (about 10 minutes)

| # | Do this | Expect |
|---|---|---|
| 1 | Fresh install, open | Dark launch screen with Sammy, never a white flash; welcome page says "No sign-up needed" |
| 2 | Enter without typing a name | Hub says "Hi, Friend!" |
| 3 | Calming Canvas: drag with one finger, then both hands / a flat palm | Soft glowing waves follow every finger; nothing flashes; ring breathes 4 s in, 6 s out |
| 4 | Toggle Low Motion (grown-ups → Sensory), reopen the canvas | Particles clearly slower, routine card stops pulsing |
| 5 | Soft Lighting on, move the warmth slider | A warm wash over every screen, stronger with warmth |
| 6 | Soothing Sounds: play each; switch the cut-off 6 → 4 → 2.5 kHz | Sounds start and stop with a fade; lower cut-off sounds more muffled; no clicks at the loop point |
| 7 | Tap the mute button on any screen | All sound and speech stop at once |
| 8 | A routine: tap a later card, then the glowing one | Later card only reads itself; glowing card finishes with a chime, stars and "Next: …" |
| 9 | Finish a routine | Sammy celebrates; "Back to Hub" goes home; "Start again" resets |
| 10 | Wait Timer 1 min | Disc shrinks; one low note and "Time for …" at the end |
| 11 | Grown-ups → Routines → New → add a step with a **photo** | Photo shows on the card; it stays after restarting the app |
| 12 | Grown-ups → Progress → Export PDF | Share sheet opens with a one-page PDF |
| 13 | Backup & account → Save progress with an email; install on a second device → Sign in | Children, routines and progress appear on the second device (photos don't, by design) |
| 14 | Delete account and all cloud data | App returns to the welcome page; data is gone from Firebase |
| 15 | Aeroplane mode from first launch | Everything works; backup shows "Waiting for an internet connection" |

Record the device, Android version and anything odd.

## Google Play pre-launch report
Upload the AAB to **Internal testing**; Google runs it on real devices and reports crashes, performance and accessibility issues.
