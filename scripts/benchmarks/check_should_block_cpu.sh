#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Check CPU benchmark for current AdBlockStats.shouldBlock path only.

Usage:
  scripts/benchmarks/check_should_block_cpu.sh [options]

Options:
  --iterations <n>      Lookups per phase (default: 3000)
  --warmup <n>          Warm-up lookups per phase (default: 300)
  --hosts <n>           Distinct hosts for warm phase (default: 2000)
  --concurrency <n>     Concurrent workers (default: 1)
  --report-dir <dir>    Output directory (default: scripts/benchmarks/reports/<timestamp>)
  --simulator-udid <id> Force running on specific simulator UDID
  --list-simulators      Show available simulators and UDID, then exit
  --help                Show help

Output:
  - current.env
  - report.md

Note:
  This script intentionally benchmarks only the current workspace code.
  Compare versions by checking out each version and running this script manually.
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

extract_kv() {
  local file="$1"
  local key="$2"
  awk -F '=' -v k="$key" '$1 == k { print $2; exit }' "$file"
}

format_number() {
  local value="$1"
  awk -v n="$value" 'BEGIN { printf "%.2f", n }'
}

format_percent() {
  local value="$1"
  awk -v n="$value" 'BEGIN { printf "%.2f%%", n * 100 }'
}

list_available_simulators() {
  local devices_output
  if ! devices_output="$(xcrun simctl list devices available 2>/dev/null)"; then
    echo "Failed to query simulators via simctl." >&2
    return 1
  fi

  echo "Available simulators (Name | UDID | Runtime):"
  printf '%s\n' "$devices_output" | awk '
    /^==/ { next }
    /^[[:space:]]*$/ { next }
    /^[[:space:]]*--/ {
      runtime = $0
      gsub(/^[[:space:]]*--[[:space:]]*/, "", runtime)
      gsub(/[[:space:]]*--[[:space:]]*$/, "", runtime)
      next
    }
    /\([[:xdigit:]-]{36}\)/ {
      line = $0
      gsub(/^[[:space:]]+/, "", line)
      udid = line
      sub(/^.*\(/, "", udid)
      sub(/\).*/, "", udid)
      name = line
      sub(/[[:space:]]*\([[:xdigit:]-]{36}\).*/, "", name)
      printf "- %s | %s | %s\n", name, udid, runtime
    }
  '
}

pick_simulator_udid() {
  local requested_udid="$1"
  if [[ -n "$requested_udid" ]]; then
    echo "$requested_udid"
    return
  fi

  local devices_output
  if ! devices_output="$(xcrun simctl list devices available 2>/dev/null)"; then
    return 1
  fi

  local line
  line="$(printf '%s\n' "$devices_output" | awk '/\(Booted\)/ {print; exit}')"
  if [[ -z "$line" ]]; then
    line="$(printf '%s\n' "$devices_output" | awk '/iPhone/ && /\([[:xdigit:]-]{36}\)/ {print; exit}')"
  fi
  if [[ -z "$line" ]]; then
    line="$(printf '%s\n' "$devices_output" | awk '/\([[:xdigit:]-]{36}\)/ {print; exit}')"
  fi

  if [[ -z "$line" ]]; then
    return 1
  fi

  echo "$line" | sed -nE 's/.*\(([[:xdigit:]-]{36})\).*/\1/p'
}

cleanup() {
  if [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}

require_cmd xcrun
require_cmd git
require_cmd awk
require_cmd sed
require_cmd uname

REPO_ROOT="$(git rev-parse --show-toplevel)"
BENCH_SWIFT="$REPO_ROOT/scripts/benchmarks/should_block_cpu_bench.swift"
SETTINGS_BUNDLE="$REPO_ROOT/apple/Settings.bundle"
LIB_XCFRAMEWORK_DIR="$REPO_ROOT/apple/libs/libadblock.xcframework/ios-arm64_x86_64-simulator"
LIB_HEADERS_DIR="$LIB_XCFRAMEWORK_DIR/Headers"
LIB_STATIC="$LIB_XCFRAMEWORK_DIR/libadblock.a"

ITERATIONS="3000"
WARMUP="300"
HOSTS="2000"
CONCURRENCY="1"
REPORT_DIR=""
SIMULATOR_UDID=""
LIST_SIMULATORS="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iterations)
      ITERATIONS="$2"
      shift 2
      ;;
    --warmup)
      WARMUP="$2"
      shift 2
      ;;
    --hosts)
      HOSTS="$2"
      shift 2
      ;;
    --concurrency)
      CONCURRENCY="$2"
      shift 2
      ;;
    --report-dir)
      REPORT_DIR="$2"
      shift 2
      ;;
    --simulator-udid)
      SIMULATOR_UDID="$2"
      shift 2
      ;;
    --list-simulators)
      LIST_SIMULATORS="1"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ "$LIST_SIMULATORS" == "1" ]]; then
  list_available_simulators
  exit 0
