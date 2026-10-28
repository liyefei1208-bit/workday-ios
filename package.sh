#!/usr/bin/env bash
#
#   ./package.sh            # unsigned device .ipa + simulator .zip
#   ./package.sh --sim-only # simulator .zip only
#
# Produces, under dist/:
#
#   工作日-<version>-unsigned.ipa   arm64 device build. NOT signed — it has to be
#                                   re-signed with your own certificate before a
#                                   phone will install it (see README).
#   工作日-<version>-simulator.zip  For the iOS Simulator only: unzip, then
#                                   `xcrun simctl install booted 工作日.app`.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST="$ROOT/dist"
VERSION="$(grep -E '^\s*MARKETING_VERSION:' "$ROOT/project.yml" | sed 's/.*"\(.*\)".*/\1/')"
NAME="工作日-$VERSION"

SIM_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --sim-only) SIM_ONLY=1 ;;
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

echo "==> 生成 Xcode 工程"
(cd "$ROOT" && xcodegen generate >/dev/null)

rm -rf "$DIST"
mkdir -p "$DIST"

# MARK: simulator build

echo "==> 构建模拟器版"
SIM_SDK="$(xcrun --sdk iphonesimulator --show-sdk-version)"
(cd "$ROOT" && xcodebuild \
  -project Workday.xcodeproj -target Workday \
  -sdk "iphonesimulator$SIM_SDK" -arch arm64 -configuration Release \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO ONLY_ACTIVE_ARCH=NO \
  build >/dev/null)

SIM_APP="$ROOT/build/Release-iphonesimulator/工作日.app"
[[ -d "$SIM_APP" ]] || { echo "error: 模拟器构建产物缺失" >&2; exit 1; }

(cd "$(dirname "$SIM_APP")" && zip -qry "$DIST/$NAME-simulator.zip" "工作日.app")
echo "    $DIST/$NAME-simulator.zip"

if [[ "$SIM_ONLY" == "1" ]]; then
  echo "==> 完成（仅模拟器版）"
  exit 0
fi

# MARK: device build

echo "==> 构建真机版（arm64，未签名）"
DEV_SDK="$(xcrun --sdk iphoneos --show-sdk-version)"
(cd "$ROOT" && xcodebuild \
  -project Workday.xcodeproj -target Workday \
  -sdk "iphoneos$DEV_SDK" -arch arm64 -configuration Release \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO ONLY_ACTIVE_ARCH=NO \
  build >/dev/null)

DEV_APP="$ROOT/build/Release-iphoneos/工作日.app"
[[ -d "$DEV_APP" ]] || { echo "error: 真机构建产物缺失" >&2; exit 1; }

STAGE="$(mktemp -d)"
mkdir -p "$STAGE/Payload"
cp -R "$DEV_APP" "$STAGE/Payload/"
(cd "$STAGE" && zip -qry "$DIST/$NAME-unsigned.ipa" Payload)
rm -rf "$STAGE"
echo "    $DIST/$NAME-unsigned.ipa"

# MARK: verify

echo "==> 校验"
fail=0
check() { # description, path, expected
  if [[ -e "$2" ]]; then
    echo "    ok   $1"
  else
    echo "    FAIL $1 ($2)" >&2
    fail=1
  fi
}

for app in "$SIM_APP" "$DEV_APP"; do
  label="$(basename "$(dirname "$app")")"
  check "$label 可执行文件"      "$app/工作日"
  check "$label 图标资源 Assets.car" "$app/Assets.car"
  check "$label Widget Extension" "$app/PlugIns/WorkdayWidgetExtension.appex/WorkdayWidgetExtension"
done

# The device slice must be a real arm64 Mach-O, not the simulator one.
if file "$DEV_APP/工作日" | grep -q "Mach-O 64-bit executable arm64"; then
  echo "    ok   真机二进制架构 arm64"
else
  echo "    FAIL 真机二进制架构异常: $(file "$DEV_APP/工作日")" >&2
  fail=1
fi

# An unsigned .ipa has no embedded provisioning profile; say so rather than
# letting it look like a warning-free, installable package.
if [[ -e "$DEV_APP/embedded.mobileprovision" ]]; then
  echo "    !! 意外发现 embedded.mobileprovision" >&2
else
  echo "    note 未签名：需用你自己的证书重签后才能装真机"
fi

[[ "$fail" == "0" ]] || exit 1

cat > "$DIST/安装说明.txt" <<NOTE
工作日 iOS $VERSION
作者 yefei.li · © 2026 yefei.li

本目录两个包用途不同。

────────────────────────────────────────────
1. $NAME-unsigned.ipa   装真机
────────────────────────────────────────────
这是 arm64 真机包，但【没有签名】。iOS 只允许安装
签名后的 App，所以它不能直接双击安装，必须先用自己的
证书重签。任选一种方式：

  A. Xcode（推荐）
     ./build.sh --open
     在 Xcode 里给 Workday 和 WorkdayWidgetExtension
     两个 target 选 Team，然后 Cmd+R 装到设备。

  B. 重新签名现有 ipa
     用 Xcode、Sideloadly、AltStore 等工具，选中本 ipa
     和你的证书重新签一次。

注意：两个 target 都需要 App Groups 能力
  group.com.liyefei.workdaywidget
没有这个共享容器，小组件读不到 App 里改过的排班，
只会用默认值。

────────────────────────────────────────────
2. $NAME-simulator.zip   装模拟器
────────────────────────────────────────────
只能装在 iOS 模拟器里，不能装真机。

  unzip $NAME-simulator.zip
  xcrun simctl install booted 工作日.app
  xcrun simctl launch booted com.liyefei.workdaywidget.ios

或者直接把 unzip 出来的 工作日.app 拖进模拟器窗口。
NOTE

echo
echo "==> 产物: $DIST"
ls -lh "$DIST" | tail -n +2 | awk '{print "    "$9"  "$5}'
