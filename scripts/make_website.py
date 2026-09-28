#!/usr/bin/env python3
"""Build the static website for https://safescape.homilabs.org into
firebase/hosting/: index (landing), privacy, terms and delete-account pages
with one shared header and footer. Plain HTML + CSS, relative .html links, so
it works on any static host.

    python3 scripts/make_website.py
"""
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "firebase/hosting"
SITE = "https://safescape.homilabs.org"
EMAIL = "homilabs.smc@gmail.com"
PLAY = "https://play.google.com/store/apps/details?id=com.homilabs.safescape"
UPDATED = "28 September 2026"

CSS = """:root {
  --bg: #12131C; --card: #1B1D2A; --raise: #262939; --text: #E8E6F0; --dim: #A9A7BA;
  --lav: #9D8DF1; --mint: #90DBB7; --sand: #F4E4BA; --blue: #89CFF0;
}
* { box-sizing: border-box; }
html { scroll-behavior: smooth; }
body { margin: 0; background: var(--bg); color: var(--text);
  font: 17px/1.65 system-ui, -apple-system, "Segoe UI", Roboto, "Noto Sans", sans-serif; }
a { color: var(--mint); }
a:hover { color: var(--sand); }
img { max-width: 100%; display: block; }
.wrap { max-width: 1040px; margin: 0 auto; padding: 0 20px; }
.narrow { max-width: 760px; }
header.site { border-bottom: 1px solid var(--raise); }
header.site .wrap { display: flex; align-items: center; gap: 12px; min-height: 64px; flex-wrap: wrap; }
.brand { display: flex; align-items: center; gap: 10px; color: var(--text); text-decoration: none; font-weight: 700; font-size: 18px; }
.brand img { width: 36px; height: 36px; border-radius: 10px; }
nav.top { margin-left: auto; display: flex; gap: 18px; flex-wrap: wrap; font-size: 15px; }
nav.top a { color: var(--dim); text-decoration: none; }
nav.top a:hover, nav.top a[aria-current] { color: var(--text); }
.hero { display: grid; grid-template-columns: 1.1fr .9fr; gap: 40px; align-items: center; padding: 56px 0 40px; }
.hero h1 { font-size: clamp(34px, 5vw, 50px); line-height: 1.1; margin: 0 0 14px; }
.hero h1 span { color: var(--lav); }
.lead { font-size: 19px; color: var(--dim); margin: 0 0 24px; }
.badges { display: flex; flex-wrap: wrap; gap: 8px; margin: 0 0 26px; padding: 0; list-style: none; }
.badges li { background: var(--card); border: 1px solid var(--raise); border-radius: 999px; padding: 4px 12px; font-size: 14px; color: var(--dim); }
.cta { display: inline-flex; align-items: center; gap: 10px; background: var(--lav); color: var(--bg); font-weight: 700;
  text-decoration: none; padding: 14px 22px; border-radius: 16px; }
.cta:hover { color: var(--bg); background: #b1a4f5; }
.cta svg { width: 22px; height: 22px; }
.note { font-size: 14px; color: var(--dim); margin-top: 10px; }
.phones { display: flex; justify-content: center; gap: 14px; }
.phone { border-radius: 26px; overflow: hidden; border: 6px solid #2b2e40; box-shadow: 0 20px 60px rgba(157,141,241,.18); background: var(--bg); }
.phone.small { width: 44%; margin-top: 40px; } .phone.big { width: 50%; }
section { padding: 40px 0; }
section h2 { font-size: 28px; margin: 0 0 8px; }
.sub { color: var(--dim); margin: 0 0 28px; }
.grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 18px; }
@media (max-width: 960px) { .grid { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 540px) { .grid { grid-template-columns: 1fr; } }
.card { background: var(--card); border: 1px solid var(--raise); border-radius: 22px; padding: 20px 22px; }
.card h3 { margin: 6px 0 6px; font-size: 19px; }
.card p { margin: 0; color: var(--dim); }
.card .shot { border-radius: 14px; margin: -4px -6px 14px; border: 1px solid var(--raise); width: calc(100% + 12px);
  height: auto; aspect-ratio: 4 / 5; object-fit: cover; object-position: top; }
.dot { width: 12px; height: 12px; border-radius: 50%; display: inline-block; }
.two { display: grid; grid-template-columns: 1fr 1fr; gap: 18px; }
ul.ticks { list-style: none; padding: 0; margin: 0; }
ul.ticks li { padding-left: 28px; position: relative; margin: 8px 0; }
ul.ticks li::before { content: "✓"; position: absolute; left: 0; color: var(--mint); font-weight: 700; }
.disclaimer { border-left: 4px solid var(--sand); background: var(--card); border-radius: 12px; padding: 14px 18px; color: var(--dim); }
footer.site { border-top: 1px solid var(--raise); margin-top: 40px; padding: 28px 0 40px; color: var(--dim); font-size: 15px; }
footer.site .wrap { display: flex; flex-wrap: wrap; gap: 10px 24px; align-items: center; }
footer.site nav { display: flex; flex-wrap: wrap; gap: 16px; margin-left: auto; }
/* Legal pages */
.doc h1 { font-size: 34px; margin: 36px 0 4px; }
.doc h2 { color: var(--lav); font-size: 21px; margin-top: 34px; }
.doc .meta { color: var(--dim); font-size: 15px; }
.doc table { border-collapse: collapse; width: 100%; font-size: 15px; }
.doc th, .doc td { text-align: left; padding: 9px 10px; border-bottom: 1px solid var(--raise); vertical-align: top; }
.doc th { color: var(--dim); font-weight: 600; }
.table-scroll { overflow-x: auto; }
.steps { counter-reset: s; list-style: none; padding: 0; }
.steps li { counter-increment: s; padding-left: 44px; position: relative; margin: 12px 0; }
.steps li::before { content: counter(s); position: absolute; left: 0; top: 0; width: 30px; height: 30px; border-radius: 50%;
  background: var(--lav); color: var(--bg); font-weight: 700; display: grid; place-items: center; }
code { background: var(--raise); padding: 1px 6px; border-radius: 6px; font-size: .92em; }
@media (max-width: 760px) {
  .hero { grid-template-columns: 1fr; padding-top: 32px; gap: 28px; }
  .two { grid-template-columns: 1fr; }
  nav.top { margin-left: 0; width: 100%; padding-bottom: 10px; }
  footer.site nav { margin-left: 0; }
}
"""