fi

if [[ ! -f "$BENCH_SWIFT" ]]; then
  echo "Benchmark source not found: $BENCH_SWIFT" >&2
  exit 1
fi
if [[ ! -d "$SETTINGS_BUNDLE" ]]; then
  echo "Settings bundle not found: $SETTINGS_BUNDLE" >&2
  exit 1
fi
if [[ ! -f "$LIB_STATIC" ]]; then
  echo "libadblock static library not found: $LIB_STATIC" >&2
  exit 1
fi
if [[ ! -d "$LIB_HEADERS_DIR" ]]; then
  echo "libadblock headers not found: $LIB_HEADERS_DIR" >&2
  exit 1
fi

if [[ -z "$REPORT_DIR" ]]; then
  REPORT_DIR="$REPO_ROOT/scripts/benchmarks/reports/$(date +%Y%m%d-%H%M%S)"
fi
mkdir -p "$REPORT_DIR"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/should-block-bench.XXXXXX")"
trap cleanup EXIT

BRIDGING_HEADER="$TMP_DIR/libadblock_bridge.h"
cat > "$BRIDGING_HEADER" <<'EOF'
#include <lib.h>
EOF

MODULE_CACHE="$TMP_DIR/module-cache"
mkdir -p "$MODULE_CACHE"

HOST_ARCH="$(uname -m)"
if [[ "$HOST_ARCH" == "x86_64" ]]; then
  TARGET_TRIPLE="x86_64-apple-ios14.0-simulator"
else
  TARGET_TRIPLE="arm64-apple-ios14.0-simulator"
fi

BINARY="$TMP_DIR/should_block_cpu_bench"
RUNTIME_DIR="$TMP_DIR/runtime"
RUNTIME_BINARY="$RUNTIME_DIR/should_block_cpu_bench"
RUNTIME_SETTINGS_BUNDLE="$RUNTIME_DIR/Settings.bundle"

ADBLOCK_SOURCES=(
  "$REPO_ROOT/apple/lunascape/AdBlock/SequenceExtension.swift"
  "$REPO_ROOT/apple/lunascape/AdBlock/FifoDict.swift"
  "$REPO_ROOT/apple/lunascape/AdBlock/CosmeticFilterModel.swift"
  "$REPO_ROOT/apple/lunascape/AdBlock/UserScriptType.swift"
  "$REPO_ROOT/apple/lunascape/AdBlock/ContentBlockerManager.swift"
  "$REPO_ROOT/apple/lunascape/AdBlock/URLExtension.swift"
  "$REPO_ROOT/apple/lunascape/AdBlock/AdblockRustEngine.swift"
  "$REPO_ROOT/apple/lunascape/AdBlock/CachedAdBlockEngine.swift"
  "$REPO_ROOT/apple/lunascape/AdBlock/AdBlockStats.swift"
  "$REPO_ROOT/apple/lunascape/AdBlock/DomainParser/Constant.swift"
  "$REPO_ROOT/apple/lunascape/AdBlock/DomainParser/DomainParserProtocol.swift"
  "$REPO_ROOT/apple/lunascape/AdBlock/DomainParser/ParsedHost.swift"
  "$REPO_ROOT/apple/lunascape/AdBlock/DomainParser/Model/RuleLabel.swift"
  "$REPO_ROOT/apple/lunascape/AdBlock/DomainParser/Model/Rule.swift"
  "$REPO_ROOT/apple/lunascape/AdBlock/DomainParser/RulesParser.swift"
  "$REPO_ROOT/apple/lunascape/AdBlock/DomainParser/BasicDomainParser.swift"
  "$REPO_ROOT/apple/lunascape/AdBlock/DomainParser/DomainParser.swift"
  "$REPO_ROOT/apple/lunascape/AdBlock/DomainParser/DomainResolver.swift"
)

echo "Compiling shouldBlock benchmark..."
xcrun --sdk iphonesimulator swiftc \
  -target "$TARGET_TRIPLE" \
  -O \
  -module-cache-path "$MODULE_CACHE" \
  -import-objc-header "$BRIDGING_HEADER" \
  -Xcc -I"$LIB_HEADERS_DIR" \
  "${ADBLOCK_SOURCES[@]}" \
  "$BENCH_SWIFT" \
  "$LIB_STATIC" \
  -o "$BINARY"

# DomainParser() resolves `Settings.bundle` via Bundle.main, so package the
# bundle next to runtime binary before simctl spawn.
mkdir -p "$RUNTIME_DIR"
cp "$BINARY" "$RUNTIME_BINARY"
cp -R "$SETTINGS_BUNDLE" "$RUNTIME_SETTINGS_BUNDLE"

