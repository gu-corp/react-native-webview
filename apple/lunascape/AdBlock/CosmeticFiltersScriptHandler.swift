//
//  CosmeticFiltersScriptHandler.swift
//

import Foundation
import WebKit

/// Element hiding and scriptlets from the adblock-rust engines (#5580).
///
/// Before a main-frame navigation is allowed, asks the engines for the page's cosmetic resources
/// and installs one user script for it, run at document start in the page's world:
/// - the scriptlets (`+js(...)` rules), and
/// - `AdblockCosmeticFilters.js` with the page's hide selectors and procedural filters.
///
/// The script is part of the WebView's configuration, so a page's Content-Security-Policy does not
/// stop it. It only runs when the document's host is the one it was made for, so a redirect to
/// another site does not get the wrong rules.
///
/// Generic class / id rules are not looked up here: the WKContentRuleList built from the same
/// lists already hides those.
@available(iOS 14.0, *)
class CosmeticFiltersScriptHandler {
    /// How long a navigation may wait for the engines. After that it goes on without the script.
    private static let timeout: TimeInterval = 0.3

    private static let cosmeticScriptSource: String? = {
        guard let bundlePath = Bundle.main.path(forResource: "Settings", ofType: "bundle"),
              let url = Bundle(path: bundlePath)?.url(forResource: "AdblockResources/Scripts/AdblockCosmeticFilters",
                                                      withExtension: "js") else {
            assertionFailure("AdblockCosmeticFilters.js is missing from Settings.bundle")
            return nil
        }
        return try? String(contentsOf: url)
    }()

    private weak var webView: WKWebView?
    private var installedScript: WKUserScript?
    /// Bumped by every prepare() and remove(), so a lookup that finishes after a newer one
    /// started, or after ad blocking was turned off for the page, does not install its script.
    private var generation = 0

    init(webView: WKWebView) {
        self.webView = webView
    }

    /// Installs the script for the page `navigationAction` loads, then calls `completion` on the
    /// main thread. Calls it at once for anything but a main-frame http(s) navigation.
    @MainActor
    func prepare(for navigationAction: WKNavigationAction, completion: @escaping () -> Void) {
        guard navigationAction.targetFrame?.isMainFrame == true,
              let url = navigationAction.request.url,
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host else {
            completion()
            return
        }

        generation += 1
        let myGeneration = generation
        var finished = false
        let finish = {
            if !finished {
                finished = true
                completion()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.timeout, execute: finish)

        Task { @MainActor in
            let source = await Self.makeSource(for: url, host: host)
            if !finished && self.generation == myGeneration {
                self.install(source: source)
            }
            finish()
        }
    }

    /// Removes the script, for pages where ad blocking is off.
    @MainActor
    func remove() {
        generation += 1
        install(source: nil)
    }

    @MainActor
    private func install(source: String?) {
        guard let controller = webView?.configuration.userContentController else { return }
        if let installedScript {
            // WKUserContentController cannot remove one script: remove all and add the others back.
            let others = controller.userScripts.filter { $0 !== installedScript }
            controller.removeAllUserScripts()
            others.forEach(controller.addUserScript)
            self.installedScript = nil
        }
        guard let source else { return }
        let script = WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true, in: .page)
        controller.addUserScript(script)
        installedScript = script
    }

    private static func makeSource(for url: URL, host: String) async -> String? {
        guard let cosmeticScriptSource else { return nil }
        let engines = await AdBlockStats.shared.cachedEngines()
        guard !engines.isEmpty else { return nil }

        var hideSelectors = Set<String>()
        var proceduralActions = Set<String>()
        var exceptions = Set<String>()
        var scriptlets: [String] = []
        var genericHide = false
        for engine in engines {
            guard let model = try? await engine.cosmeticFilterModel(forFrameURL: url) else { continue }
            hideSelectors.formUnion(model.hideSelectors)
            proceduralActions.formUnion(model.proceduralActions)
            exceptions.formUnion(model.exceptions)
            genericHide = genericHide || model.genericHide
            if !model.injectedScript.isEmpty && !scriptlets.contains(model.injectedScript) {
                scriptlets.append(model.injectedScript)
            }
        }
        if hideSelectors.isEmpty && proceduralActions.isEmpty && scriptlets.isEmpty {
            return nil
        }

        let resources: [String: Any] = [
            "hide_selectors": Array(hideSelectors),
            "procedural_actions": Array(proceduralActions),
            "exceptions": Array(exceptions),
            "generichide": genericHide,
        ]
        guard let resourcesData = try? JSONSerialization.data(withJSONObject: resources),
              let resourcesJSON = String(data: resourcesData, encoding: .utf8),
              let hostData = try? JSONSerialization.data(withJSONObject: [host]),
              let hostArrayJSON = String(data: hostData, encoding: .utf8) else {
            return nil
        }

        return """
        (function () {
          if (location.hostname !== \(hostArrayJSON)[0]) { return; }
          \(scriptlets.joined(separator: "\n"))
        })();
        \(cosmeticScriptSource)
        (function () {
          if (location.hostname !== \(hostArrayJSON)[0]) { return; }
          window.__lunascapeAdblockCosmetic(\(resourcesJSON), null);
        })();
        """
    }
}