PLAY_ICON = ('<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M3.6 2.2 13.4 12l-9.8 9.8c-.4-.2-.6-.6-.6-1.1V3.3'
             'c0-.5.2-.9.6-1.1Zm10.9 10.9 2.5 2.5-11 6.3 8.5-8.8Zm3.9-3.9 2.9 1.7c.8.5.8 1.7 0 2.2l-2.9 1.7-2.8-2.8 2.8-2.8ZM6 1.8l11 6.3'
             '-2.5 2.5L6 1.8Z"/></svg>')


def page(name, title, description, body, current):
    links = [("index.html", "Home"), ("privacy.html", "Privacy"), ("terms.html", "Terms"), ("delete-account.html", "Delete my data")]
    cur = ' aria-current="page"'
    nav = "".join(f'<a href="{href}"{cur if href == current else ""}>{label}</a>' for href, label in links)
    canonical = SITE + ("/" if name == "index.html" else f"/{name}")
    html = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<meta name="description" content="{description}">
<link rel="canonical" href="{canonical}">
<meta property="og:title" content="{title}">
<meta property="og:description" content="{description}">
<meta property="og:image" content="{SITE}/images/social-card.jpg">
<meta property="og:url" content="{canonical}">
<meta name="theme-color" content="#12131C">
<link rel="icon" href="icon.png">
<link rel="stylesheet" href="style.css">
</head>
<body>
<header class="site"><div class="wrap">
  <a class="brand" href="index.html"><img src="icon.png" alt="">Sensory SafeScape</a>
  <nav class="top" aria-label="Site">{nav}</nav>
