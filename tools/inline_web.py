#!/usr/bin/env python3
"""Bundles the Expo web export (dist/) into one self-contained HTML file.

Usage: npx expo export --platform web && python3 tools/inline_web.py dist out.html
Assets referenced from the JS bundle ("/assets/…") become data: URIs, the bundle is inlined.
"""
import base64, mimetypes, os, re, sys

dist, out = sys.argv[1], sys.argv[2]
html = open(os.path.join(dist, "index.html"), encoding="utf-8").read()
src = re.search(r'<script src="([^"]+\.js)"[^>]*></script>', html)
js = open(os.path.join(dist, src.group(1).lstrip("/")), encoding="utf-8").read()

def data_uri(path):
    full = os.path.join(dist, path.lstrip("/"))
    mime = mimetypes.guess_type(full)[0] or ("font/ttf" if full.endswith(".ttf") else "application/octet-stream")
    return f"data:{mime};base64," + base64.b64encode(open(full, "rb").read()).decode()

count = 0
def repl(m):
    global count
    path = m.group(1)
    if os.path.exists(os.path.join(dist, path.lstrip("/"))):
        count += 1
        return '"' + data_uri(path) + '"'
    return m.group(0)

js = re.sub(r'["\'](/assets/[^"\']+\.(?:ttf|png|jpg|otf))["\']', repl, js)
js = js.replace("</script", "<\\/script")
html = html.replace(src.group(0), "")
# Expo Router routes on location.pathname; the hosting page lives at an arbitrary path, so start at "/".
# A plain "#name" in the link opens that screen (e.g. #paywall, #food-safety).
boot = "<script>if(!/keep=1/.test(location.search))try{var h=location.hash.slice(1);history.replaceState(null,'','/'+(/^[a-z-]+$/.test(h)?h:''))}catch(e){}</script>"
html = html.replace("</body>", f"{boot}<script>{js}</script></body>")
open(out, "w", encoding="utf-8").write(html)
print(f"inlined {count} assets → {out} ({os.path.getsize(out)/1e6:.1f} MB)")
