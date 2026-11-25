package com.reactnativecommunity.webview.lunascape

import android.util.Log
import android.webkit.JavascriptInterface
import android.webkit.WebView
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import com.brave.adblock.Engine
import org.json.JSONArray
import org.json.JSONObject

/**
 * Element hiding and scriptlets from the adblock-rust engines (#5580).
 *
 * A script registered with addDocumentStartJavaScript runs in every frame before the page's own
 * scripts. It asks [Bridge.cosmeticResources] (synchronously) for the frame's rules, runs the
 * scriptlets, and hands the rest to AdblockCosmeticFilters.js, which hides elements and asks
 * [Bridge.hiddenClassIdSelectors] for the generic rules that match the page's classes and ids.
 *
 * Scriptlets run through eval, with a Trusted Types policy where the page requires one
 * (YouTube). On a page whose Content-Security-Policy forbids eval, the main
 * frame's scriptlets are run with evaluateJavascript instead, which is a little later.
 */
object AdblockCosmeticFilters {
    private const val TAG = "AdblockCosmeticFilters"
    const val INTERFACE_NAME = "LunascapeAdblock"
    private const val SCRIPT_ASSET = "AdblockCosmeticFilters.js"

    /**
     * The engines for the WebView's current page, or null when ad blocking is off for it (off for
     * the tab, or the page is on the user's allowlist).
     */
    fun interface EngineSource {
        fun engines(): List<Engine>?
    }

    @Volatile
    private var startScript: String? = null

    /** Adds the bridge and the document-start script to [webView]. Call once per WebView. */
    fun install(webView: WebView, engines: EngineSource) {
        if (!WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) {
            Log.w(TAG, "WebView has no document-start scripts; element hiding is off")
            return
        }
        val script = startScript(webView) ?: return
        webView.addJavascriptInterface(Bridge(webView, engines), INTERFACE_NAME)
        WebViewCompat.addDocumentStartJavaScript(webView, script, setOf("*"))
    }

    private fun startScript(webView: WebView): String? {
        startScript?.let { return it }
        val cosmetic = try {
            webView.context.assets.open(SCRIPT_ASSET).bufferedReader().use { it.readText() }
        } catch (e: Exception) {
            Log.e(TAG, "Could not read $SCRIPT_ASSET", e)
            return null
        }
        val script = """
            (function () {
              var bridge = window.$INTERFACE_NAME;
              if (!bridge || window.__lunascapeAdblockStarted) { return; }
              window.__lunascapeAdblockStarted = true;
              var resources;
              try {
                var json = bridge.cosmeticResources(location.href);
                if (!json) { return; }
                resources = JSON.parse(json);
              } catch (e) { return; }
              if (resources.injected_script) {
                try {
                  var code = resources.injected_script;
                  // Pages that require Trusted Types (YouTube) reject a plain string in eval.
                  if (window.trustedTypes && window.trustedTypes.createPolicy) {
                    try {
                      code = window.trustedTypes.createPolicy('lunascape-adblock', {
                        createScript: function (s) { return s; }
                      }).createScript(code);
                    } catch (e) {}
                  }
                  (0, eval)(code);
                  window.__lunascapeAdblockScriptlets = 'document-start';
                } catch (e) {
                  window.__lunascapeAdblockScriptlets = 'late';
                  if (window === window.top) { bridge.runScriptletsInMainFrame(location.href); }
                }
              }
              $cosmetic
              window.__lunascapeAdblockCosmetic(resources, function (classes, ids, exceptions) {
                var selectors = bridge.hiddenClassIdSelectors(
                  JSON.stringify(classes), JSON.stringify(ids), JSON.stringify(exceptions));
                return selectors ? JSON.parse(selectors) : [];
              });
            })();
        """.trimIndent()
        startScript = script
        return script
    }

    /** Merged cosmetic resources of [engines] for [url], or null when there are none. */
    fun cosmeticResources(engines: List<Engine>, url: String): JSONObject? {
        val hide = LinkedHashSet<String>()
        val procedural = LinkedHashSet<String>()
        val exceptions = LinkedHashSet<String>()
        val scripts = ArrayList<String>()
        var genericHide = false
        for (engine in engines) {
            val json = engine.urlCosmeticResources(url) ?: continue
            val resources = try {
                JSONObject(json)
            } catch (e: Exception) {
                continue
            }
            resources.optJSONArray("hide_selectors")?.let { addAll(hide, it) }
            resources.optJSONArray("procedural_actions")?.let { addAll(procedural, it) }
            resources.optJSONArray("exceptions")?.let { addAll(exceptions, it) }
            val script = resources.optString("injected_script")
            if (script.isNotEmpty() && script !in scripts) {
                scripts.add(script)
            }
            genericHide = genericHide || resources.optBoolean("generichide")
        }
        if (hide.isEmpty() && procedural.isEmpty() && scripts.isEmpty() && genericHide) {
            return null
        }
        return JSONObject()
            .put("hide_selectors", JSONArray(hide))
            .put("procedural_actions", JSONArray(procedural))
            .put("exceptions", JSONArray(exceptions))
            .put("injected_script", scripts.joinToString("\n"))
            .put("generichide", genericHide)
    }

    private fun addAll(set: MutableSet<String>, array: JSONArray) {
        for (i in 0 until array.length()) {
            array.optString(i)?.let { set.add(it) }
        }
    }

    private fun toArray(json: String?): Array<String> {
        if (json == null) return emptyArray()
        return try {
            val array = JSONArray(json)
            Array(array.length()) { array.optString(it) }
        } catch (e: Exception) {
            emptyArray()
        }
    }

    /**
     * Called from page scripts in any frame, on WebView's JavaBridge thread. It only gives out
     * filter rules, which are public anyway.
     */
    class Bridge(private val webView: WebView, private val engines: EngineSource) {
        @JavascriptInterface
        fun cosmeticResources(url: String?): String? {
            if (url == null || !(url.startsWith("http://") || url.startsWith("https://"))) return null
            return try {
                val list = engines.engines() ?: return null
                cosmeticResources(list, url)?.toString()
            } catch (e: Exception) {
                Log.w(TAG, "cosmeticResources failed", e)
                null
            }
        }

        @JavascriptInterface
        fun hiddenClassIdSelectors(classesJson: String?, idsJson: String?, exceptionsJson: String?): String? {
            return try {
                val list = engines.engines() ?: return null
                val classes = toArray(classesJson)
                val ids = toArray(idsJson)
                val exceptions = toArray(exceptionsJson)
                val selectors = LinkedHashSet<String>()
                for (engine in list) {
                    engine.hiddenClassIdSelectors(classes, ids, exceptions)?.let { addAll(selectors, JSONArray(it)) }
                }
                JSONArray(selectors).toString()
            } catch (e: Exception) {
                Log.w(TAG, "hiddenClassIdSelectors failed", e)
                null
            }
        }

        /** For pages that forbid eval: runs the main frame's scriptlets with evaluateJavascript. */
        @JavascriptInterface
        fun runScriptletsInMainFrame(url: String?) {
            val script = cosmeticResources(url)?.let {
                try {
                    JSONObject(it).optString("injected_script")
                } catch (e: Exception) {
                    null
                }
            }
            if (script.isNullOrEmpty()) return
            webView.post {
                if (webView.url == url) {
                    webView.evaluateJavascript(script, null)
                }
            }
        }
    }
}
