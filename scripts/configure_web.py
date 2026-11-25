"""Configure the generated Flutter web host as an installable, private app."""
import json, re
from pathlib import Path

mf = Path('web/manifest.json')
if mf.exists():
    d = json.loads(mf.read_text())
    d.update({'name': 'Shell', 'short_name': 'Shell', 'display': 'standalone',
              'background_color': '#F8FAF8', 'theme_color': '#21877C',
              'description': 'A private personal-development companion. Your data stays on this device.'})
    mf.write_text(json.dumps(d, indent=2))
ix = Path('web/index.html')
if ix.exists():
    h = ix.read_text()
    h = re.sub(r'<title>.*?</title>', '<title>Shell</title>', h)
    h = re.sub(r'(<meta name="apple-mobile-web-app-title" content=")[^"]*', r'\1Shell', h)
    if 'apple-mobile-web-app-capable' not in h:
        h = h.replace('</head>', '  <meta name="apple-mobile-web-app-capable" content="yes">\n</head>')
    ix.write_text(h)
import shutil
for src, dst in [('icons/web/icons', 'web/icons'), ('icons/web/favicon.png', 'web/favicon.png'), ('icons/web/apple-touch-icon.png', 'web/icons/apple-touch-icon.png')]:
    sp = Path(src)
    if sp.is_dir():
        Path(dst).mkdir(parents=True, exist_ok=True)
        for f in sp.glob('*.png'):
            shutil.copy(f, Path(dst) / f.name)
    elif sp.exists():
        Path(dst).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(sp, dst)
if ix.exists():
    h = ix.read_text()
    if 'apple-touch-icon.png' not in h or 'icons/apple-touch-icon.png' not in h:
        h = re.sub(r'<link rel="apple-touch-icon"[^>]*>', '<link rel="apple-touch-icon" href="icons/apple-touch-icon.png">', h)
        ix.write_text(h)
print('web configured')
