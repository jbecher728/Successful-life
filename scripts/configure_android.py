"""Configure generated Android Flutter host for privacy and notifications."""
from pathlib import Path
from xml.etree import ElementTree as ET
p=Path('android/app/src/main/AndroidManifest.xml')
ET.register_namespace('android','http://schemas.android.com/apk/res/android')
ns='{http://schemas.android.com/apk/res/android}'
tree=ET.parse(p)
root=tree.getroot()
for name in ['android.permission.POST_NOTIFICATIONS','android.permission.RECEIVE_BOOT_COMPLETED','android.permission.USE_BIOMETRIC']:
    if not any(x.get(ns+'name')==name for x in root.findall('uses-permission')):
        ET.SubElement(root,'uses-permission',{ns+'name':name})
app=root.find('application')
app.set(ns+'allowBackup','true')
app.set(ns+'fullBackupContent','@xml/backup_rules')
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
# Only one opt-in, passphrase-encrypted file may ever be backed up; it exists only if the user turns Google backup on.
(xml/'data_extraction_rules.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<data-extraction-rules><cloud-backup><include domain="file" path="cloud_backup.bin"/></cloud-backup><device-transfer><include domain="file" path="cloud_backup.bin"/></device-transfer></data-extraction-rules>''')
(xml/'backup_rules.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<full-backup-content><include domain="file" path="cloud_backup.bin"/></full-backup-content>''')
tree.write(p,encoding='utf-8',xml_declaration=True)
# Local notification plugin may require core library desugaring on newer Android Gradle plugins.
gradle=Path('android/app/build.gradle.kts')
if gradle.exists():
    text=gradle.read_text()
    if 'isCoreLibraryDesugaringEnabled' not in text:
        text=text.replace('compileOptions {','compileOptions {\n        isCoreLibraryDesugaringEnabled = true',1)
    if 'coreLibraryDesugaring(' not in text:
        text+='\n\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n    implementation("androidx.appcompat:appcompat:1.7.0")\n}\n'
    gradle.write_text(text)
print('Android notifications and local-only backup configuration applied')
# Some plugins (flutter_timezone) declare mismatched Java/Kotlin JVM targets; don't fail the build over it.
gp=Path('android/gradle.properties')
gtext=gp.read_text() if gp.exists() else ''
if 'kotlin.jvm.target.validation.mode' not in gtext:
    gp.write_text(gtext.rstrip('\n')+'\nkotlin.jvm.target.validation.mode=IGNORE\n')

# Some plugins are compiled against older Android APIs than their dependencies require. Raise them to 36.
root=Path('android/build.gradle.kts')
if root.exists():
    rt=root.read_text()
    if 'compileSdkVersion(36)' not in rt:
        hook='''subprojects {
    afterEvaluate {
        if (project.name != "app") {
            val androidExt = extensions.findByName("android")
            if (androidExt != null) {
                androidExt.withGroovyBuilder { "compileSdkVersion"(36) }
            }
        }
    }
}

'''
        i=rt.find('subprojects {')
        rt=hook+rt if i<0 else rt[:i]+hook+rt[i:]
        root.write_text(rt)
print('Plugin compileSdk override applied')

# local_auth (biometrics) needs a FragmentActivity and an AppCompat theme.
import glob, re
for f in glob.glob('android/app/src/main/**/MainActivity.kt', recursive=True):
    k=Path(f); kt=k.read_text()
    if 'FlutterFragmentActivity' not in kt:
        kt=kt.replace('import io.flutter.embedding.android.FlutterActivity','import io.flutter.embedding.android.FlutterFragmentActivity').replace('FlutterActivity()','FlutterFragmentActivity()')
        k.write_text(kt)
for f in glob.glob('android/app/src/main/res/values*/styles.xml'):
    k=Path(f); st=k.read_text()
    st=st.replace('parent="@android:style/Theme.Light.NoTitleBar"','parent="Theme.AppCompat.Light.NoActionBar"').replace('parent="@android:style/Theme.Black.NoTitleBar"','parent="Theme.AppCompat.NoActionBar"')
    k.write_text(st)
print('Biometric support configured')

# Smaller release builds: shrink code and resources, and keep what the notification plugin needs at runtime.
Path('android/app/proguard-rules.pro').write_text('''-keepattributes Signature,*Annotation*,InnerClasses,EnclosingMethod
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-dontwarn com.google.android.play.core.**
''')
g=Path('android/app/build.gradle.kts')
if g.exists():
    gt=g.read_text()
    marker='signingConfig = signingConfigs.getByName("debug")'
    if marker in gt and 'proguard-rules.pro' not in gt:
        gt=gt.replace(marker,marker+'\n            isMinifyEnabled = true\n            isShrinkResources = true\n            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")',1)
        g.write_text(gt)
        print('Release shrinking enabled')
    else:
        print('WARNING: release shrinking marker not found')
