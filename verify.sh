#!/usr/bin/env bash
#
# Boots a Dynamic Island simulator and captures every display surface.
#
#   ./verify.sh              # full run
#   ./verify.sh --keep-sim   # leave the simulator booted afterwards
#
# Output: verify/*.png
#
# Two kinds of evidence are collected:
#
#   * Real, system-rendered — the app's screens, the Live Activity in the
#     Dynamic Island (compact and long-press expanded), and the pull-down
#     Notification Center. Driven by XCUITest against SpringBoard.
#   * Host-rendered — the shipping widget views at real widget point sizes for
#     every workday phase. Adding widgets to the home screen is not scriptable
#     and the simulator clock cannot be moved, so the phase-dependent layouts
#     are rendered by the WorkdayVerify harness instead.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$ROOT/verify"
DEVICE_NAME="Workday-Verify"
DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"
APP_ID="com.liyefei.workdaywidget.ios"
VERIFY_ID="com.liyefei.workdaywidget.ios.verify"

KEEP_SIM=0
for arg in "$@"; do
  case "$arg" in
    --keep-sim) KEEP_SIM=1 ;;
  esac
done

if [[ -z "${DEVELOPER_DIR:-}" || ! -x "${DEVELOPER_DIR}/usr/bin/xcrun" ]]; then
  for candidate in \
    "/Applications/Xcode-26.3.0.app/Contents/Developer" \
    "/Applications/Xcode.app/Contents/Developer"; do
    if [[ -d "$candidate" ]]; then
      export DEVELOPER_DIR="$candidate"
      break
    fi
  done
fi

RUNTIME="$(xcrun simctl list runtimes 2>/dev/null \
  | awk '/^iOS /{print $NF}' | tail -1)"
if [[ -z "$RUNTIME" ]]; then
  cat >&2 <<'ERR'
error: 没有安装 iOS 模拟器 runtime，无法验证。安装：
  xcodebuild -downloadPlatform iOS
ERR
  exit 1
fi
echo "==> runtime: $RUNTIME"

# MARK: simulator

UDID="$(xcrun simctl list devices -j \
  | python3 -c "
import json,sys
d=json.load(sys.stdin)['devices']
for rt in d:
    for dev in d[rt]:
        if dev['name']=='$DEVICE_NAME':
            print(dev['udid']); raise SystemExit
")"

if [[ -z "$UDID" ]]; then
  echo "==> 创建模拟器 $DEVICE_NAME"
  UDID="$(xcrun simctl create "$DEVICE_NAME" "$DEVICE_TYPE" "$RUNTIME")"
fi
echo "==> device: $UDID"

if ! xcrun simctl list devices | grep -q "$UDID.*Booted"; then
  xcrun simctl boot "$UDID"
fi
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl ui "$UDID" appearance light >/dev/null 2>&1 || true

rm -rf "$OUT"
mkdir -p "$OUT"

# MARK: build

echo "==> 生成 Xcode 工程"
(cd "$ROOT" && xcodegen generate >/dev/null)

echo "==> 构建 App + Widget Extension"
xcodebuild -project "$ROOT/Workday.xcodeproj" -target Workday \
  -sdk "iphonesimulator$(xcrun --sdk iphonesimulator --show-sdk-version)" \
  -arch arm64 -configuration Debug \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO ONLY_ACTIVE_ARCH=NO \
  build >/dev/null
echo "    OK"

echo "==> 构建验证宿主"
xcodebuild -project "$ROOT/Workday.xcodeproj" -target WorkdayVerify \
  -sdk "iphonesimulator$(xcrun --sdk iphonesimulator --show-sdk-version)" \
  -arch arm64 -configuration Debug \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO ONLY_ACTIVE_ARCH=NO \
  build >/dev/null
echo "    OK"

BUILT="$ROOT/build/Debug-iphonesimulator"

# A Live Activity keeps rendering with the extension code that was loaded when
# it started, so reinstalling over a running activity shows stale layout even
# though its numbers keep updating. Uninstalling ends the activity first.
xcrun simctl uninstall "$UDID" "$APP_ID" >/dev/null 2>&1 || true
xcrun simctl uninstall "$UDID" "$VERIFY_ID" >/dev/null 2>&1 || true