</div></header>
{body}
<footer class="site"><div class="wrap">
  <span>© 2026 HomiLabs · <a href="mailto:{EMAIL}">{EMAIL}</a></span>
  <nav aria-label="Legal"><a href="privacy.html">Privacy policy</a><a href="terms.html">Terms and conditions</a><a href="delete-account.html">Delete my account</a></nav>
</div></footer>
</body>
</html>
"""
    (OUT / name).write_text(html)


INDEX = f"""<main>
<div class="wrap">
  <section class="hero">
    <div>
      <h1>A calm place to play, breathe and get <span>ready for what's next.</span></h1>
      <p class="lead">Sensory SafeScape helps autistic and sensory-sensitive children (ages 2–10) calm down with gentle, touch-and-glow play,
        and get through the day's changes with simple picture routines.</p>
      <ul class="badges"><li>Free</li><li>No ads</li><li>No tracking</li><li>No sign-up</li><li>Works offline</li></ul>
      <a class="cta" href="{PLAY}">{PLAY_ICON} Get it on Google Play</a>
      <p class="note">For Android phones and tablets.</p>
    </div>
    <div class="phones">
      <div class="phone small"><img src="images/canvas.webp" alt="Calming Canvas with a breathing ring and Sammy the Turtle" width="360" height="749"></div>
      <div class="phone big"><img src="images/hub.webp" alt="The SafeScape home screen with four large cards" width="360" height="749"></div>
    </div>
  </section>

  <section id="features">
    <h2>Everything is gentle, predictable and in the child's control</h2>
    <p class="sub">Four simple spaces, big buttons, soft colours, and nothing that flashes, buzzes or says "wrong".</p>
    <div class="grid">
      <div class="card"><img class="shot" src="images/canvas.webp" alt="" loading="lazy" width="360" height="749">
        <h3>Calming Canvas</h3><p>Touch and drag with one finger, two hands or a whole palm to make soft, glowing waves. A slow breathing ring (4 s in, 6 s out) and Sammy the Turtle breathe along.</p></div>
      <div class="card"><img class="shot" src="images/routine.webp" alt="" loading="lazy" width="360" height="749">
        <h3>Visual Routines</h3><p>Picture steps for the doctor, dentist, haircut, school, bath and bedtime, with a First / Then strip and short stories read aloud. Make your own with your own photos.</p></div>
      <div class="card"><img class="shot" src="images/sounds.webp" alt="" loading="lazy" width="360" height="749">
        <h3>Soothing Sounds</h3><p>Warm hum, soft rain, ocean waves and a marimba lullaby, all filtered to remove sharp high pitches, with a slow fade-out for bedtime.</p></div>
      <div class="card"><img class="shot" src="images/wait.webp" alt="" loading="lazy" width="360" height="749">
        <h3>Wait Timer</h3><p>A soft disc slowly shrinks to show "a few more minutes", with a picture of what comes next. No numbers counting down and no alarm, just one low note.</p></div>
    </div>
  </section>

  <section>
    <div class="two">
      <div class="card">
        <h2>Designed to be sensory-safe</h2>
        <ul class="ticks">
          <li>Dark, low-glare screens with soft pastels; never a white flash</li>
          <li>Low Motion mode, warm Soft Lighting and adjustable particle density</li>
          <li>Every sound pre-filtered below 6, 4 or 2.5 kHz, your choice</li>
          <li>72 dp touch targets and one-tap mute on every screen</li>
          <li>Errorless: no scores, timers that buzz or "try again"</li>
        </ul>
      </div>
      <div class="card">
        <h2>For parents and therapists</h2>
        <ul class="ticks">
          <li>Settings behind a grown-up check children can't pass</li>
          <li>Build routines with your own photos and words</li>
          <li>Several children, each with their own settings</li>
          <li>Calm minutes, favourite calming modes and routine progress</li>
          <li>One-tap PDF summary to share with an occupational therapist</li>
        </ul>
      </div>
    </div>
  </section>

  <section id="privacy">
    <div class="two">
      <div>
        <h2>Private by design</h2>
        <p class="sub">SafeScape stores as little as possible and never sells or shares it.</p>
        <ul class="ticks">
          <li>No account needed: open the app and play</li>
          <li>No ads, analytics or tracking tools</li>
          <li>No microphone, location or contacts; photos you add never leave the phone</li>
          <li>Optional private cloud backup you can switch off or delete at any time</li>
        </ul>
        <p><a href="privacy.html">Read the privacy policy</a> · <a href="delete-account.html">How to delete your data</a></p>
      </div>
      <div class="phones"><div class="phone big"><img src="images/progress.webp" alt="Grown-ups area showing calm minutes per day" loading="lazy" width="360" height="749"></div></div>
    </div>
  </section>

  <section>
    <p class="disclaimer">Sensory SafeScape is an educational and calming tool. It is not a medical device and does not diagnose or treat any condition.
      It does not replace advice from a doctor or therapist.</p>
  </section>
