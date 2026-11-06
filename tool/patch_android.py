"""flutter create が生成した Android プロジェクトに、WiFi通信に必要な設定を追加する。"""
import os
import pathlib
import re
import shutil
import sys

root = pathlib.Path(__file__).resolve().parent.parent
manifest = root / "android/app/src/main/AndroidManifest.xml"
s = manifest.read_text(encoding="utf-8")

perms = [
    "android.permission.INTERNET",
    "android.permission.ACCESS_WIFI_STATE",
    "android.permission.ACCESS_NETWORK_STATE",
    "android.permission.CHANGE_WIFI_MULTICAST_STATE",
    "com.google.android.gms.permission.AD_ID",  # 広告ID（Android 13 以降で広告を出すために必要）
]
missing = [p for p in perms if p not in s]
if missing:
    lines = "".join(f'\n    <uses-permission android:name="{p}" />' for p in missing)
    s = re.sub(r"(<manifest\b[^>]*>)", r"\1" + lines, s, count=1)

# 同じWiFi内の端末同士は http で直接通信するため平文通信を許可
if "usesCleartextTraffic" not in s:
    s = s.replace("<application", '<application\n        android:usesCleartextTraffic="true"', 1)

# AdMob のアプリID（広告を表示するために必須。公開してよいID）
ADMOB_APP_ID = "ca-app-pub-6787171058926480~6110309787"
if "com.google.android.gms.ads.APPLICATION_ID" not in s:
    meta = (
        '    <meta-data\n'
        '            android:name="com.google.android.gms.ads.APPLICATION_ID"\n'
        f'            android:value="{ADMOB_APP_ID}"/>\n'
        '    </application>'
    )
    s = s.replace("</application>", meta, 1)

s = re.sub(r'android:label="[^"]*"', 'android:label="WiFi Match"', s, count=1)
manifest.write_text(s, encoding="utf-8")

# MainActivity を MulticastLock 対応版に差し替え
kt_dir = root / "android/app/src/main/kotlin/com/wifimatch/wifi_match"
if not kt_dir.is_dir():
    sys.exit(f"MainActivity の場所が見つかりません: {kt_dir}")
for old in kt_dir.glob("MainActivity.*"):
    old.unlink()
shutil.copy(root / "tool/MainActivity.kt", kt_dir / "MainActivity.kt")

# アプリのアイコンを差し替え
for density in ["mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"]:
    src = root / f"assets/icon/ic_launcher_{density}.png"
    dst = root / f"android/app/src/main/res/mipmap-{density}/ic_launcher.png"
    if src.exists() and dst.parent.is_dir():
        shutil.copy(src, dst)

# 広告ライブラリが使う WorkManager が、コード圧縮（R8）で壊れて起動時に落ちるため、圧縮を無効にする
minify_done = False
for gradle_name in ("build.gradle.kts", "build.gradle"):
    gradle = root / "android/app" / gradle_name
    if not gradle.exists():
        continue
    text = gradle.read_text(encoding="utf-8")
    if "isMinifyEnabled" in text or "minifyEnabled" in text:
        minify_done = True
        break
    if gradle_name.endswith(".kts"):
        extra = "isMinifyEnabled = false\n\\2isShrinkResources = false"
    else:
        extra = "minifyEnabled false\n\\2shrinkResources false"
    new_text, n = re.subn(r"(\n([ \t]*)signingConfig\b[^\n]*)", r"\1\n\2" + extra, text, count=1)
    if n:
        gradle.write_text(new_text, encoding="utf-8")
        minify_done = True
        print(f"{gradle_name}: コード圧縮を無効にしました")
        break
if not minify_done:
    sys.exit("android/app の build.gradle に release の設定が見つかりません（コード圧縮を無効にできませんでした）")

# ストア公開用: 署名鍵の環境変数があるときだけ、リリース署名を設定する（普通のAPKビルドは今まで通り）
if os.environ.get("ANDROID_KEYSTORE_FILE"):
    sign_done = False
    for gradle_name in ("build.gradle.kts", "build.gradle"):
        gradle = root / "android/app" / gradle_name
        if not gradle.exists():
            continue
        text = gradle.read_text(encoding="utf-8")
        if gradle_name.endswith(".kts"):
            block = (
                "    signingConfigs {\n"
                '        create("release") {\n'
                '            storeFile = file(System.getenv("ANDROID_KEYSTORE_FILE"))\n'
                '            storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")\n'
                '            keyAlias = System.getenv("ANDROID_KEY_ALIAS")\n'
                '            keyPassword = System.getenv("ANDROID_KEY_PASSWORD")\n'
                '            storeType = "pkcs12"\n'
                "        }\n"
                "    }\n"
            )
            text2 = text.replace('signingConfigs.getByName("debug")', 'signingConfigs.getByName("release")')
        else:
            block = (
                "    signingConfigs {\n"
                "        release {\n"
                '            storeFile file(System.getenv("ANDROID_KEYSTORE_FILE"))\n'
                '            storePassword System.getenv("ANDROID_KEYSTORE_PASSWORD")\n'
                '            keyAlias System.getenv("ANDROID_KEY_ALIAS")\n'
                '            keyPassword System.getenv("ANDROID_KEY_PASSWORD")\n'
                '            storeType "pkcs12"\n'
                "        }\n"
                "    }\n"
            )
            text2 = text.replace("signingConfigs.debug", "signingConfigs.release")
        if text2 == text:
            continue
        text3, n = re.subn(r"(\n[ \t]*buildTypes\s*\{)", lambda m: "\n" + block + m.group(1), text2, count=1)
        if n:
            gradle.write_text(text3, encoding="utf-8")
            sign_done = True
            print(f"{gradle_name}: リリース署名を設定しました")
            break
    if not sign_done:
        sys.exit("android/app の build.gradle にリリース署名を設定できませんでした")

