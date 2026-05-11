import Foundation
import Dispatch

enum BenchmarkMode: String {
    case legacy
    case shared
}

struct Config {
    var mode: BenchmarkMode = .legacy
    var iterations: Int = 3_000
    var warmup: Int = 300
    var hostCount: Int = 2_000
    var concurrency: Int = 1
    var pslFilePath: String = ""
    var label: String = "run"
}

protocol BaseDomainResolving {
    func baseDomain(for host: String) -> String?
}

final class LegacyPerCallResolver: BaseDomainResolving {
    private let rulesData: Data

    init(rulesData: Data) {
        self.rulesData = rulesData
    }

    func baseDomain(for host: String) -> String? {
        guard let parser = try? DomainParser(rulesData: rulesData, quickParsing: false, sortRules: false) else {
            return nil
        }
        return parser.parse(host: host)?.domain
    }
}

final class SharedParserResolver: BaseDomainResolving {
    private let lock = NSLock()
    private let parser: DomainParser?

    init(rulesData: Data) {
        parser = try? DomainParser(rulesData: rulesData, quickParsing: false, sortRules: false)
    }

    func baseDomain(for host: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return parser?.parse(host: host)?.domain
    }
}

@inline(never)
func consume(_ string: String?) -> Int {
    guard let string else { return 0 }
    return string.utf8.count
}

func processCPUTimeNanos() -> UInt64 {
    var ts = timespec()
    clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &ts)
    return UInt64(ts.tv_sec) * 1_000_000_000 + UInt64(ts.tv_nsec)
}

func generateHosts(count: Int) -> [String] {
    let prefixes = ["www", "m", "cdn", "img", "api", "ads", "static", "news", "media", "shop"]
    let labels = [
        "alpha", "beta", "gamma", "delta", "omega", "luna", "nova", "terra", "orbit", "nexus",
        "zen", "peak", "stream", "flux", "spark", "pulse", "logic", "drift", "pixel", "forge"
    ]
    let suffixes = [
        "com", "org", "net", "io", "app", "dev", "co.uk", "co.jp", "jp", "de",
        "fr", "co.in", "in", "vn", "com.vn", "xyz", "online", "info", "me", "us"
    ]

    var hosts = [String]()
    hosts.reserveCapacity(max(count, 1))

    if count <= 0 {
        return ["www.example.com"]
    }

    for i in 0..<count {
        let p = prefixes[i % prefixes.count]
        let l1 = labels[(i * 7 + 3) % labels.count]
        let l2 = labels[(i * 11 + 5) % labels.count]
        let suffix = suffixes[(i * 13 + 1) % suffixes.count]
        hosts.append("\(p).\(l1)-\(l2).\(suffix)")
    }
    return hosts
}

func runLookups(
    resolver: BaseDomainResolving,
    hosts: [String],
    iterations: Int,
    concurrency: Int
) -> Int {
    if concurrency <= 1 {
        var checksum = 0
        for i in 0..<iterations {
            checksum &+= consume(resolver.baseDomain(for: hosts[i % hosts.count]))
        }
        return checksum
    }

    var partial = [Int](repeating: 0, count: concurrency)
    let base = iterations / concurrency
    let remainder = iterations % concurrency

    DispatchQueue.concurrentPerform(iterations: concurrency) { worker in
        let start = worker * base + min(worker, remainder)
        let length = base + (worker < remainder ? 1 : 0)
        var localChecksum = 0

        if length > 0 {
            for i in 0..<length {
                let globalIndex = start + i
                localChecksum &+= consume(resolver.baseDomain(for: hosts[globalIndex % hosts.count]))
            }
        }

        partial[worker] = localChecksum
    }

    return partial.reduce(0, &+)
}

