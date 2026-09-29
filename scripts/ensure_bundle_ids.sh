#!/usr/bin/env bash
# 애플 개발자 사이트에 번들 ID(아이폰 앱, 워치 앱)를 만들고 HealthKit 기능을 켠다.
# 이미 있으면 그대로 두고 HealthKit만 확인한다. 여러 번 실행해도 안전하다.
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

for pair in "$BUNDLE_ID|Splits8" "$BUNDLE_ID.watchkitapp|Splits8 Watch"; do
  ID="${pair%%|*}"
  NAME="${pair##*|}"
  RID=$(app-store-connect bundle-ids list --bundle-id-identifier "$ID" --strict-match-identifier --json 2>/dev/null | get_id || true)
  if [ -z "$RID" ]; then
    echo "→ $ID 새로 만듭니다"
    RID=$(app-store-connect bundle-ids create "$ID" --name "$NAME" --platform IOS --json | get_id)
  else
    echo "→ $ID 이미 있습니다"
  fi
  echo "   HealthKit 켜기"
  if app-store-connect bundle-ids capabilities "$RID" --json 2>/dev/null | grep -qi "HEALTHKIT"; then
    echo "   (이미 켜져 있음)"
  else
    app-store-connect bundle-ids enable-capabilities "$RID" --capability HealthKit
  fi
  if [ "$ID" = "$BUNDLE_ID" ]; then
    echo "   Sign in with Apple 켜기"
    if app-store-connect bundle-ids capabilities "$RID" --json 2>/dev/null | grep -qi "APPLE_ID_AUTH"; then
      echo "   (이미 켜져 있음)"
    else
      app-store-connect bundle-ids enable-capabilities "$RID" --capability "Sign In with Apple"
    fi
  fi
done
