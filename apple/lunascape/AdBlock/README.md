# Adblock
This source code based on https://github.com/brave/brave-ios/blob/v1.62.1/Sources/Brave/WebFilters/AdblockRustEngine.swift 
My goal is to make it work on iOS, iPadOS.

Features:
- Block ads with WebKit Content Blocker (https://webkit.org/blog/3476/content-blockers-first-look/).  
Docs: https://developer.apple.com/documentation/webkit/wkcontentruleliststore
- Block ads with Adblock-rust library (https://github.com/brave/adblock-rust)
  - A FFI crate C++ wrapper: https://github.com/gu-corp/adblock-rust-jni/tree/dev-v0.7.9. Please check details in {root_dir}/apple/libs/README.md
  - Request blocking with Adblock-rust library via window.fetch and XMLHttpRequest.
  - Create customUserScript with Adblock-rust library. (support later)