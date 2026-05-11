import Foundation
import Dispatch
import Darwin

struct Config {
    var iterations: Int = 3_000
    var warmup: Int = 300
    var hostCount: Int = 2_000
    var concurrency: Int = 1
    var settingsBundlePath: String = ""
    var label: String = "current"
    var seed: UInt64 = 42
}

struct RequestCase {
    let requestURL: URL
    let sourceURL: URL
    let resourceType: AdblockRustEngine.ResourceType
    let hashSeed: Int
}

struct PhaseMetrics {
    let wallNanos: UInt64
    let cpuNanos: UInt64
    let nsPerLookup: Double
    let cpuNsPerLookup: Double
    let lookupsPerSec: Double
    let blockRate: Double
    let checksum: Int
}

struct LookupResult {
    var blocked: Int
    var checksum: Int
}

enum AccessPattern {
    case cyclic
    case unique(start: Int)
}

struct LCG {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextInt(_ upperBound: Int) -> Int {
        precondition(upperBound > 0)
        return Int(next() % UInt64(upperBound))
    }
}

func processCPUTimeNanos() -> UInt64 {
    var ts = timespec()
    clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &ts)
    return UInt64(ts.tv_sec) * 1_000_000_000 + UInt64(ts.tv_nsec)
}

func parseArgs() throws -> Config {
    var config = Config()
    let args = CommandLine.arguments
    var index = 1

    while index < args.count {
        let arg = args[index]

        func requireValue(_ key: String) throws -> String {
            let next = index + 1
            guard next < args.count else {
                throw NSError(domain: "bench", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing value for \(key)"])
            }
            index = next
            return args[next]
        }

        switch arg {
        case "--iterations":
            config.iterations = Int(try requireValue("--iterations")) ?? config.iterations
        case "--warmup":
            config.warmup = Int(try requireValue("--warmup")) ?? config.warmup
        case "--hosts":
            config.hostCount = Int(try requireValue("--hosts")) ?? config.hostCount
        case "--concurrency":
            config.concurrency = Int(try requireValue("--concurrency")) ?? config.concurrency
        case "--settings-bundle":
            config.settingsBundlePath = try requireValue("--settings-bundle")
        case "--label":
            config.label = try requireValue("--label")
        case "--seed":
            if let value = UInt64(try requireValue("--seed")) {
                config.seed = value
            }
        case "--help", "-h":
            print(
                """
                Usage:
                  should_block_cpu_bench --settings-bundle <path> [options]

                Options:
                  --iterations <n>      Lookups per phase (default: 3000)
                  --warmup <n>          Warm-up lookups before measure (default: 300)
                  --hosts <n>           Distinct hosts for warm phase (default: 2000)
                  --concurrency <n>     Concurrent workers (default: 1)
                  --label <text>        Label written to output
                  --seed <n>            Deterministic seed (default: 42)
                """
            )
            exit(0)
        default:
            throw NSError(domain: "bench", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown argument: \(arg)"])
        }

        index += 1
    }

    guard !config.settingsBundlePath.isEmpty else {
        throw NSError(domain: "bench", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing required --settings-bundle"])
    }

    config.iterations = max(config.iterations, 1)
    config.warmup = max(config.warmup, 0)
    config.hostCount = max(config.hostCount, 1)
    config.concurrency = max(config.concurrency, 1)
    return config
}

func resourceURL(_ host: String, type: AdblockRustEngine.ResourceType, index: Int) -> URL {
    let path: String
    switch type {
    case .script:
        path = "/assets/js/\(index % 97).js"
    case .image:
        path = "/assets/img/\(index % 89).png"
    case .xmlhttprequest:
        path = "/api/v1/data/\(index % 77)"
    case .subdocument:
        path = "/frame/\(index % 67)/index.html"
    }
    return URL(string: "https://\(host)\(path)?q=\(index)")!
}

func sourceURL(_ host: String, index: Int) -> URL {
    return URL(string: "https://\(host)/page/\(index % 131)?ref=\(index % 53)")!
}

func generateRequestCases(count: Int, seed: UInt64) -> [RequestCase] {
    let tlds = ["com", "net", "org", "io", "app", "co.uk", "vn", "co.jp", "de", "fr"]
    let roots = [
        "alpha", "beta", "gamma", "delta", "omega", "luna", "nova", "terra", "orbit", "nexus",
        "zen", "peak", "stream", "pulse", "pixel", "forge", "bravo", "atlas", "vector", "echo"
    ]
    let subdomains = ["www", "m", "cdn", "img", "api", "ads", "static", "news", "media", "track"]
    let resourceTypes: [AdblockRustEngine.ResourceType] = [.script, .image, .xmlhttprequest, .subdocument]

    var rng = LCG(seed: seed)
    var cases = [RequestCase]()
    cases.reserveCapacity(max(count, 1))

    for i in 0..<max(count, 1) {
        let sourceRoot = roots[(i * 7 + rng.nextInt(roots.count)) % roots.count]
        let sourceTld = tlds[(i * 11 + rng.nextInt(tlds.count)) % tlds.count]
        let sourceHost = "www.\(sourceRoot).\(sourceTld)"

        let thirdParty = (i % 4) != 0
        let requestHost: String
        if thirdParty {
            let reqSub = subdomains[(i * 5 + rng.nextInt(subdomains.count)) % subdomains.count]
            let reqRoot = roots[(i * 13 + rng.nextInt(roots.count)) % roots.count]
            let reqTld = tlds[(i * 17 + rng.nextInt(tlds.count)) % tlds.count]
            requestHost = "\(reqSub).\(reqRoot).\(reqTld)"
        } else {
            let reqSub = subdomains[(i * 3 + 1) % subdomains.count]
            requestHost = "\(reqSub).\(sourceRoot).\(sourceTld)"
        }

        let type = resourceTypes[(i + rng.nextInt(resourceTypes.count)) % resourceTypes.count]
        let requestURLValue = resourceURL(requestHost, type: type, index: i)
        let sourceURLValue = sourceURL(sourceHost, index: i)

        let hashSeed = sourceHost.utf8.count &+ requestHost.utf8.count &+ i
        cases.append(RequestCase(
            requestURL: requestURLValue,
            sourceURL: sourceURLValue,
            resourceType: type,
            hashSeed: hashSeed
        ))
    }

    return cases
}

@available(iOS 13.0, *)
func compileProductionEngines(settingsBundlePath: String) async throws {
    let settingsBundleURL = URL(fileURLWithPath: settingsBundlePath, isDirectory: true)
    let resourcesURL = settingsBundleURL.appendingPathComponent("AdblockResources/resources.json")

    let resourcesInfo = CachedAdBlockEngine.ResourcesInfo(localFileURL: resourcesURL)
    let filterLists: [(CachedAdBlockEngine.Source, String)] = [
        (.adBlock, "AdblockResources/Easylist/list.txt"),
        (.filterList(componentId: "bfpgedeaaibpoidldhjcknekahbikncb"), "AdblockResources/Easylist/list7545.txt"),
        (.filterList(componentId: "cdbbhgbmjhfnhnmgeddbliobbofkgdhe"), "AdblockResources/Easylist/list8055.txt"),
        (.filterList(componentId: "llgjaaddopeckcifdceaaadmemagkepi"), "AdblockResources/Easylist/list1458.txt")
    ]

    for (source, relativePath) in filterLists {
        let filterURL = settingsBundleURL.appendingPathComponent(relativePath)
        let listInfo = CachedAdBlockEngine.FilterListInfo(source: source, localFileURL: filterURL)
        await AdBlockStats.shared.compile(lazyInfo: listInfo, resourcesInfo: resourcesInfo)
    }
}

@available(iOS 13.0, *)
func executeLookups(
    requests: [RequestCase],
    iterations: Int,
    concurrency: Int,
    accessPattern: AccessPattern
) async -> LookupResult {
    guard !requests.isEmpty else {
        return LookupResult(blocked: 0, checksum: 0)
    }

    func requestFor(step: Int) -> RequestCase {
        switch accessPattern {
        case .cyclic:
            return requests[step % requests.count]
        case .unique(let start):
            return requests[start + step]
        }
    }

    if concurrency <= 1 {
        var blockedCount = 0
        var checksum = 0
        for step in 0..<iterations {
            let request = requestFor(step: step)
            let blocked = await AdBlockStats.shared.shouldBlock(
                requestURL: request.requestURL,
                sourceURL: request.sourceURL,
                resourceType: request.resourceType
            )
            if blocked { blockedCount += 1 }
            checksum &+= request.hashSeed
            checksum &+= blocked ? 97 : 31
        }
        return LookupResult(blocked: blockedCount, checksum: checksum)
    }

    return await withTaskGroup(of: LookupResult.self) { group in
        for worker in 0..<concurrency {
            group.addTask {
                var blockedCount = 0
                var checksum = 0
                var step = worker

                while step < iterations {
                    let request = requestFor(step: step)
                    let blocked = await AdBlockStats.shared.shouldBlock(
                        requestURL: request.requestURL,
                        sourceURL: request.sourceURL,
                        resourceType: request.resourceType
                    )
                    if blocked { blockedCount += 1 }
                    checksum &+= request.hashSeed
                    checksum &+= blocked ? 97 : 31
                    step += concurrency
                }

                return LookupResult(blocked: blockedCount, checksum: checksum)
            }
        }

        var merged = LookupResult(blocked: 0, checksum: 0)
        for await result in group {
            merged.blocked += result.blocked
            merged.checksum &+= result.checksum
        }
        return merged
    }
}

@available(iOS 13.0, *)
func runPhase(
    requests: [RequestCase],
    iterations: Int,
    warmup: Int,
    concurrency: Int,
    accessPattern: AccessPattern
) async -> PhaseMetrics {
    if warmup > 0 {
        _ = await executeLookups(
            requests: requests,
            iterations: warmup,
            concurrency: concurrency,
            accessPattern: accessPattern
        )
    }

    let wallStart = DispatchTime.now().uptimeNanoseconds
    let cpuStart = processCPUTimeNanos()
    let lookupResult = await executeLookups(
        requests: requests,
        iterations: iterations,
        concurrency: concurrency,
        accessPattern: accessPattern
    )
    let cpuEnd = processCPUTimeNanos()
    let wallEnd = DispatchTime.now().uptimeNanoseconds

    let wallNanos = wallEnd &- wallStart
    let cpuNanos = cpuEnd &- cpuStart
    let nsPerLookup = Double(wallNanos) / Double(iterations)
    let cpuNsPerLookup = Double(cpuNanos) / Double(iterations)
    let lookupsPerSec = Double(iterations) / (Double(wallNanos) / 1_000_000_000)
    let blockRate = Double(lookupResult.blocked) / Double(iterations)

    return PhaseMetrics(
        wallNanos: wallNanos,
        cpuNanos: cpuNanos,
        nsPerLookup: nsPerLookup,
        cpuNsPerLookup: cpuNsPerLookup,
        lookupsPerSec: lookupsPerSec,
        blockRate: blockRate,
        checksum: lookupResult.checksum
    )
}

func printPhase(_ name: String, _ metrics: PhaseMetrics) {
    print("\(name).wall_ns=\(metrics.wallNanos)")
    print("\(name).cpu_ns=\(metrics.cpuNanos)")
    print(String(format: "\(name).ns_per_lookup=%.2f", metrics.nsPerLookup))
    print(String(format: "\(name).cpu_ns_per_lookup=%.2f", metrics.cpuNsPerLookup))
    print(String(format: "\(name).lookups_per_sec=%.2f", metrics.lookupsPerSec))
    print(String(format: "\(name).block_rate=%.6f", metrics.blockRate))
    print("\(name).checksum=\(metrics.checksum)")
}

@main
struct Main {
    static func main() async {
        do {
            if #available(iOS 13.0, *) {
                let config = try parseArgs()

                try await compileProductionEngines(settingsBundlePath: config.settingsBundlePath)

                let warmRequests = generateRequestCases(count: config.hostCount, seed: config.seed)
                let coldWarmup = config.warmup
                let coldRequests = generateRequestCases(
                    count: coldWarmup + config.iterations,
                    seed: config.seed &+ 1_000_003
                )

                let coldMetrics = await runPhase(
                    requests: coldRequests,
                    iterations: config.iterations,
                    warmup: coldWarmup,
                    concurrency: config.concurrency,
                    accessPattern: .unique(start: coldWarmup)
                )

                // Ensure warm phase truly measures cache-hit path by prefilling at least one full host cycle.
                let warmWarmup = max(config.warmup, config.hostCount)
                let warmMetrics = await runPhase(
                    requests: warmRequests,
                    iterations: config.iterations,
                    warmup: warmWarmup,
                    concurrency: config.concurrency,
                    accessPattern: .cyclic
                )

                print("label=\(config.label)")
                print("settings_bundle=\(config.settingsBundlePath)")
                print("engines=4")
                print("iterations=\(config.iterations)")
                print("warmup=\(config.warmup)")
                print("host_count=\(config.hostCount)")
                print("concurrency=\(config.concurrency)")
                print("seed=\(config.seed)")

                printPhase("cold", coldMetrics)
                printPhase("warm", warmMetrics)
                print("overall.checksum=\(coldMetrics.checksum &+ warmMetrics.checksum)")
            } else {
                fputs("Benchmark requires iOS 13.0+\n", stderr)
                exit(1)
            }
        } catch {
            fputs("Benchmark failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}
