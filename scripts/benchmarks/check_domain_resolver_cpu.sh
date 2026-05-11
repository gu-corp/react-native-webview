#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Check CPU benchmark for current domain resolver code only.

Usage:
  scripts/benchmarks/check_domain_resolver_cpu.sh [options]

Options:
  --iterations <n>     Lookup iterations per run (default: 3000)
  --warmup <n>         Warm-up iterations (default: 300)
  --hosts <n>          Number of generated hosts (default: 2000)
  --concurrency <n>    Parallel workers (default: 1)
  --report-dir <dir>   Output directory (default: scripts/benchmarks/reports/<timestamp>)
  --help               Show this help

Output:
  - current.env
  - report.md

Note:
  This script intentionally benchmarks only the current workspace code.
  To benchmark old code, run separate steps manually.
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

cleanup() {
  if [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}

require_cmd git
require_cmd xcrun
require_cmd awk

REPO_ROOT="$(git rev-parse --show-toplevel)"
BENCH_SWIFT="$REPO_ROOT/scripts/benchmarks/domain_resolver_cpu_bench.swift"
DOMAIN_PARSER_DIR="$REPO_ROOT/apple/lunascape/AdBlock/DomainParser"
PSL_FILE="$REPO_ROOT/apple/Settings.bundle/AdblockResources/public_suffix_list.dat"

if [[ ! -f "$BENCH_SWIFT" ]]; then
  echo "Benchmark source not found: $BENCH_SWIFT" >&2
  exit 1
fi

if [[ ! -f "$PSL_FILE" ]]; then
  echo "PSL file not found: $PSL_FILE" >&2
  exit 1
fi

ITERATIONS="3000"
WARMUP="300"
HOSTS="2000"
CONCURRENCY="1"
REPORT_DIR=""

export LANG=C
export LC_ALL=C

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

if [[ -z "$REPORT_DIR" ]]; then
  REPORT_DIR="$REPO_ROOT/scripts/benchmarks/reports/$(date +%Y%m%d-%H%M%S)"
fi

mkdir -p "$REPORT_DIR"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/domain-resolver-bench.XXXXXX")"
trap cleanup EXIT

BINARY="$TMP_DIR/domain_resolver_cpu_bench"
MODULE_CACHE="$TMP_DIR/module-cache"

mkdir -p "$MODULE_CACHE"

echo "Compiling benchmark against current workspace code..."
xcrun swiftc -O \
  -module-cache-path "$MODULE_CACHE" \
  "$DOMAIN_PARSER_DIR/Constant.swift" \
  "$DOMAIN_PARSER_DIR/DomainParserProtocol.swift" \
  "$DOMAIN_PARSER_DIR/ParsedHost.swift" \
  "$DOMAIN_PARSER_DIR/Model/RuleLabel.swift" \
  "$DOMAIN_PARSER_DIR/Model/Rule.swift" \
  "$DOMAIN_PARSER_DIR/RulesParser.swift" \
  "$DOMAIN_PARSER_DIR/BasicDomainParser.swift" \
  "$DOMAIN_PARSER_DIR/DomainParser.swift" \
  "$BENCH_SWIFT" \
  -o "$BINARY"

echo "Running benchmark on current code..."
"$BINARY" \
  --mode shared \
  --psl-file "$PSL_FILE" \
  --iterations "$ITERATIONS" \
  --warmup "$WARMUP" \
  --hosts "$HOSTS" \
  --concurrency "$CONCURRENCY" \
  --label "current" > "$REPORT_DIR/current.env"

WALL_NS="$(extract_kv "$REPORT_DIR/current.env" "wall_ns")"
CPU_NS="$(extract_kv "$REPORT_DIR/current.env" "cpu_ns")"
NS_PER_LOOKUP="$(extract_kv "$REPORT_DIR/current.env" "ns_per_lookup")"
CPU_NS_PER_LOOKUP="$(extract_kv "$REPORT_DIR/current.env" "cpu_ns_per_lookup")"
LPS="$(extract_kv "$REPORT_DIR/current.env" "lookups_per_sec")"

cat > "$REPORT_DIR/report.md" <<EOF
# Domain Resolver CPU Benchmark Report

- Generated at: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
- Mode: \`shared\`
- Iterations: \`$ITERATIONS\`
- Warmup: \`$WARMUP\`
- Host set size: \`$HOSTS\`
- Concurrency: \`$CONCURRENCY\`

| Metric | Value |
|---|---:|
| Wall time total (ns) | $WALL_NS |
| CPU time total (ns) | $CPU_NS |
| Wall time per lookup (ns) | $(format_number "$NS_PER_LOOKUP") |
| CPU time per lookup (ns) | $(format_number "$CPU_NS_PER_LOOKUP") |
| Lookups per second | $(format_number "$LPS") |

This report benchmarks only the current workspace code.
EOF

echo "Report generated:"
echo "  $REPORT_DIR/report.md"
echo "Raw data: $REPORT_DIR/current.env"
