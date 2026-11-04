#!/usr/bin/env bash
# Assemble everything the owner needs for Play Console and the website into
# releases/SafeScape-v<ver>-package/ and a zip next to it.
set -euo pipefail
cd "$(dirname "$0")/.."
# Version from pubspec.yaml, e.g. 1.2.0+3 -> 1.2.0-3
VER="$(grep -m1 '^version:' pubspec.yaml | awk '{print $2}' | tr '+' '-')"
NAME="${VER%-*}"
SRC="releases/v$VER"
OUT="releases/SafeScape-v$VER-package"
rm -rf "$OUT" "$OUT.zip"
mkdir -p "$OUT"/{1_upload_to_play_console,2_website_safescape.homilabs.org,3_store_listing/phone_screenshots,4_test_apk_for_phones}

cp "$SRC/safescape-$VER.aab" "$OUT/1_upload_to_play_console/"
python3 scripts/make_website.py > /dev/null
cp -r firebase/hosting/. "$OUT/2_website_safescape.homilabs.org/"
cp store-assets/icon-512.png store-assets/feature-graphic-1024x500.png "$OUT/3_store_listing/"
# Play allows 8 phone screenshots: the captioned set (make_captioned.py).
cp store-assets/captioned/*.jpg "$OUT/3_store_listing/phone_screenshots/"
cp docs/play-console-listing-kit.md "$OUT/3_store_listing/play-console-answers.md"
cp "$SRC/safescape-$VER.apk" "$OUT/4_test_apk_for_phones/"

# Copy-paste text for the store listing.
python3 - "$OUT/3_store_listing/store-listing-text.txt" "$NAME" <<'PY'
import re, sys
kit = open("docs/play-console-listing-kit.md").read()
short = re.search(r"## Short description \(80\)\n(.+?)\n", kit).group(1).strip()
full = re.search(r"## Full description \(≤4000\)\n(.+?)\n## Graphics", kit, re.S).group(1).strip()
name = sys.argv[2]
m = re.search(r"## Release notes — v" + re.escape(name) + r" \(versionCode \d+\)\n\n```\n(.+?)```", kit, re.S)
notes = m.group(1).strip() if m else re.search(r"## Release notes \(v1.0.0\)\n(.+?)\n", kit).group(1).strip()
assert len(notes) <= 500, len(notes)
assert len(short) <= 80 and len(full) <= 4000, (len(short), len(full))
open(sys.argv[1], "w").write(
    "APP NAME (30 max)\nSensory SafeScape\n\n"
    f"SHORT DESCRIPTION ({len(short)}/80)\n{short}\n\n"
    f"FULL DESCRIPTION ({len(full)}/4000)\n{full}\n\n"
    f"RELEASE NOTES / WHAT'S NEW (v{name}, {len(notes)}/500)\n{notes}\n\n"
    "WEBSITE\nhttps://safescape.homilabs.org\n\nEMAIL\nhomilabs.smc@gmail.com\n\n"
    "PRIVACY POLICY URL\nhttps://safescape.homilabs.org/privacy.html\n\n"
    "ACCOUNT DELETION URL\nhttps://safescape.homilabs.org/delete-account.html\n\n"
    "TERMS AND CONDITIONS URL\nhttps://safescape.homilabs.org/terms.html\n")
print(f"listing text: short {len(short)}/80, full {len(full)}/4000")
PY

cat > "$OUT/README.txt" <<'TXT'
SENSORY SAFESCAPE - RELEASE PACKAGE (version in the file names)
Package name: com.homilabs.safescape

1_upload_to_play_console/
   safescape-<version>.aab -> Play Console > Test and release > (Internal testing first) > Create release > Upload.
   Signed with the SafeScape upload key. Let Google manage the app signing key (Play App Signing).

2_website_safescape.homilabs.org/
   Upload everything in this folder (4 pages, style.css, icon.png, images/) to the root of https://safescape.homilabs.org so that these URLs work:
     https://safescape.homilabs.org/                    (index.html)
     https://safescape.homilabs.org/privacy.html
     https://safescape.homilabs.org/terms.html
     https://safescape.homilabs.org/delete-account.html
   The app itself links to privacy.html and terms.html on this domain, so publish the site before the app goes live.
   Plain static HTML: works on any web host (cPanel, Hostinger, Netlify, GitHub Pages, Firebase Hosting).
   The same pages are already live as a backup at https://safescape-homilabs.web.app/

3_store_listing/
   store-listing-text.txt   -> copy-paste name, short/full description, release notes, URLs
   play-console-answers.md  -> App content answers: Data safety, target audience, content rating, Families policy
   icon-512.png             -> App icon (512 x 512)
   feature-graphic-1024x500.png -> Feature graphic
   phone_screenshots/       -> 8 captioned phone screenshots (1080 x 1920, English + Urdu headline), upload in order 01..08

4_test_apk_for_phones/
   safescape-<version>.apk -> for installing directly on test phones (not for Play Console)

AFTER THE FIRST UPLOAD
   1. Play Console > Setup > App signing: copy the App signing key SHA-1 and SHA-256.
   2. Firebase console (project safescape-homilabs) > Project settings > Android app com.homilabs.safescape:
      add those fingerprints.
   3. Personal developer accounts: run a closed test with at least 12 testers for 14 days before production.

The upload keystore is NOT in this package (keep it private). It is in .secrets/ on homi-nas and in the
private Google Drive backup. Future updates must be signed with it (bump the version in pubspec.yaml).

Contact in all pages and the app: homilabs.smc@gmail.com
TXT

( cd releases && zip -qr "$(basename "$OUT").zip" "$(basename "$OUT")" )
echo "package: $OUT"
du -sh "$OUT" "$OUT.zip"
find "$OUT" -type f | sort | sed "s#$OUT/##"