SIMULATOR_UDID="$(pick_simulator_udid "$SIMULATOR_UDID")" || {
  echo "Could not find an available simulator. Run 'scripts/benchmarks/check_should_block_cpu.sh --list-simulators' then pass --simulator-udid." >&2
  exit 1
}

echo "Using simulator: $SIMULATOR_UDID"
xcrun simctl boot "$SIMULATOR_UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$SIMULATOR_UDID" -b >/dev/null 2>&1 || true

echo "Running benchmark on current code..."
set +e
xcrun simctl spawn "$SIMULATOR_UDID" "$RUNTIME_BINARY" \
  --iterations "$ITERATIONS" \
  --warmup "$WARMUP" \
  --hosts "$HOSTS" \
  --concurrency "$CONCURRENCY" \
  --settings-bundle "$RUNTIME_SETTINGS_BUNDLE" \
  --label "current" > "$REPORT_DIR/current.env"
spawn_exit="$?"
set -e
if [[ "$spawn_exit" -ne 0 ]]; then
  echo "Benchmark process failed (exit: $spawn_exit)." >&2
  echo "Hint: if you see 'signal 5 (Trace/BPT trap)', it is usually a runtime assert/fatalError." >&2
  echo "Make sure simulator is healthy and Settings.bundle is packaged with runtime binary." >&2
  exit "$spawn_exit"
fi

COLD_WALL_NS="$(extract_kv "$REPORT_DIR/current.env" "cold.wall_ns")"
COLD_CPU_NS="$(extract_kv "$REPORT_DIR/current.env" "cold.cpu_ns")"
COLD_NS_PER_LOOKUP="$(extract_kv "$REPORT_DIR/current.env" "cold.ns_per_lookup")"
COLD_CPU_NS_PER_LOOKUP="$(extract_kv "$REPORT_DIR/current.env" "cold.cpu_ns_per_lookup")"
COLD_LPS="$(extract_kv "$REPORT_DIR/current.env" "cold.lookups_per_sec")"
COLD_BLOCK_RATE="$(extract_kv "$REPORT_DIR/current.env" "cold.block_rate")"
COLD_CHECKSUM="$(extract_kv "$REPORT_DIR/current.env" "cold.checksum")"

WARM_WALL_NS="$(extract_kv "$REPORT_DIR/current.env" "warm.wall_ns")"
WARM_CPU_NS="$(extract_kv "$REPORT_DIR/current.env" "warm.cpu_ns")"
WARM_NS_PER_LOOKUP="$(extract_kv "$REPORT_DIR/current.env" "warm.ns_per_lookup")"
WARM_CPU_NS_PER_LOOKUP="$(extract_kv "$REPORT_DIR/current.env" "warm.cpu_ns_per_lookup")"
WARM_LPS="$(extract_kv "$REPORT_DIR/current.env" "warm.lookups_per_sec")"
WARM_BLOCK_RATE="$(extract_kv "$REPORT_DIR/current.env" "warm.block_rate")"
WARM_CHECKSUM="$(extract_kv "$REPORT_DIR/current.env" "warm.checksum")"

cat > "$REPORT_DIR/report.md" <<EOF
# AdBlockStats.shouldBlock CPU Benchmark Report

- Generated at: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
- Scope: current workspace code only
- Path: \`AdBlockStats.shared.shouldBlock(...)\`
- Engines: \`4\` (production config)
- Iterations (each phase): \`$ITERATIONS\`
- Warmup: \`$WARMUP\`
- Host set size (warm phase): \`$HOSTS\`
- Concurrency: \`$CONCURRENCY\`
- Simulator UDID: \`$SIMULATOR_UDID\`

| Phase | Wall total (ns) | CPU total (ns) | Wall / lookup (ns) | CPU / lookup (ns) | Lookups / sec | Block rate |
|---|---:|---:|---:|---:|---:|---:|
| cold | $COLD_WALL_NS | $COLD_CPU_NS | $(format_number "$COLD_NS_PER_LOOKUP") | $(format_number "$COLD_CPU_NS_PER_LOOKUP") | $(format_number "$COLD_LPS") | $(format_percent "$COLD_BLOCK_RATE") |
| warm | $WARM_WALL_NS | $WARM_CPU_NS | $(format_number "$WARM_NS_PER_LOOKUP") | $(format_number "$WARM_CPU_NS_PER_LOOKUP") | $(format_number "$WARM_LPS") | $(format_percent "$WARM_BLOCK_RATE") |

## Checksums
- cold: \`$COLD_CHECKSUM\`
- warm: \`$WARM_CHECKSUM\`

This report benchmarks only the current workspace code.
EOF

echo "Report generated:"
echo "  $REPORT_DIR/report.md"
echo "Raw data: $REPORT_DIR/current.env"
