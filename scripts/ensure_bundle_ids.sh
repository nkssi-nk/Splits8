#!/usr/bin/env bash
# 애플 개발자 사이트에 번들 ID(아이폰 앱, 워치 앱, 위젯 2개)를 만들고 기능을 켠다.
# 앱 · 워치: HealthKit (+ 앱은 Sign in with Apple) / 넷 모두: App Groups (빌드 22 — 위젯이 앱의 요약을 읽음).
# 이미 있으면 그대로 두고 기능만 확인한다. 여러 번 실행해도 안전하다.
# 주의: App Group(group.com.nkssi.splits8) 자체를 만들고 네 번들 ID 에 연결하는 것은 API 로 안 되어
#       개발자 사이트(Certificates, Identifiers & Profiles)에서 한 번 손으로 해야 함.
set -euo pipefail

BUNDLE_ID=$(grep -E '^[[:space:]]+APP_BUNDLE_ID:' project.yml | awk '{print $2}')
echo "번들 ID: $BUNDLE_ID"

get_id() {
  python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    print(""); sys.exit()
if isinstance(d, list):
    print(d[0]["id"] if d else "")
elif isinstance(d, dict):
    print(d.get("id", ""))
'
}

# 기능 켜기 (설정값이 필요 없는 것): enable_cap <번들 리소스 id> <APP_GROUPS 등>
enable_cap() {
  BUNDLE_RID="$1" CAP="$2" python3 - <<'PY'
import os, time, json, urllib.request, urllib.error
import jwt
key = os.environ["APP_STORE_CONNECT_PRIVATE_KEY"]
now = int(time.time())
tok = jwt.encode({"iss": os.environ["APP_STORE_CONNECT_ISSUER_ID"], "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"},
                 key, algorithm="ES256", headers={"kid": os.environ["APP_STORE_CONNECT_KEY_IDENTIFIER"], "typ": "JWT"})
body = {"data": {"type": "bundleIdCapabilities",
                 "attributes": {"capabilityType": os.environ["CAP"]},
                 "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": os.environ["BUNDLE_RID"]}}}}}
req = urllib.request.Request("https://api.appstoreconnect.apple.com/v1/bundleIdCapabilities",
                             data=json.dumps(body).encode(), method="POST",
                             headers={"Authorization": "Bearer " + tok, "Content-Type": "application/json"})
try:
    urllib.request.urlopen(req)
    print("   " + os.environ["CAP"] + " 켜짐")
except urllib.error.HTTPError as e:
    print("   " + os.environ["CAP"] + " 실패:", e.code, e.read().decode()[:300])
PY
}

for pair in "$BUNDLE_ID|Splits8" "$BUNDLE_ID.watchkitapp|Splits8 Watch" "$BUNDLE_ID.widgets|Splits8 Widgets" "$BUNDLE_ID.watchkitapp.widgets|Splits8 Watch Widgets"; do
  ID="${pair%%|*}"
  NAME="${pair##*|}"
  RID=$(app-store-connect bundle-ids list --bundle-id-identifier "$ID" --strict-match-identifier --json 2>/dev/null | get_id || true)
  if [ -z "$RID" ]; then
    echo "→ $ID 새로 만듭니다"
    RID=$(app-store-connect bundle-ids create "$ID" --name "$NAME" --platform IOS --json | get_id)
  else
    echo "→ $ID 이미 있습니다"
  fi
  CAPS=$(app-store-connect bundle-ids capabilities "$RID" --json 2>/dev/null || true)
  if [ "$ID" = "$BUNDLE_ID" ] || [ "$ID" = "$BUNDLE_ID.watchkitapp" ]; then
    echo "   HealthKit 켜기"
    if echo "$CAPS" | grep -qi "HEALTHKIT"; then
      echo "   (이미 켜져 있음)"
    else
      app-store-connect bundle-ids enable-capabilities "$RID" --capability HealthKit
    fi
  fi
  echo "   App Groups 켜기"
  if echo "$CAPS" | grep -qi "APP_GROUPS"; then
    echo "   (이미 켜져 있음)"
  else
    enable_cap "$RID" APP_GROUPS
  fi
  if [ "$ID" = "$BUNDLE_ID" ]; then
    echo "   Sign in with Apple 켜기"
    if app-store-connect bundle-ids capabilities "$RID" --json 2>/dev/null | grep -qi "APPLE_ID_AUTH"; then
      echo "   (이미 켜져 있음)"
    else
      # Sign in with Apple 은 설정(기본 앱)을 함께 보내야 해서 API 를 직접 부른다
      BUNDLE_RID="$RID" python3 - <<'PY'
import os, time, json, urllib.request, urllib.error
import jwt
key = os.environ["APP_STORE_CONNECT_PRIVATE_KEY"]
now = int(time.time())
tok = jwt.encode({"iss": os.environ["APP_STORE_CONNECT_ISSUER_ID"], "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"},
                 key, algorithm="ES256", headers={"kid": os.environ["APP_STORE_CONNECT_KEY_IDENTIFIER"], "typ": "JWT"})
body = {"data": {"type": "bundleIdCapabilities",
                 "attributes": {"capabilityType": "APPLE_ID_AUTH",
                                "settings": [{"key": "APPLE_ID_AUTH_APP_CONSENT", "options": [{"key": "PRIMARY_APP_CONSENT"}]}]},
                 "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": os.environ["BUNDLE_RID"]}}}}}
req = urllib.request.Request("https://api.appstoreconnect.apple.com/v1/bundleIdCapabilities",
                             data=json.dumps(body).encode(), method="POST",
                             headers={"Authorization": "Bearer " + tok, "Content-Type": "application/json"})
try:
    urllib.request.urlopen(req)
    print("   Sign in with Apple 켜짐")
except urllib.error.HTTPError as e:
    print("   실패:", e.code, e.read().decode()[:400])
    raise SystemExit(1)
PY
    fi
  fi
done