</div>
</main>"""

PRIVACY = f"""<main class="wrap narrow doc">
<h1>Privacy Policy</h1>
<p class="meta">Sensory SafeScape (Android app <code>com.homilabs.safescape</code>) by HomiLabs · Last updated {UPDATED}</p>

<p>Sensory SafeScape is made for children, so we collect as little as possible and never sell or share it. There are no ads, no analytics and no tracking tools in the app.</p>

<h2>What the app stores</h2>
<div class="table-scroll"><table>
<tr><th>Data</th><th>Why</th><th>Where</th></tr>
<tr><td>Child's nickname (optional) and age group (2–4, 5–7 or 8–10)</td><td>To greet the child and suggest calm settings</td><td>Device; cloud backup if on</td></tr>
<tr><td>Sensory settings (motion, lighting, sound filtering, colours)</td><td>To keep the app comfortable for the child</td><td>Device; cloud backup if on</td></tr>
<tr><td>Routines (titles, pictures chosen from the app, short stories)</td><td>To show step-by-step routines</td><td>Device; cloud backup if on</td></tr>
<tr><td>Photos a grown-up adds to routine steps</td><td>To show real places and objects</td><td><b>Device only. Never uploaded.</b></td></tr>
<tr><td>Activity times (for example "Calming Canvas, 6 minutes, lavender colours"; routine steps completed)</td><td>For the grown-ups' progress view and the optional PDF summary</td><td>Device; cloud backup if on</td></tr>
<tr><td>A random account ID, and the parent's email only if a parent chooses to add one</td><td>To keep the backup private and restore it on a new device</td><td>Google Firebase</td></tr>
</table></div>
<p>The app does <b>not</b> use the microphone or location, does not read contacts, does not record audio or video, and does not collect the child's real name, a photo of the child (unless a grown-up chooses one for a routine step, which stays on the device), or any advertising ID.</p>

<h2>Cloud backup</h2>
<p>By default, a private copy of the data above (except photos) is kept in Google Firebase (Cloud Firestore and Firebase Authentication) under a random anonymous ID. Only that account can read or write it. A grown-up can switch the backup off at any time in the app (Grown-ups area → Backup &amp; account); the data then stays only on the device. Google processes this data on our behalf under the <a href="https://firebase.google.com/support/privacy">Firebase terms</a>. Data is encrypted in transit and at rest.</p>

<h2>Permissions</h2>
<p>The app only asks for internet access (for the optional cloud backup). Adding a photo to a routine uses Android's own photo picker or camera, so the app never gets access to your photo library or camera.</p>

