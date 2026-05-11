# Benchmarks

The benchmarks in this directory run independently from the UI/app flow and measure only the current workspace code.

## 1) Domain resolver benchmark

Measures domain parsing cost in isolation.

```bash
scripts/benchmarks/check_domain_resolver_cpu.sh
```

Customize:

```bash
scripts/benchmarks/check_domain_resolver_cpu.sh \
  --iterations 5000 \
  --warmup 500 \
  --hosts 4000 \
  --concurrency 2
```

## 2) shouldBlock end-to-end benchmark

Measures the `await AdBlockStats.shared.shouldBlock(...)` path directly with the same 4 engines used in production.

```bash
scripts/benchmarks/check_should_block_cpu.sh
```

Show available simulators and their UDIDs:

```bash
scripts/benchmarks/check_should_block_cpu.sh --list-simulators
```

Customize:

```bash
scripts/benchmarks/check_should_block_cpu.sh \
  --iterations 5000 \
  --warmup 500 \
  --hosts 4000 \
  --concurrency 2 \
  --simulator-udid <optional-udid>
```

## Output

Each run creates:
- `scripts/benchmarks/reports/<timestamp>/report.md`
- `scripts/benchmarks/reports/<timestamp>/current.env`

For the shouldBlock benchmark:
- `cold.*`: cache-miss phase using unique requests
- `warm.*`: cache-hit phase using repeated requests

## Comparing Versions

The scripts do not checkout other revisions automatically.
To compare before/after versions:
1. Checkout version A, run the script, and keep the report.
2. Checkout version B, run the same script with the same config.
3. Compare `cpu_ns_per_lookup` and `lookups_per_sec` between the two reports.

## Notes

- Run the same config 3 times and average the results to reduce noise.
- The shouldBlock benchmark requires Xcode and a working iOS Simulator.
