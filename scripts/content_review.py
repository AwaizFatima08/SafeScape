#!/usr/bin/env python3
"""Render the child-facing wording of Learn with Sammy and Picture Stories
into docs/v1.2-content-review.md so the owner can review every sentence.

    python3 scripts/content_review.py
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
lessons = json.loads((ROOT / "assets/content/lessons.json").read_text())
stories = json.loads((ROOT / "assets/content/stories.json").read_text())

out = ["# v1.2 content review: every sentence a child will see and hear",
       "",
       "Generated from `assets/content/*.json` by `scripts/content_review.py`. Edit the JSON, then rerun.",
       "Each card's picture is shown in [brackets] (a Noto Emoji pictogram key).",
       "",
       f"## Learn with Sammy ({len(lessons['chapters'])} chapters)", ""]
for n, c in enumerate(lessons["chapters"], 1):
    out.append(f"### {n}. {c['title']}  [{c['icon']}]")
    out.append(f"*{c['summary']}*")
    out.append("")
    for i, card in enumerate(c["cards"], 1):
        out.append(f"{i}. {card['text']}  [{card['icon']}]")
    p = c["practice"]
    out.append("")
    out.append(f"**Practice ({p['type']}):** {p['prompt']}")
    if p["type"] == "choose":
        out.append("Options: " + ", ".join(f"{o['label']} [{o['icon']}]" for o in p["options"]))
    elif p["type"] == "count":
        out.append("Steps: " + "; ".join(f"{s['label']} ({s['count']} stars) [{s['icon']}]" for s in p["steps"]))
    elif p["type"] == "squeeze":
        out.append(f"Squeeze and let go {p['times']} times.")
    elif p["type"] == "breathe":
        out.append(f"{p['breaths']} slow breaths (4 s in, 6 s out).")
    out.append(f"Sammy replies: \"{p['reply']}\"")
    out.append("")

out += [f"## Picture Stories ({len(stories['stories'])} stories)", ""]
for n, s in enumerate(stories["stories"], 1):
    out.append(f"### {n}. {s['title']}  [{s['icon']}]")
    out.append("")
    for i, page in enumerate(s["pages"], 1):
        out.append(f"{i}. {page['text']}  [{page['icon']}]")
    out.append("")

words = sum(len(c["text"].split()) for ch in lessons["chapters"] for c in ch["cards"]) + \
    sum(len(p["text"].split()) for s in stories["stories"] for p in s["pages"])
out.append(f"---\nTotal: {len(lessons['chapters'])} chapters, {len(stories['stories'])} stories, about {words} words.")
(ROOT / "docs/v1.2-content-review.md").write_text("\n".join(out) + "\n")
print("docs/v1.2-content-review.md written,", words, "words")
