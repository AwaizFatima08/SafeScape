# Sensory SafeScape

Calm sensory play (Flow Canvas, Soothing Sounds, Breathing Buddy, Bubble Pop, Feelings Check-in), visual routines (step cards, First/Then, Wait Timer) and, from v1.2, Calm Skills lessons (Learn with Sammy) and Picture Stories for autistic and sensory-sensitive children aged 2–10, with a Parent & Therapist dashboard. Free, no ads, no tracking. Separate from EchoSteps and Sound Painter; don't carry their decisions over unless §0 of the design review says so.

## Source of truth
- `docs/product-design-document-v1.md`: the owner's PDD (the starting point).
- `docs/design-review-v1.md`: tool-set critique, improvements and **locked decisions (§0)**. §0 wins wherever the two conflict.
- `docs/v1.2-scope.md`: v1.2 decisions V1–V10 (lessons, Picture Stories). Child-facing wording lives in `assets/content/lessons.json` and `stories.json`; `python3 scripts/content_review.py` renders it to `docs/v1.2-content-review.md` for the owner's review. Never write "Social Stories" (trademark).

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
- GitHub (**public**): `git@github.com:AwaizFatima08/SafeScape.git`
- Backup: `bash scripts/backup.sh`. Commit first; the GitHub layer refuses to push with untracked or uncommitted files. `.secrets/` (upload keystore + passwords) only goes to the local and Drive layers.

## Code map
- `lib/models/models.dart`: ChildProfile (incl. `lessonsDone`), SensoryProfile, Routine/RoutineStep, PictureStory/StoryPage (parent-written), SensorySession (modes incl. `lesson`, `story`), GlobalSettings, AppData (JSON, tolerant of bad input).
- `lib/core/learning.dart`: loads chapters and built-in stories from `assets/content/*.json` (`learningProvider`).
- `lib/services/`: `store.dart` (local-first store, serial atomic writes, merge), `cloud_sync.dart` (Firestore mirror + auth), `audio.dart` (just_audio loops/SFX with fades), `speech.dart` (slow TTS), `stats.dart` (Calm & Focus Horizon), `report.dart` (OT PDF).
- `lib/views/`: onboarding, hub, `flow_sim.dart` + `flow_canvas_screen.dart`, `breathing_screen.dart` (patterns in `core/content.dart`), `bubbles_screen.dart` (`BubbleSim` + painter), `feelings_screen.dart`, `lessons_screen.dart` (chapter list + player) and `practice.dart` (choose / breathe / squeeze / count), `stories_screen.dart` (library + reader), routines + routine player, sounds, wait timer, `parent/` (dashboard tabs incl. `stories_tab.dart` with the story editor, routine editor).
- `lib/widgets/`: `sammy.dart` (CustomPainter turtle), `common.dart` (72 dp buttons, mute, parent gate, step pictures), `photos.dart` (`pickLocalPhoto`, device-only).
- `scripts/`: `make_audio.py` (all audio, verifies cutoffs; `make_audio.py new` renders only the v1.1 loops + pop so v1.0 files stay identical), `make_icon.py`, `fetch_icons.sh` (Noto emoji pictograms), `make_store_assets.py` (feature graphic, 2:1 Play screenshots), `make_captioned.py` (the 8 captioned Play screenshots), `make_website.py` (site + its images), `make_release_package.sh`, `emulator_run.sh` (device tests + screenshots on the emulator, via jobq), `content_review.py`, `backup.sh`.

## Commands
- Tests: `flutter test` (unit + widget, incl. Galaxy A12 340 dp ×1.3 and OPPO CPH2743 320 dp ×1.15 no-truncation checks). Device: `jobq run --name safescape-emulator -- bash scripts/emulator_run.sh` (app_flow, learning_flow, screenshots). Device tests write to the **live** Firebase project and delete their own anonymous account at the end — never wipe the project, real families use it.
- Release: `flutter build appbundle --release` (signs via `android/key.properties` → `.secrets/safescape-upload.keystore`).
- Builds need `JAVA_HOME=~/jdks/jdk-21.0.12.1+1`. Another session may stop the shared Gradle daemon mid-build ("stop command received"); just rerun.
- Emulator AVD `safescape_api35` (`ANDROID_AVD_HOME=/mnt/storage/projects/android-avd`), a dedicated AVD (EchoSteps has its own). Start with `-port 5570 -gpu swangle_indirect -cores 3 -memory 3072` when RAM allows: running it next to another session's emulator and Gradle daemon can exhaust the 15 GB.

## Status (2026-11-04)
v1.0.0 and v1.1.0 are live on Google Play. **v1.2.0 (versionCode 4) is in preparation**: Learn with Sammy (8 Calm Skills chapters with errorless practices), Picture Stories (12 built-in + parent-written with photos), a Learning section on Progress and in the OT PDF, 39 more Noto pictograms (100 total), and canvas-bar and grown-ups-gate fixes for 320 dp phones. Content and Urdu captions approved by the owner and the website deployed (2026-11-05); the signed package is `releases/SafeScape-v1.2.0-4-package.zip` (versionCode 3 was superseded by the gate fix). The owner's OPPO CPH2743 is a test phone now (Play data already erased with the owner's OK); device tests run on it over wireless adb.