<h2>Sharing</h2>
<p>We do not sell, rent or share data with anyone. The PDF summary is only created when a grown-up taps "Export", and it is only shared where the grown-up chooses (for example with a therapist).</p>

<h2>Children</h2>
<p>The app is designed for children under the supervision of a parent, carer or therapist, and follows Google Play's Families Policy. Settings, account options, links and sharing are behind a question young children can't answer. No personal information is collected from the child beyond the optional nickname entered by a grown-up.</p>

<h2>Keeping and deleting data</h2>
<p>Data is kept until you delete it. In the app: Grown-ups area → Backup &amp; account → <b>Delete account and all cloud data</b> removes everything from the device and the cloud immediately. You can also remove a single child in the Children tab. If you no longer have the app, see <a href="delete-account.html">how to delete your data</a>.</p>

<h2>Your rights</h2>
<p>You can ask us what data we hold about you, ask for a copy, correct it, or have it deleted, by emailing <a href="mailto:{EMAIL}">{EMAIL}</a>. We reply within 30 days.</p>

<h2>Changes</h2>
<p>If this policy changes, we will update this page and the date above.</p>

<h2>Contact</h2>
<p>HomiLabs · <a href="mailto:{EMAIL}">{EMAIL}</a></p>
</main>"""

TERMS = f"""<main class="wrap narrow doc">
<h1>Terms and Conditions</h1>
<p class="meta">Sensory SafeScape (Android app <code>com.homilabs.safescape</code>) by HomiLabs · Last updated {UPDATED}</p>

<p>These terms apply to your use of the Sensory SafeScape app. By installing or using the app you agree to them. If you don't agree, please uninstall the app.</p>

<h2>1. What the app is</h2>
<p>Sensory SafeScape offers calming sensory activities (the Calming Canvas and Soothing Sounds), visual routines and a wait timer for children, with settings and a usage summary for parents, carers and therapists. It is free and has no ads or in-app purchases.</p>

<h2>2. Not a medical device</h2>
<p class="disclaimer">Sensory SafeScape is an educational and calming tool. It is <b>not a medical device</b> and does not diagnose, treat, cure or prevent any condition, including autism or sensory processing differences. It does not replace advice or therapy from a doctor, occupational therapist, speech therapist or other qualified professional. The progress view and PDF summary report how the app was used; they are not a clinical assessment.</p>
<p>If a child is in distress, unwell or unsafe, seek help from a qualified person or emergency services. Do not rely on the app.</p>

<h2>3. Adult supervision</h2>
<p>The app is meant to be set up and supervised by a parent, carer, teacher or therapist ("grown-up"). Grown-ups are responsible for choosing settings that suit the child (for example sound level, motion and lighting), for deciding how long the child uses the device, and for any photos or text they add to routines. Stop using the app if it seems to upset or overstimulate the child.</p>

<h2>4. Your account and data</h2>
<p>No sign-up is needed. If you turn on cloud backup or add an email, you are responsible for keeping your password safe. How we handle data is explained in the <a href="privacy.html">Privacy Policy</a>. You can delete your data at any time (see <a href="delete-account.html">Delete my account</a>).</p>

<h2>5. Acceptable use</h2>
<p>Please don't copy, resell, reverse-engineer or modify the app, misuse the cloud backup service, try to access other people's data, or use the app for anything unlawful.</p>

<h2>6. Content you add</h2>
<p>Routine titles, stories and photos you add remain yours. Photos stay on your device. Text is included in your private cloud backup only if backup is on, and only to provide that backup to you.</p>

<h2>7. Intellectual property</h2>
<p>The app, its design, code, sounds and characters (including Sammy the Turtle) belong to HomiLabs. Routine pictures come from Noto Emoji by Google (Apache License 2.0); the Andika font is by SIL International (SIL Open Font License 1.1).</p>

<h2>8. Availability and changes</h2>
<p>We work to keep the app and its backup service running, but we can't promise they will always be available or error-free. We may update, change or stop features. The app works without internet; only the cloud backup needs a connection.</p>

