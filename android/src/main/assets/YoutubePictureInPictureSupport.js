/* Copyright (c) 2019 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/. */

 // You can update this script here: https://github.com/brave/brave-core/blob/master/browser/android/youtube_script_injector/youtube_script_injector_tab_helper.cc
(function() {
    // Function to modify the flags if the target object exists.
    function modifyYtcfgFlags() {
      const config = window.ytcfg.get("WEB_PLAYER_CONTEXT_CONFIGS")
        ?.WEB_PLAYER_CONTEXT_CONFIG_ID_MWEB_WATCH
      if (config && config.serializedExperimentFlags && typeof config
        .serializedExperimentFlags === 'string') {
        let flags = config.serializedExperimentFlags;
  
        // Replace target flags.
        flags = flags
          .replace(
            "html5_picture_in_picture_blocking_ontimeupdate=true",
            "html5_picture_in_picture_blocking_ontimeupdate=false")
          .replace("html5_picture_in_picture_blocking_onresize=true",
            "html5_picture_in_picture_blocking_onresize=false")
          .replace(
            "html5_picture_in_picture_blocking_document_fullscreen=true",
            "html5_picture_in_picture_blocking_document_fullscreen=false"
          )
          .replace(
            "html5_picture_in_picture_blocking_standard_api=true",
            "html5_picture_in_picture_blocking_standard_api=false")
          .replace("html5_picture_in_picture_logging_onresize=true",
            "html5_picture_in_picture_logging_onresize=false");
  
        // Assign updated flags back to config.
        config.serializedExperimentFlags = flags;
      }
    }
  
    if (window.ytcfg) {
      modifyYtcfgFlags();
    } else {
      document.addEventListener('load', (event) => {
        const target = event.target;
        if (target.tagName === 'SCRIPT' && window.ytcfg) {
          // Check and modify flags when a new script is added.
          modifyYtcfgFlags();
        }
      }, true);
    }
}());
  
    // add sourceURL for debugging on chrome devtools
    //# sourceURL=Lunascape_mobile_YoutubePictureInPictureSupport.js