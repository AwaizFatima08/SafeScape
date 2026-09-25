# Sensory SafeScape

Calm sensory play (Flow Canvas, Soothing Sounds) and visual routines (step cards, First/Then, Wait Timer) for autistic and sensory-sensitive children aged 2–10, with a Parent & Therapist dashboard. Free, no ads, no tracking. Separate from EchoSteps and Sound Painter; don't carry their decisions over unless §0 of the design review says so.

## Source of truth
- `docs/product-design-document-v1.md`: the owner's PDD (the starting point).
- `docs/design-review-v1.md`: tool-set critique, improvements and **locked decisions (§0)**. §0 wins wherever the two conflict.

## Locked (summary; details in the design review)
- Flutter (SDK at `/mnt/storage/projects/flutter/bin`), **Android only**, English, portrait.
- Package `com.homilabs.safescape`: never change it after the first Play upload.
- Local-first JSON store on the device; Firestore (`users/{uid}/children/{id}/routines|sessions`) is an optional mirror. Anonymous auth, optional email linking. Photos never leave the device.
- No analytics, Crashlytics, ads or tracking. All audio synthesised and low-passed (≤6/4/2.5 kHz variants). Sammy the Turtle is drawn in code. No Gemini (credits exhausted).
- Errorless: no fail states, alarms or scores. Parent Zone behind a multiplication gate.

## Locations
- Website: `https://safescape.homilabs.org` (owner hosts it; pages in `firebase/hosting/`: index, privacy, terms, delete-account). Contact: `homilabs.smc@gmail.com`. The app links to `/privacy.html` and `/terms.html` there.
- Firebase project: `safescape-homilabs` (Firestore + Auth: anonymous, email/password; Hosting keeps a mirror of the pages).
- Local backup: `/mnt/storage/project_backups/safescape_backup/`
- Google Drive: folder `1MQLHEGvfUOIOxbr9LbQuoM7z3pviZEFW` (rclone remote `gdrive`)
- GitHub (**public**): `git@github.com:AwaizFatima08/safescape.git`
- Backup: `bash scripts/backup.sh`. Commit first; the GitHub layer refuses to push with untracked or uncommitted files. `.secrets/` (upload keystore + passwords) only goes to the local and Drive layers.

## Code map
- `lib/models/models.dart`: ChildProfile, SensoryProfile, Routine/RoutineStep, SensorySession, GlobalSettings, AppData (JSON, tolerant of bad input).
- `lib/services/`: `store.dart` (local-first store, serial atomic writes, merge), `cloud_sync.dart` (Firestore mirror + auth), `audio.dart` (just_audio loops/SFX with fades), `speech.dart` (slow TTS), `stats.dart` (Calm & Focus Horizon), `report.dart` (OT PDF).
- `lib/views/`: onboarding, hub, `flow_sim.dart` + `flow_canvas_screen.dart`, routines + routine player, sounds, wait timer, `parent/` (dashboard tabs, routine editor).
- `lib/widgets/`: `sammy.dart` (CustomPainter turtle), `common.dart` (72 dp buttons, mute, parent gate, step pictures).
- `scripts/`: `make_audio.py` (all audio, verifies cutoffs), `make_icon.py`, `fetch_icons.sh` (Noto emoji pictograms), `make_store_assets.py`, `backup.sh`.

## Commands
- Tests: `flutter test` (unit + widget) and `flutter test integration_test/app_flow_test.dart -d <device>`.
- Release: `flutter build appbundle --release` (signs via `android/key.properties` → `.secrets/safescape-upload.keystore`).
- Builds need `JAVA_HOME=~/jdks/jdk-21.0.12.1+1`. Another session may stop the shared Gradle daemon mid-build ("stop command received"); just rerun.
- Emulator AVD `safescape_api35` (`ANDROID_AVD_HOME=/mnt/storage/projects/android-avd`), a dedicated AVD (EchoSteps has its own). Start with `-port 5570 -gpu swangle_indirect -cores 3 -memory 3072` when RAM allows: running it next to another session's emulator and Gradle daemon can exhaust the 15 GB.
