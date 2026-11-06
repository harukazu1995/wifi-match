"""WiFi Match テスト相手（相手役のスマホの代わり）

同じWiFiにつないだPCで起動すると、スマホのWiFi Matchアプリに
「テスト相手」として表示されます。

  - 見つけた相手に数秒後に自分からいいねする
  - いいねされたら必ずいいねを返す（＝マッチ）
  - 1対1チャットに自動で返信する
  - 広場に投稿があると返事をする

使い方:  python test_buddy.py   （Windowsでは TestBuddy.exe をダブルクリック）
標準ライブラリだけで動きます。
"""
import argparse
import json
import secrets
import socket
import sys
import threading
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

APP_TAG = "wifimatch"
PROTOCOL = 1
DISCOVERY_PORT = 47801

ap = argparse.ArgumentParser(description="WiFi Match テスト相手")
ap.add_argument("--name", default="テスト相手")
ap.add_argument("--listen-port", type=int, default=DISCOVERY_PORT, help="ビーコンを受け取るUDPポート")
ap.add_argument("--send-port", type=int, default=DISCOVERY_PORT, help="ビーコンを送るUDPポート")
ap.add_argument("--target", action="append", default=[], help="ブロードキャストに加えてビーコンを送るIP")
ap.add_argument("--no-broadcast", action="store_true", help="ブロードキャストせず --target だけに送る")
ap.add_argument("--fast", action="store_true", help="待ち時間を短くする（自動テスト用）")
args = ap.parse_args()

DELAY = 1.0 if args.fast else 6.0
REPLY_DELAY = 0.3 if args.fast else 1.5

me = {
    "id": "bot" + secrets.token_hex(8),
    "name": args.name,
    "emoji": "🐼",
    "bio": "動作確認用のテスト相手です。いいねすると必ずいいねを返します。",
    "tags": ["カフェ", "映画", "ゲーム", "音楽"],
}

lock = threading.Lock()
peers = {}        # id -> {"ip", "port", "profile", "seen"}
likes_out = set()
likes_in = set()
blocked = set()


def log(msg):
    print(time.strftime("%H:%M:%S"), msg, flush=True)


def now_ms():
    return int(time.time() * 1000)


def is_match(pid):
    return pid in likes_out and pid in likes_in and pid not in blocked


def post(pid, path, body):
    with lock:
        p = peers.get(pid)
    if not p:
        raise RuntimeError("相手が見つかりません")
    req = urllib.request.Request(
        f"http://{p['ip']}:{p['port']}{path}",
        data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=5) as r:
        return json.loads(r.read().decode("utf-8") or "{}")


def name_of(pid):
    with lock:
        p = peers.get(pid)
    return p["profile"]["name"] if p else pid


# ---------------- HTTP（スマホからの受信） ----------------
class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def reply(self, status, obj):
        data = json.dumps(obj).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self):
        try:
            n = int(self.headers.get("Content-Length") or 0)
            body = json.loads(self.rfile.read(min(n, 16384)).decode("utf-8"))
        except Exception:
            return self.reply(400, {"error": "bad body"})

        frm = body.get("from")
        sender = frm.get("id") if isinstance(frm, dict) else frm
        with lock:
            p = peers.get(sender)
        if not p or p["ip"] != self.client_address[0]:
            return self.reply(409, {"error": "unknown sender"})
        if sender in blocked:
            return self.reply(403, {"error": "blocked"})
        who = p["profile"]["name"]

        if self.path == "/like":
            likes_in.add(sender)
            first = sender not in likes_out
            likes_out.add(sender)  # いいねされたら必ず返す
            log(f"💌 {who} さんからいいね → いいねを返しました（マッチ！）" if first else f"💞 {who} さんとマッチしました")
            return self.reply(200, {"likedYou": True})

        if self.path == "/unlike":
            likes_in.discard(sender)
            log(f"💔 {who} さんがいいねを取り消しました")
            return self.reply(200, {"ok": True})

        if self.path == "/block":
            blocked.add(sender)
            likes_out.discard(sender)
            likes_in.discard(sender)
            log(f"🚫 {who} さんにブロックされました")
            return self.reply(200, {"ok": True})

        if self.path == "/dm":
            if not is_match(sender):
                return self.reply(403, {"error": "not matched"})
            text = str(body.get("text", ""))[:500]
            log(f"💬 {who} さんからDM: {text}")
            threading.Thread(target=send_dm, args=(sender, f"「{text[:40]}」受け取りました！ DMは正常に動いています👍"), daemon=True).start()
            return self.reply(200, {"ok": True})

        if self.path == "/plaza":
            text = str(body.get("text", ""))[:500]
            log(f"📢 広場 {who}: {text}")
            threading.Thread(target=send_plaza_reply, args=(sender, who), daemon=True).start()
            return self.reply(200, {"ok": True})

        return self.reply(404, {"error": "not found"})


