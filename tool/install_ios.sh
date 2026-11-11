#!/bin/zsh
# บิลด์ iOS แบบ release แล้วลง iPhone ที่เสียบอยู่
# ใช้จากโฟลเดอร์โปรเจกต์: tool/install_ios.sh
# เลือกเครื่องเอง: DEVICE_UDID=... tool/install_ios.sh
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

if [[ -x "$root/.fvm/flutter_sdk/bin/flutter" ]]; then
  flutter_bin=("$root/.fvm/flutter_sdk/bin/flutter")
elif command -v fvm >/dev/null 2>&1; then
  flutter_bin=(fvm flutter)
elif [[ -x /Users/skyline/fvm/versions/3.38.7/bin/flutter ]]; then
  flutter_bin=(/Users/skyline/fvm/versions/3.38.7/bin/flutter)
else
  echo "ไม่พบ Flutter 3.38.7" >&2
  exit 1
fi

pick_device() {
  local json
  json=$(mktemp)
  xcrun devicectl list devices --json-output "$json" >/dev/null
  python3 - "$json" "${DEVICE_UDID:-}" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1]))
wanted = sys.argv[2]
phones = []
for device in data["result"]["devices"]:
    props = device.get("properties") or {}
    hardware = props.get("hardware") or {}
    if hardware.get("reality") != "physical":
        continue
    if hardware.get("deviceType") != "iPhone":
        continue
    connection = props.get("connection") or {}
    state = props.get("state") or {}
    phones.append(
        {
            "udid": hardware.get("udid") or device.get("identifier"),
            "name": state.get("name") or "iPhone",
            "connected": connection.get("state") == "connected",
        }
    )

if wanted:
    phones = [phone for phone in phones if phone["udid"] == wanted]
    if not phones:
        sys.exit(f"ไม่พบ iPhone ตาม DEVICE_UDID {wanted}")

if not phones:
    sys.exit("ไม่พบ iPhone จริงที่จับคู่กับ Mac เครื่องนี้")
if len(phones) > 1 and not wanted:
    names = ", ".join(phone["name"] for phone in phones)
    sys.exit(f"มี iPhone หลายเครื่อง ({names}) ใส่ DEVICE_UDID ตอนรัน")

phone = phones[0]
if not phone["connected"]:
    sys.exit(
        f"{phone['name']} ยังไม่ได้เชื่อมต่อ เสียบสาย ปลดล็อกเครื่อง แล้วกด Trust This Computer"
    )
print(f"{phone['udid']}\t{phone['name']}")
PY
  rm -f "$json"
}

resign_app() {
  local app="$1"
  local identity entitlements
  identity=$(codesign -dv "$app" 2>&1 | sed -n 's/^Authority=//p' | head -1)
  if [[ -z "$identity" ]]; then
    identity=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' | head -1)
  fi
  if [[ -z "$identity" ]]; then
    echo "ไม่พบใบรับรอง Apple Development ในพวงกุญแจ" >&2
    exit 1
  fi
  entitlements=$(mktemp)
  codesign -d --entitlements :- "$app" >"$entitlements" 2>/dev/null || true
  python3 - "$entitlements" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
data = path.read_bytes()
start = data.find(b"<?xml")
if start < 0:
    sys.exit("ไม่พบ entitlements ของแอป")
path.write_bytes(data[start:])
PY
  codesign --force --sign "$identity" --entitlements "$entitlements" --timestamp=none "$app"
  rm -f "$entitlements"
  codesign --verify --strict "$app"
}

strip_simulator_sqlite() {
  local app="$1"
  local framework="$app/Frameworks/sqlite3.framework"
  if [[ ! -d "$framework" ]]; then
    return 0
  fi
  echo "เอา sqlite3.framework ออกจากแอปเครื่องจริง แอปใช้ SQLite ของระบบ"
  rm -rf "$framework"
  resign_app "$app"
}

device_line=$(pick_device)
udid=${device_line%%$'\t'*}
name=${device_line#*$'\t'}
echo "จะลงที่ $name"

if [[ ! -f "$root/.env" ]]; then
  echo "ไม่พบ .env จึงบิลด์แอปที่ต่อฐานข้อมูลไม่ได้" >&2
  exit 1
fi

echo "กำลังบิลด์ iOS release"
"${flutter_bin[@]}" build ios --release --dart-define-from-file=.env

app="$root/build/ios/iphoneos/Runner.app"
if [[ ! -d "$app" ]]; then
  echo "ไม่พบ $app" >&2
  exit 1
fi
strip_simulator_sqlite "$app"

bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Info.plist")
echo "กำลังติดตั้ง $bundle_id"
xcrun devicectl device install app --device "$udid" "$app"
echo "กำลังเปิดแอป"
xcrun devicectl device process launch --device "$udid" "$bundle_id"
echo "ลงเครื่องและเปิดแอปแล้ว"