xcrun simctl install "$UDID" "$BUILT/工作日.app"
xcrun simctl install "$UDID" "$BUILT/WorkdayVerify.app"

# MARK: host-rendered widget galleries

shot() { xcrun simctl io "$UDID" screenshot --type=png "$OUT/$1" >/dev/null; }

SCENARIOS=(before-work morning lunch afternoon dinner last-stretch overtime weekend)

echo "==> 渲染小组件各尺寸 × 各阶段"
i=0
for s in "${SCENARIOS[@]}"; do
  i=$((i + 1))
  n=$(printf "%02d" "$i")
  xcrun simctl terminate "$UDID" "$VERIFY_ID" >/dev/null 2>&1 || true
  xcrun simctl launch "$UDID" "$VERIFY_ID" -scenario "$s" -page widgets >/dev/null
  sleep 2.5
  shot "widgets-$n-$s.png"
  echo "    widgets-$n-$s.png"
done

echo "==> 渲染 Live Activity 卡片 × 各阶段"
i=0
for s in "${SCENARIOS[@]}"; do
  i=$((i + 1))
  n=$(printf "%02d" "$i")
  xcrun simctl terminate "$UDID" "$VERIFY_ID" >/dev/null 2>&1 || true
  xcrun simctl launch "$UDID" "$VERIFY_ID" -scenario "$s" -page activity >/dev/null
  sleep 2.5
  shot "card-$n-$s.png"
  echo "    card-$n-$s.png"
done
xcrun simctl terminate "$UDID" "$VERIFY_ID" >/dev/null 2>&1 || true

# MARK: system-rendered surfaces

echo "==> 驱动真实界面（灵动岛 / 通知中心 / App 页面）"
RESULT="$ROOT/build/verify.xcresult"
rm -rf "$RESULT"

# `xcodebuild test` builds and runs in one step. Using test-without-building
# here would reinstall the app recorded in a previously generated .xctestrun,
# which can predate the current sources — the test then screenshots a stale
# build while reporting success.
set +e
xcodebuild test \
  -project "$ROOT/Workday.xcodeproj" \
  -scheme Workday \
  -destination "id=$UDID" \
  -derivedDataPath "$ROOT/build/dd" \
  -resultBundlePath "$RESULT" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  >"$OUT/uitest.log" 2>&1
UITEST_RC=$?
set -e

if [[ $UITEST_RC -eq 0 ]]; then
  echo "    UI 测试通过"
else
  echo "    !! UI 测试未通过 (exit $UITEST_RC)，日志: verify/uitest.log" >&2
fi

if [[ -d "$RESULT" ]]; then
  echo "==> 导出截图附件"
  xcrun xcresulttool export attachments \
    --path "$RESULT" --output-path "$OUT/attachments" >/dev/null 2>&1 || true
  if [[ -d "$OUT/attachments" ]]; then
    # Attachments land under a manifest-indexed directory with generated file
    # names; restore the names the test assigned. Those carry an
    # `_<index>_<uuid>` suffix that has to come off.
    python3 - "$OUT/attachments" "$OUT" <<'PY'
import json, pathlib, re, shutil, sys
src, dst = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
manifest = src / "manifest.json"
suffix = re.compile(r"_\d+_[0-9A-Fa-f-]{36}$")
if manifest.exists():
    for test in json.loads(manifest.read_text()):
        for att in test.get("attachments", []):
            name = att.get("suggestedHumanReadableName") or att.get("exportedFileName")
            exported = src / att["exportedFileName"]
            if not (exported.exists() and name):
                continue
            stem = suffix.sub("", pathlib.Path(name).stem)
            shutil.copy(exported, dst / f"{stem}.png")
            print(f"    {stem}.png")
PY
  fi
fi

if [[ "$KEEP_SIM" == "0" ]]; then
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
  echo "==> 模拟器已关闭（--keep-sim 可保留）"
fi

echo
echo "==> 截图输出: $OUT"
ls -1 "$OUT"/*.png 2>/dev/null | sed 's|.*/|    |'