def send_dm(pid, text):
    time.sleep(REPLY_DELAY)
    try:
        post(pid, "/dm", {"from": me["id"], "id": secrets.token_hex(12), "text": text, "at": now_ms()})
        log(f"   ↳ 返信しました: {text}")
    except Exception as e:
        log(f"   ↳ 返信に失敗: {e}")


def send_plaza_reply(pid, who):
    time.sleep(REPLY_DELAY)
    try:
        post(pid, "/plaza", {"from": me["id"], "id": secrets.token_hex(12), "text": f"{who} さん、広場のメッセージ届きました👋", "at": now_ms()})
        log("   ↳ 広場に返事しました")
    except Exception as e:
        log(f"   ↳ 広場の返事に失敗: {e}")


def like_new_peer(pid):
    time.sleep(DELAY)
    if pid in likes_out or pid in blocked:
        return
    likes_out.add(pid)
    for attempt in range(6):  # 相手がまだこちらを見つけていない（409）ときは少し待って再送
        try:
            r = post(pid, "/like", {"from": me})
            if r.get("likedYou"):
                likes_in.add(pid)
            log(f"💌 {name_of(pid)} さんに自分からいいねしました" + ("（マッチ！）" if is_match(pid) else "（スマホにいいねの通知が出るはず）"))
            return
        except Exception as e:
            if attempt == 5:
                likes_out.discard(pid)
                log(f"⚠️ {name_of(pid)} さんへのいいねが届きませんでした: {e}")
            else:
                time.sleep(2)


# ---------------- UDP（発見） ----------------
def local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))  # 実際には送信しない。使われるIPを知るため
        return s.getsockname()[0]
    except Exception:
        return None
    finally:
        s.close()


def beacon_loop(udp, http_port):
    while True:
        data = json.dumps({"app": APP_TAG, "v": PROTOCOL, "port": http_port, "p": me}).encode("utf-8")
        targets = set(args.target)
        if not args.no_broadcast:
            targets.add("255.255.255.255")
            ip = local_ip()
            if ip:
                targets.add(".".join(ip.split(".")[:3] + ["255"]))
        for t in targets:
            try:
                udp.sendto(data, (t, args.send_port))
            except OSError:
                pass
        time.sleep(3)


def listen_loop(udp):
    while True:
        try:
            data, (ip, _) = udp.recvfrom(4096)
            j = json.loads(data.decode("utf-8"))
        except Exception:
            continue
        if not isinstance(j, dict) or j.get("app") != APP_TAG or j.get("v") != PROTOCOL:
            continue
        p, port = j.get("p"), j.get("port")
        if not isinstance(p, dict) or not isinstance(port, int) or p.get("id") in (None, me["id"]) or p.get("id") in blocked:
            continue
        pid = p["id"]
        with lock:
            old = peers.get(pid)
            peers[pid] = {"ip": ip, "port": port, "profile": p, "seen": time.time()}
        if old is None or time.time() - old["seen"] > 12:
            log(f"📱 発見: {p.get('emoji', '')} {p.get('name')} （{ip}）")
            threading.Thread(target=like_new_peer, args=(pid,), daemon=True).start()


def main():
    http = ThreadingHTTPServer(("0.0.0.0", 0), Handler)
    threading.Thread(target=http.serve_forever, daemon=True).start()

    udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    udp.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    udp.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    try:
        udp.bind(("0.0.0.0", args.listen_port))
    except OSError as e:
        log(f"❌ ポート {args.listen_port} を使えません: {e}")
        sys.exit(1)

    threading.Thread(target=beacon_loop, args=(udp, http.server_address[1]), daemon=True).start()
    log(f"🐼 「{me['name']}」として起動しました（このPCのIP: {local_ip() or '不明'}）")
    log("   同じWiFiのスマホで WiFi Match を開くと「みんな」に表示されます。止めるときはこの画面を閉じてください。")
    listen_loop(udp)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