print("Android の設定を追加しました")
print(s)
"""flutter create が生成した Android プロジェクトに、WiFi通信に必要な設定を追加する。"""
import pathlib
import re
import shutil
import sys

root = pathlib.Path(__file__).resolve().parent.parent
manifest = root / "android/app/src/main/AndroidManifest.xml"
s = manifest.read_text(encoding="utf-8")

perms = [
    "android.permission.INTERNET",
    "android.permission.ACCESS_WIFI_STATE",
    "android.permission.ACCESS_NETWORK_STATE",
    "android.permission.CHANGE_WIFI_MULTICAST_STATE",
    "com.google.android.gms.permission.AD_ID",  # 広告ID（Android 13 以降で広告を出すために必要）
]
missing = [p for p in perms if p not in s]
if missing:
    lines = "".join(f'\n    <uses-permission android:name="{p}" />' for p in missing)
    s = re.sub(r"(<manifest\b[^>]*>)", r"\1" + lines, s, count=1)

# 同じWiFi内の端末同士は http で直接通信するため平文通信を許可
if "usesCleartextTraffic" not in s:
    s = s.replace("<application", '<application\n        android:usesCleartextTraffic="true"', 1)

# AdMob のアプリID（広告を表示するために必須。公開してよいID）
ADMOB_APP_ID = "ca-app-pub-6787171058926480~6110309787"
if "com.google.android.gms.ads.APPLICATION_ID" not in s:
    meta = (
        '    <meta-data\n'
        '            android:name="com.google.android.gms.ads.APPLICATION_ID"\n'
        f'            android:value="{ADMOB_APP_ID}"/>\n'
        '    </application>'
    )
    s = s.replace("</application>", meta, 1)

s = re.sub(r'android:label="[^"]*"', 'android:label="WiFi Match"', s, count=1)
manifest.write_text(s, encoding="utf-8")

# MainActivity を MulticastLock 対応版に差し替え
kt_dir = root / "android/app/src/main/kotlin/com/wifimatch/wifi_match"
if not kt_dir.is_dir():
    sys.exit(f"MainActivity の場所が見つかりません: {kt_dir}")
for old in kt_dir.glob("MainActivity.*"):
    old.unlink()
shutil.copy(root / "tool/MainActivity.kt", kt_dir / "MainActivity.kt")

# アプリのアイコンを差し替え
for density in ["mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"]:
    src = root / f"assets/icon/ic_launcher_{density}.png"
    dst = root / f"android/app/src/main/res/mipmap-{density}/ic_launcher.png"
    if src.exists() and dst.parent.is_dir():
        shutil.copy(src, dst)

# 広告ライブラリが使う WorkManager が、コード圧縮（R8）で壊れて起動時に落ちるため、圧縮を無効にする
minify_done = False
for gradle_name in ("build.gradle.kts", "build.gradle"):
    gradle = root / "android/app" / gradle_name
    if not gradle.exists():
        continue
    text = gradle.read_text(encoding="utf-8")
    if "isMinifyEnabled" in text or "minifyEnabled" in text:
        minify_done = True
        break
    if gradle_name.endswith(".kts"):
        extra = "isMinifyEnabled = false\n\\2isShrinkResources = false"
    else:
        extra = "minifyEnabled false\n\\2shrinkResources false"
    new_text, n = re.subn(r"(\n([ \t]*)signingConfig\b[^\n]*)", r"\1\n\2" + extra, text, count=1)
    if n:
        gradle.write_text(new_text, encoding="utf-8")
        minify_done = True
        print(f"{gradle_name}: コード圧縮を無効にしました")
        break
if not minify_done:
    sys.exit("android/app の build.gradle に release の設定が見つかりません（コード圧縮を無効にできませんでした）")

print("Android の設定を追加しました")
print(s)
