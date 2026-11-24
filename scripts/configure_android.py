"""Configure generated Android Flutter host for privacy and notifications."""
from pathlib import Path
from xml.etree import ElementTree as ET
p=Path('android/app/src/main/AndroidManifest.xml')
ET.register_namespace('android','http://schemas.android.com/apk/res/android')
ns='{http://schemas.android.com/apk/res/android}'
tree=ET.parse(p)
root=tree.getroot()
for name in ['android.permission.POST_NOTIFICATIONS','android.permission.RECEIVE_BOOT_COMPLETED']:
    if not any(x.get(ns+'name')==name for x in root.findall('uses-permission')):
        ET.SubElement(root,'uses-permission',{ns+'name':name})
app=root.find('application')
app.set(ns+'allowBackup','false')
app.set(ns+'fullBackupContent','false')
app.set(ns+'dataExtractionRules','@xml/data_extraction_rules')
# Notifications plugin requires receivers for scheduled delivery after reboot.
for cls in ['com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver',
            'com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver']:
    if not any(x.get(ns+'name')==cls for x in app.findall('receiver')):
        attrs={ns+'name':cls,ns+'exported':'false' if cls.endswith('ScheduledNotificationReceiver') else 'true'}
        r=ET.SubElement(app,'receiver',attrs)
        if cls.endswith('ScheduledNotificationBootReceiver'):
            intent=ET.SubElement(r,'intent-filter')
            for action in ['android.intent.action.BOOT_COMPLETED','android.intent.action.MY_PACKAGE_REPLACED','android.intent.action.QUICKBOOT_POWERON','com.htc.intent.action.QUICKBOOT_POWERON']:
                ET.SubElement(intent,'action',{ns+'name':action})
xml=Path('android/app/src/main/res/xml');xml.mkdir(parents=True,exist_ok=True)
(xml/'data_extraction_rules.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<data-extraction-rules><cloud-backup><exclude domain="root" path="."/></cloud-backup><device-transfer><exclude domain="root" path="."/></device-transfer></data-extraction-rules>''')
tree.write(p,encoding='utf-8',xml_declaration=True)
# Local notification plugin may require core library desugaring on newer Android Gradle plugins.
gradle=Path('android/app/build.gradle.kts')
if gradle.exists():
    text=gradle.read_text()
    if 'isCoreLibraryDesugaringEnabled' not in text:
        text=text.replace('compileOptions {','compileOptions {\n        isCoreLibraryDesugaringEnabled = true',1)
    if 'coreLibraryDesugaring(' not in text:
        text+='\n\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    gradle.write_text(text)
print('Android notifications and local-only backup configuration applied')
# Some plugins (flutter_timezone) declare mismatched Java/Kotlin JVM targets; don't fail the build over it.
gp=Path('android/gradle.properties')
gtext=gp.read_text() if gp.exists() else ''
if 'kotlin.jvm.target.validation.mode' not in gtext:
    gp.write_text(gtext.rstrip('\n')+'\nkotlin.jvm.target.validation.mode=IGNORE\n')
