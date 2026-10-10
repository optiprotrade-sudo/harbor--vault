#!/usr/bin/env python3
"""Applies required Android-only settings after `flutter create`."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
manifest = root / 'android/app/src/main/AndroidManifest.xml'
if not manifest.exists():
    raise SystemExit('No AndroidManifest.xml: run flutter create first.')
xml = manifest.read_text(encoding='utf-8')
if 'android.permission.USE_BIOMETRIC' not in xml:
    xml = xml.replace('<application',
                      '    <uses-permission android:name="android.permission.USE_BIOMETRIC" />\n    <application',
                      1)
if 'android.permission.INTERNET' not in xml:
    xml = xml.replace('<application',
                      '    <uses-permission android:name="android.permission.INTERNET" />\n    <application',
                      1)
if 'android:allowBackup=' not in xml:
    xml = xml.replace('<application', '<application android:allowBackup="false"', 1)
xml = xml.replace('android:label="harbor_vault"', 'android:label="Harbor Vault"')
manifest.write_text(xml, encoding='utf-8')

kotlin_gradle = root / 'android/app/build.gradle.kts'
groovy_gradle = root / 'android/app/build.gradle'
if kotlin_gradle.exists():
    content = kotlin_gradle.read_text(encoding='utf-8')
    content = content.replace('minSdk = flutter.minSdkVersion', 'minSdk = 24')
    kotlin_gradle.write_text(content, encoding='utf-8')
elif groovy_gradle.exists():
    content = groovy_gradle.read_text(encoding='utf-8')
    content = content.replace('minSdkVersion flutter.minSdkVersion', 'minSdkVersion 24')
    groovy_gradle.write_text(content, encoding='utf-8')
else:
    raise SystemExit('Android Gradle configuration missing.')
print('Android manifest and minimum SDK settings applied.')

# Flutter's template uses FlutterActivity. local_auth requires FragmentActivity.
for activity in (root / 'android/app/src/main').rglob('MainActivity.kt'):
    content = activity.read_text(encoding='utf-8')
    content = content.replace('import io.flutter.embedding.android.FlutterActivity',
                              'import io.flutter.embedding.android.FlutterFragmentActivity')
    content = content.replace(' : FlutterActivity()', ' : FlutterFragmentActivity()')
    content = content.replace(': FlutterActivity()', ': FlutterFragmentActivity()')
    activity.write_text(content, encoding='utf-8')
for activity in (root / 'android/app/src/main').rglob('MainActivity.java'):
    content = activity.read_text(encoding='utf-8')
    content = content.replace('import io.flutter.embedding.android.FlutterActivity;',
                              'import io.flutter.embedding.android.FlutterFragmentActivity;')
    content = content.replace('extends FlutterActivity', 'extends FlutterFragmentActivity')
    activity.write_text(content, encoding='utf-8')

# Provide an AppCompat theme for Android biometric dialogs on older devices.
# AppCompat is available only if AndroidX appcompat is also declared below.
for styles in (root / 'android/app/src/main/res').glob('values*/styles.xml'):
    content = styles.read_text(encoding='utf-8')
    content = content.replace('parent="@android:style/Theme.Light.NoTitleBar"',
                              'parent="Theme.AppCompat.DayNight.NoActionBar"')
    content = content.replace('parent="@android:style/Theme.Black.NoTitleBar"',
                              'parent="Theme.AppCompat.DayNight.NoActionBar"')
    styles.write_text(content, encoding='utf-8')
if kotlin_gradle.exists():
    content = kotlin_gradle.read_text(encoding='utf-8')
    if 'androidx.appcompat:appcompat:' not in content:
        content += '\ndependencies {\n    implementation("androidx.appcompat:appcompat:1.7.0")\n}\n'
    kotlin_gradle.write_text(content, encoding='utf-8')
elif groovy_gradle.exists():
    content = groovy_gradle.read_text(encoding='utf-8')
    if 'androidx.appcompat:appcompat:' not in content:
        content += "\ndependencies {\n    implementation 'androidx.appcompat:appcompat:1.7.0'\n}\n"
    groovy_gradle.write_text(content, encoding='utf-8')
print('Local device-auth platform settings applied.')
