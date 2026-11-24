"""Configure the generated Flutter iOS host: Face ID text, name, iPhone-only, notifications, no iCloud backup."""
import re
from pathlib import Path
import plistlib

pl = Path('ios/Runner/Info.plist')
if pl.exists():
    d = plistlib.loads(pl.read_bytes())
    d['CFBundleDisplayName'] = 'Successful Life'
    d['NSFaceIDUsageDescription'] = 'Face ID is used to unlock Successful Life if you turn on the app lock. Nothing is stored or sent.'
    pl.write_bytes(plistlib.dumps(d))
    print('Info.plist updated')

proj = Path('ios/Runner.xcodeproj/project.pbxproj')
if proj.exists():
    t = proj.read_text()
    t = t.replace('TARGETED_DEVICE_FAMILY = "1,2";', 'TARGETED_DEVICE_FAMILY = "1";')
    proj.write_text(t)
    print('iPhone-only')

ad = Path('ios/Runner/AppDelegate.swift')
if ad.exists():
    s = ad.read_text()
    if 'isExcludedFromBackup' not in s:
        inject = """
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    // Keep the app's data out of iCloud and iTunes backups (privacy: data stays on this phone).
    for dir in [FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
                FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first] {
      if var u = dir {
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        var rv = URLResourceValues()
        rv.isExcludedFromBackup = true
        try? u.setResourceValues(rv)
      }
    }
"""
        m = re.search(r'didFinishLaunchingWithOptions[^{]*\{', s)
        if m:
            s = s[:m.end()] + inject + s[m.end():]
            if 'import UserNotifications' not in s:
                s = s.replace('import UIKit', 'import UIKit\nimport UserNotifications', 1)
            ad.write_text(s)
            print('AppDelegate patched')
        else:
            print('WARNING: AppDelegate launch method not found; notifications and backup exclusion not patched')
