#!/usr/bin/env bash
#
#   ./build.sh            # generate project + build (simulator SDK)
#   ./build.sh --icon     # also re-render the app icon
#   ./build.sh --open     # generate project and open it in Xcode
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ICON="$ROOT/App/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

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

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: 需要 xcodegen。安装：brew install xcodegen" >&2
  exit 1
fi

WANT_ICON=0
WANT_OPEN=0
for arg in "$@"; do
  case "$arg" in
    --icon) WANT_ICON=1 ;;
    --open) WANT_OPEN=1 ;;
  esac
done

# The icon renderer runs on macOS (see Tools/MakeIcon.swift) and only needs to
# re-run when the artwork changes.
if [[ ! -f "$ICON" || "$WANT_ICON" == "1" ]]; then
  echo "==> 渲染应用图标"
  TOOL="$(mktemp -d)/make-icon"
  xcrun swiftc -swift-version 5 -O -o "$TOOL" "$ROOT/Tools/MakeIcon.swift"
  "$TOOL" "$ICON"
  rm -rf "$(dirname "$TOOL")"
fi

echo "==> 生成 Xcode 工程"
(cd "$ROOT" && xcodegen generate)

if [[ "$WANT_OPEN" == "1" ]]; then
  open "$ROOT/Workday.xcodeproj"
  echo "==> 已在 Xcode 中打开。记得在 Signing & Capabilities 里选择你的 Team。"
  exit 0
fi

# Simulator runtimes are not required to compile. Building the target directly
# avoids xcodebuild's destination lookup, which needs an installed runtime.
SDK="$(xcrun --sdk iphonesimulator --show-sdk-version 2>/dev/null || echo "")"
if [[ -z "$SDK" ]]; then
  echo "error: 找不到 iOS Simulator SDK，请在 Xcode 中安装 iOS 平台支持。" >&2
  exit 1
fi

# Simulator runtimes are not required to compile Swift, but `actool` refuses to
# compile an asset catalog when none is installed. Detect that and say so
# instead of failing with an opaque error.
HAS_RUNTIME=0
if xcrun simctl list runtimes 2>/dev/null | grep -qi "iOS"; then
  HAS_RUNTIME=1
fi

ICON_ARGS=()
if [[ "$HAS_RUNTIME" == "0" ]]; then
  cat >&2 <<'WARN'

!! 本机未安装任何 iOS 模拟器 runtime。
   Swift 代码会照常编译，但应用图标（Assets.xcassets）会被跳过 ——
   actool 在没有 runtime 时拒绝编译资源目录。

   安装 runtime 后即可生成完整带图标的包：
     xcodebuild -downloadPlatform iOS
   或在 Xcode → Settings → Components 里安装 iOS 平台支持。

WARN
  ICON_ARGS=(
    EXCLUDED_SOURCE_FILE_NAMES="Assets.xcassets"
    ASSETCATALOG_COMPILER_APPICON_NAME=""
  )
fi

echo "==> 编译 (iphonesimulator$SDK)"
(cd "$ROOT" && xcodebuild \
  -project Workday.xcodeproj \
  -target Workday \
  -sdk "iphonesimulator$SDK" \
  -arch arm64 \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  ONLY_ACTIVE_ARCH=NO \
  ${ICON_ARGS[@]+"${ICON_ARGS[@]}"} \
  build | tail -3)

echo "==> 构建完成: $ROOT/build/Debug-iphonesimulator/工作日.app"
if [[ "$HAS_RUNTIME" == "0" ]]; then
  echo "    (未包含应用图标，原因见上方提示)"
fi
echo
echo "要装到真机：./build.sh --open，在 Xcode 里选 Team 后 Cmd+R。"
