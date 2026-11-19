#!/usr/bin/env python3
"""Regenerates server/site/terms.html and privacy.html from docs/LEGAL.md."""
import os, re
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
legal = open(os.path.join(ROOT, "docs", "LEGAL.md"), encoding="utf-8").read()

def md(block):
    out, inlist = [], False
    for line in block.strip().split("\n"):
        l = line.strip()
        if not l:
            if inlist: out.append("</ul>"); inlist = False
            continue
        l = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", l)
        l = re.sub(r"`(.+?)`", r"<code>\1</code>", l)
        if l.startswith("- "):
            if not inlist: out.append("<ul>"); inlist = True
            out.append("<li>" + l[2:] + "</li>")
        elif line.startswith("  ") and out and out[-1].endswith("</li>"):
            out[-1] = out[-1][:-5] + " " + l + "</li>"
        elif line.startswith("  ") and out and out[-1].endswith("</p>"):
            out[-1] = out[-1][:-4] + " " + l + "</p>"
        else:
            out.append("<p>" + l + "</p>")
    if inlist: out.append("</ul>")
    return "\n".join(out)

terms = legal.split("## Terms of Use")[1].split("## Privacy Policy")[0]
privacy = legal.split("## Privacy Policy")[1]
privacy = privacy.replace("see pettrack.bagce.dev/support", "{{CONTACT_EMAIL}}")
privacy = re.sub(r"\*\*Hosting:\*\*.*", "**Hosting:** {{HOSTING}}", privacy)
head = '<nav class="wrap" style="max-width:760px"><a class="logo" href="/"><img src="/site/img/apple-touch-icon.png" alt="" width="34" height="34" style="border-radius:9px">PetTrack</a></nav>'
site = os.path.join(ROOT, "server", "site")
open(os.path.join(site, "terms.html"), "w", encoding="utf-8").write(
    f'<title>Terms of Use – PetTrack</title></head><body>{head}<main class="doc"><span class="eyebrow">Legal</span><h1>Terms of Use</h1>'
    f'<p class="updated">Last updated {{{{UPDATED}}}} · Operator: {{{{OPERATOR}}}} · Contact: {{{{CONTACT_EMAIL}}}}</p>{md(terms)}</main>')
open(os.path.join(site, "privacy.html"), "w", encoding="utf-8").write(
    f'<title>Privacy Policy – PetTrack</title></head><body>{head}<main class="doc"><span class="eyebrow">Legal</span><h1>Privacy Policy</h1>'
    f'<p class="updated">Last updated {{{{UPDATED}}}} · Controller: {{{{OPERATOR}}}} · Contact: {{{{CONTACT_EMAIL}}}}</p>{md(privacy)}'
    '<h2>Changes</h2><p>We will post any changes on this page and update the date above.</p></main>')
print("legal pages rebuilt")
