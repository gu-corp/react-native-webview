import WebKit
// reference: https://github.com/brave/brave-core/blob/5953436ac2e5f2f177d8a62a9889629c491c0971/ios/brave-ios/Sources/Web/WebKit/WebKitPrivateHelpers.swift#L53
extension WKNavigationAction {
  var isSyntheticClick: Bool {
    responds(to: Selector(("_syntheticClickType")))
      && value(forKey: "syntheticClickType") as? Int == 0
  }
  var isUserInitiated: Bool {
    // For window.open we need to be able to determine if the request was user initiated, but
    // synthetic click types don't seem to be reported correctly when window.open is triggered from
    // within a subframe.
    //
    // WKNavigationActionPrivate.h definition:
    //     @property (nonatomic, readonly, getter=_isUserInitiated) BOOL _userInitiated;
    let selector = Selector(("_isUserInitiated"))
    #if DEBUG
    assert(responds(to: selector), "WKNavigationAction does not respond to _isUserInitiated")
    #endif
    guard responds(to: selector), let result = perform(selector) else {
      return false
    }
    return Int(bitPattern: result.toOpaque()) == 1
  }
}

@objc(WKNavigationActionHelper)
public class WKNavigationActionHelper: NSObject {
  
  @objc
  public static func isSyntheticClick(_ navigationAction: WKNavigationAction) -> Bool {
    return navigationAction.isSyntheticClick
  }
  
  @objc
  public static func isUserInitiated(_ navigationAction: WKNavigationAction) -> Bool {
    return navigationAction.isUserInitiated
  }
}