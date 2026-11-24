"""Configure the generated Flutter web host as an installable, private app."""
import json, re
from pathlib import Path

mf = Path('web/manifest.json')
if mf.exists():
    d = json.loads(mf.read_text())
    d.update({'name': 'Successful Life', 'short_name': 'Successful Life', 'display': 'standalone',
              'background_color': '#F8FAF8', 'theme_color': '#21877C',
              'description': 'A private personal-development companion. Your data stays on this device.'})
    mf.write_text(json.dumps(d, indent=2))
ix = Path('web/index.html')
if ix.exists():
    h = ix.read_text()
    h = re.sub(r'<title>.*?</title>', '<title>Successful Life</title>', h)
    h = re.sub(r'(<meta name="apple-mobile-web-app-title" content=")[^"]*', r'\1Successful Life', h)
    if 'apple-mobile-web-app-capable' not in h:
        h = h.replace('</head>', '  <meta name="apple-mobile-web-app-capable" content="yes">\n</head>')
    ix.write_text(h)
print('web configured')
