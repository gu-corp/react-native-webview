// Lunascape YouTube ad blocking (updated 2026-11, gu-corp/lunascape-mobile#5578).
//
// YouTube sends its ads inside the player data (adPlacements / adSlots / playerAds), in the page
// (ytInitialPlayerResponse), in JSON.parse results and in the /youtubei/v1/* fetch/XHR responses
// (player, next, get_watch, reel_watch_sequence for Shorts). This removes them at every step,
// following the same approach as the current uBlock Origin YouTube filters (json-prune,
// json-prune-fetch-response / -xhr-response, set-constant), plus a fallback that skips an ad that
// still starts playing (server-side inserted ads). Runs once per page; injected at page start
// and again when the page has loaded.
(function () {
  if (window.__lsYoutubeAdblock) return;
  window.__lsYoutubeAdblock = true;

  var AD_KEYS = ['adPlacements', 'adSlots', 'playerAds'];

  // --- Remove the ad fields from an object (player response or a wrapper around one). ---------
  function pruneAds(obj) {
    if (!obj || typeof obj !== 'object') return obj;
    var targets = [obj, obj.playerResponse];
    if (Array.isArray(obj)) {
      for (var i = 0; i < obj.length; i++) targets.push(obj[i], obj[i] && obj[i].playerResponse);
    }
    try {
      var pre = obj.endpoint && obj.endpoint.watchEndpoint && obj.endpoint.watchEndpoint.unserializedPrefetchData;
      if (pre) targets.push(pre.playerResponse);
    } catch (e) {}
    for (var t = 0; t < targets.length; t++) {
      var o = targets[t];
      if (!o || typeof o !== 'object') continue;
      for (var k = 0; k < AD_KEYS.length; k++) {
        if (Object.prototype.hasOwnProperty.call(o, AD_KEYS[k])) delete o[AD_KEYS[k]];
      }
    }
    // Shorts: drop the entries that are ads.
    var lists = [obj.entries, obj.reelWatchSequenceResponse && obj.reelWatchSequenceResponse.entries];
    for (var l = 0; l < lists.length; l++) {
      var list = lists[l];
      if (!Array.isArray(list)) continue;
      for (var j = list.length - 1; j >= 0; j--) {
        try {
          if (list[j].command.reelWatchEndpoint.adClientParams.isAd) list.splice(j, 1);
        } catch (e) {}
      }
    }
    return obj;
  }

  // --- JSON.parse ----------------------------------------------------------------------------
  var nativeParse = JSON.parse;
  JSON.parse = new Proxy(nativeParse, {
    apply: function (target, thisArg, args) {
      var r = Reflect.apply(target, thisArg, args);
      try { pruneAds(r); } catch (e) {}
      return r;
    },
  });

  // --- Responses of the YouTube API (fetch and XHR) --------------------------------------------
  var API = /\/youtubei\/v1\/(player|next|get_watch|reel\/reel_watch_sequence|reel_watch_sequence|browse)|\/playlist\?|[?&]pbj=1/;

  // Rename the ad keys in the raw JSON text: the player then finds no ads. Cheap and also works
  // for responses that are parsed by code we do not see.
  function cleanText(text) {
    if (typeof text !== 'string' || text.indexOf('"ad') === -1 && text.indexOf('"playerAds"') === -1) return text;
    return text
      .replace(/"adPlacements"/g, '"no_ads_p"')
      .replace(/"adSlots"/g, '"no_ads_s"')
      .replace(/"playerAds"/g, '"no_ads_a"');
  }

  if (window.fetch) {
    var nativeFetch = window.fetch;
    window.fetch = new Proxy(nativeFetch, {
      apply: function (target, thisArg, args) {
        var p = Reflect.apply(target, thisArg, args);
        var url = '';
        try { url = typeof args[0] === 'string' ? args[0] : (args[0] && args[0].url) || ''; } catch (e) {}
        if (!API.test(url)) return p;
        return p.then(function (res) {
          if (!res || !res.ok) return res;
          return res.clone().text().then(function (text) {
            var cleaned = cleanText(text);
            if (cleaned === text) return res;
            var out = new Response(cleaned, { status: res.status, statusText: res.statusText, headers: res.headers });
            try {
              Object.defineProperty(out, 'url', { value: res.url });
              Object.defineProperty(out, 'type', { value: res.type });
            } catch (e) {}
            return out;
          }).catch(function () { return res; });
        });
      },
    });
  }

  var xhrProto = XMLHttpRequest.prototype;
  var nativeOpen = xhrProto.open;
  xhrProto.open = function (method, url) {
    try { this.__lsYtUrl = String(url); } catch (e) {}
    return nativeOpen.apply(this, arguments);
  };
  ['responseText', 'response'].forEach(function (prop) {
    var desc = Object.getOwnPropertyDescriptor(xhrProto, prop);
    if (!desc || !desc.get) return;
    Object.defineProperty(xhrProto, prop, {
      configurable: true,
      get: function () {
        var v = desc.get.call(this);
        if (this.readyState !== 4 || !this.__lsYtUrl || !API.test(this.__lsYtUrl)) return v;
        if (typeof v === 'string') return cleanText(v);
        if (v && typeof v === 'object' && !(v instanceof ArrayBuffer) && !(v instanceof Blob)) {
          try { pruneAds(v); } catch (e) {}
        }
        return v;
      },
    });
  });

  // --- The player response written into the page ----------------------------------------------
  ['ytInitialPlayerResponse', 'playerResponse'].forEach(function (name) {
    var value = window[name];
    if (value) pruneAds(value);
    try {
      Object.defineProperty(window, name, {
        configurable: true,
        get: function () { return value; },
        set: function (v) { value = pruneAds(v); },
      });
    } catch (e) {}
  });

  // --- Fallback: an ad that still plays is skipped, ad boxes are hidden -----------------------
  var style = document.createElement('style');
  style.textContent = [
    'ytm-promoted-sparkles-web-renderer', 'ytm-promoted-video-renderer', 'ytm-companion-ad-renderer',
    'ad-slot-renderer', 'ytm-ad-slot-renderer', 'ytd-ad-slot-renderer', 'ytd-promoted-sparkles-web-renderer',
    'ytd-in-feed-ad-layout-renderer', 'ytd-banner-promo-renderer', 'ytm-statement-banner-renderer',
    '.ytp-ad-overlay-container', '.ytp-ad-message-container', 'ytm-promoted-sparkles-text-search-renderer',
    'ytd-engagement-panel-section-list-renderer[target-id="engagement-panel-ads"]',
  ].join(',') + '{display:none !important}';
  (document.head || document.documentElement).appendChild(style);

  function skipAd() {
    try {
      var player = document.querySelector('.ad-showing, .ad-interrupting');
      if (!player) return;
      var video = player.querySelector('video');
      if (video && isFinite(video.duration) && video.duration > 0 && video.currentTime < video.duration - 0.1) {
        video.currentTime = video.duration;
      }
      var skip = document.querySelector('.ytp-ad-skip-button, .ytp-ad-skip-button-modern, .ytp-skip-ad-button, button.ytp-ad-skip-button-container');
      if (skip) skip.click();
    } catch (e) {}
  }
  setInterval(skipAd, 500);
})();
//# sourceURL=Lunascape_mobile_youtubeAdblock.js