func parseArgs() throws -> Config {
    var config = Config()
    var index = 1
    let args = CommandLine.arguments

    while index < args.count {
        let arg = args[index]

        func requireValue(_ name: String) throws -> String {
            let next = index + 1
            guard next < args.count else {
                throw NSError(domain: "bench", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing value for \(name)"])
            }
            index = next
            return args[next]
        }

        switch arg {
        case "--mode":
            let value = try requireValue("--mode")
            guard let mode = BenchmarkMode(rawValue: value) else {
                throw NSError(domain: "bench", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid --mode. Use legacy|shared"])
            }
            config.mode = mode
        case "--iterations":
            config.iterations = Int(try requireValue("--iterations")) ?? config.iterations
        case "--warmup":
            config.warmup = Int(try requireValue("--warmup")) ?? config.warmup
        case "--hosts":
            config.hostCount = Int(try requireValue("--hosts")) ?? config.hostCount
        case "--concurrency":
            config.concurrency = Int(try requireValue("--concurrency")) ?? config.concurrency
        case "--psl-file":
            config.pslFilePath = try requireValue("--psl-file")
        case "--label":
            config.label = try requireValue("--label")
        case "--help", "-h":
            print(
                """
                Usage:
                  domain_resolver_cpu_bench --mode legacy|shared --psl-file <path> [options]

                Options:
                  --iterations <n>   Lookup iterations (default: 3000)
                  --warmup <n>       Warm-up iterations (default: 300)
                  --hosts <n>        Distinct generated hosts (default: 2000)
                  --concurrency <n>  Parallel workers (default: 1)
                  --label <text>     Label written to output
                """
            )
            exit(0)
        default:
            throw NSError(domain: "bench", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown argument: \(arg)"])
        }

        index += 1
    }

    guard !config.pslFilePath.isEmpty else {
        throw NSError(domain: "bench", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing required --psl-file"])
    }
    config.iterations = max(config.iterations, 1)
    config.warmup = max(config.warmup, 0)
    config.hostCount = max(config.hostCount, 1)
    config.concurrency = max(config.concurrency, 1)
    return config
}

func makeResolver(mode: BenchmarkMode, rulesData: Data) -> BaseDomainResolving {
    switch mode {
    case .legacy:
        return LegacyPerCallResolver(rulesData: rulesData)
    case .shared:
        return SharedParserResolver(rulesData: rulesData)
    }
}

@main
struct Main {
    static func main() {
        do {
            let config = try parseArgs()
            let rulesData = try Data(contentsOf: URL(fileURLWithPath: config.pslFilePath))
            let hosts = generateHosts(count: config.hostCount)
            let resolver = makeResolver(mode: config.mode, rulesData: rulesData)

            _ = runLookups(
                resolver: resolver,
                hosts: hosts,
                iterations: config.warmup,
                concurrency: config.concurrency
            )

            let wallStart = DispatchTime.now().uptimeNanoseconds
            let cpuStart = processCPUTimeNanos()
            let checksum = runLookups(
                resolver: resolver,
                hosts: hosts,
                iterations: config.iterations,
                concurrency: config.concurrency
            )
            let cpuEnd = processCPUTimeNanos()
            let wallEnd = DispatchTime.now().uptimeNanoseconds

            let wallNanos = wallEnd &- wallStart
            let cpuNanos = cpuEnd &- cpuStart
            let nsPerLookup = Double(wallNanos) / Double(config.iterations)
            let cpuNsPerLookup = Double(cpuNanos) / Double(config.iterations)
            let throughput = Double(config.iterations) / (Double(wallNanos) / 1_000_000_000)

            print("label=\(config.label)")
            print("mode=\(config.mode.rawValue)")
            print("iterations=\(config.iterations)")
            print("warmup=\(config.warmup)")
            print("host_count=\(config.hostCount)")
            print("concurrency=\(config.concurrency)")
            print("wall_ns=\(wallNanos)")
            print("cpu_ns=\(cpuNanos)")
            print(String(format: "ns_per_lookup=%.2f", nsPerLookup))
            print(String(format: "cpu_ns_per_lookup=%.2f", cpuNsPerLookup))
            print(String(format: "lookups_per_sec=%.2f", throughput))
            print("checksum=\(checksum)")
        } catch {
            fputs("Benchmark failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}
