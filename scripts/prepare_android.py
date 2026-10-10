#!/usr/bin/env python3
"""Applies required Android-only settings after `flutter create`."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
manifest = root / 'android/app/src/main/AndroidManifest.xml'
if not manifest.exists():
    raise SystemExit('No AndroidManifest.xml: run flutter create first.')
xml = manifest.read_text(encoding='utf-8')
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
    content = content.replace('minSdk = flutter.minSdkVersion', 'minSdk = 23')
    kotlin_gradle.write_text(content, encoding='utf-8')
elif groovy_gradle.exists():
    content = groovy_gradle.read_text(encoding='utf-8')
    content = content.replace('minSdkVersion flutter.minSdkVersion', 'minSdkVersion 23')
    groovy_gradle.write_text(content, encoding='utf-8')
else:
    raise SystemExit('Android Gradle configuration missing.')
print('Android manifest and minimum SDK settings applied.')
