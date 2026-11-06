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
]
missing = [p for p in perms if p not in s]
if missing:
    lines = "".join(f'\n    <uses-permission android:name="{p}" />' for p in missing)
    s = re.sub(r"(<manifest\b[^>]*>)", r"\1" + lines, s, count=1)

# 同じWiFi内の端末同士は http で直接通信するため平文通信を許可
if "usesCleartextTraffic" not in s:
    s = s.replace("<application", '<application\n        android:usesCleartextTraffic="true"', 1)

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

print("Android の設定を追加しました")
print(s)
