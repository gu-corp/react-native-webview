/* Copyright (c) 2019 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/. */

// You can update this script here: https://github.com/brave/brave-core/blob/master/browser/android/youtube_script_injector/youtube_script_injector_tab_helper.cc
(function () {
  if (document._addEventListener === undefined) {
    document._addEventListener = document.addEventListener;
    document.addEventListener = function (a, b, c) {
      if (a != 'visibilitychange') {
        document._addEventListener(a, b, c);
      }
    };
  }

  // Override document.visibilityState to always return 'visible'
  Object.defineProperty(document, 'visibilityState', {
    configurable: true,
    get: function () {
      return 'visible';
    },
  });
})();

// add sourceURL for debugging on chrome devtools
//# sourceURL=Lunascape_mobile_YoutubeBackgroundPlayback.js