<h2>9. No warranty and limitation of liability</h2>
<p>The app is provided free of charge, "as is" and "as available". To the extent the law allows, HomiLabs gives no warranties and is not liable for any indirect or consequential loss, or for loss of data, arising from using or being unable to use the app. Nothing in these terms limits rights you have under consumer law that cannot be excluded.</p>

<h2>10. Changes to these terms</h2>
<p>We may update these terms. The date above shows the latest version; continuing to use the app after a change means you accept the updated terms.</p>

<h2>11. Governing law</h2>
<p>These terms are governed by the laws of Pakistan, without affecting any mandatory consumer protections of the country where you live.</p>

<h2>12. Contact</h2>
<p>HomiLabs · <a href="mailto:{EMAIL}">{EMAIL}</a></p>
</main>"""

DELETE = f"""<main class="wrap narrow doc">
<h1>Delete my account and data</h1>
<p class="meta">Sensory SafeScape by HomiLabs (<code>com.homilabs.safescape</code>)</p>
<p>You can delete your Sensory SafeScape account and all of its data at any time, in the app or by email.</p>

<div class="card">
<h2 style="margin-top:4px">Option 1: in the app (immediate)</h2>
<ol class="steps">
<li>Open SafeScape and tap the <b>lock</b> at the top-left of the home screen.</li>
<li>Answer the grown-up question.</li>
<li>Open the <b>Backup &amp; account</b> tab.</li>
<li>Tap <b>Delete account and all cloud data</b> and confirm (if you added an email, enter your password).</li>
</ol>
<p>This permanently deletes every child profile, routine, photo and activity record from the device and from our cloud backup, and closes the account. It cannot be undone.</p>
</div>

<div class="card" style="margin-top:18px">
<h2 style="margin-top:4px">Option 2: by email (if you no longer have the app)</h2>
<p>Email <a href="mailto:{EMAIL}?subject=SafeScape%20account%20deletion">{EMAIL}</a> with the subject <b>"SafeScape account deletion"</b>, from the email address linked to your SafeScape backup. We delete the account and all its data within 30 days and confirm by email.</p>
<p class="meta">If you never linked an email, your backup is anonymous: uninstalling the app removes the copy on the phone, and the anonymous cloud copy cannot be linked to you. You can still ask us to delete it by sending the Account ID shown in the app (Grown-ups area → Backup &amp; account).</p>
</div>

<h2>What is deleted</h2>
<ul class="ticks">
<li>Child nicknames and age groups</li>
<li>Sensory settings and routines</li>
<li>Activity times and progress</li>
<li>The account itself, including the email if one was linked</li>
</ul>
<p>Nothing is kept after deletion. Photos added to routines were only ever stored on the phone and are removed from it too.</p>

<h2>Only want to stop the cloud backup?</h2>
<p>In Grown-ups area → Backup &amp; account, switch off <b>Private cloud backup</b>. Everything then stays only on the phone.</p>
</main>"""


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "style.css").write_text(CSS)
    page("index.html", "Sensory SafeScape: calm sensory play and visual routines for kids",
         "Calm sensory play and picture routines for autistic and sensory-sensitive children aged 2 to 10. Free, no ads, no tracking, no sign-up.",
         INDEX, "index.html")
    page("privacy.html", "Privacy Policy · Sensory SafeScape",
         "How Sensory SafeScape handles data: minimal, never sold or shared, photos stay on the device.", PRIVACY, "privacy.html")
    page("terms.html", "Terms and Conditions · Sensory SafeScape",
         "Terms and conditions for using the Sensory SafeScape app.", TERMS, "terms.html")
    page("delete-account.html", "Delete my account · Sensory SafeScape",
         "How to delete your Sensory SafeScape account and all of its data, in the app or by email.", DELETE, "delete-account.html")
    print("website written to", OUT)


if __name__ == "__main__":
    main()
