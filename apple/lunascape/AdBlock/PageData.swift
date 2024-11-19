//
//  PageData.swift
//
import Foundation
import WebKit


@available(iOS 13.0.0, *)
struct PageData {
  /// The url of the page (i.e. main frame)
  private(set) var mainFrameURL: URL
  /// A list of all currently available subframes for this current page
  /// These are loaded dyncamically as the user scrolls through the page
  private(set) var allSubframeURLs: Set<URL> = []
  /// The stats class to get the engine data from
  private var adBlockStats: AdBlockStats
  
  init(mainFrameURL: URL, adBlockStats: AdBlockStats = AdBlockStats.shared) {
    self.mainFrameURL = mainFrameURL
    self.adBlockStats = adBlockStats
  }
  
  /// This method builds all the user scripts that should be included for this page
  @MainActor mutating func addSubframeURL(forRequestURL requestURL: URL, isForMainFrame: Bool) {
    if !isForMainFrame {
      // We need to add any non-main frame urls to our site data
      // We will need this to construct all non-main frame scripts
      allSubframeURLs.insert(requestURL)
    }
  }
  
  /// A new list of scripts is returned only if a change is detected in the response (for example an HTTPs upgrade).
  /// In some cases (like during an https upgrade) the scripts may change on the response. So we need to update the user scripts
  @MainActor mutating func upgradeFrameURL(forResponseURL responseURL: URL, isForMainFrame: Bool) -> Bool {
    if isForMainFrame {
      // If it's the main frame url that was upgraded,
      // we need to update it and rebuild the types
      guard mainFrameURL != responseURL else { return false }
      mainFrameURL = responseURL
      return true
    } else if !allSubframeURLs.contains(responseURL) {
      // first try to remove the old unwanted `http` frame URL
      if var components = URLComponents(url: responseURL, resolvingAgainstBaseURL: false), components.scheme == "https" {
        components.scheme = "http"
        if let downgradedURL = components.url {
          allSubframeURLs.remove(downgradedURL)
        }
      }
      
      // Now add the new subframe url
      allSubframeURLs.insert(responseURL)
      return true
    } else {
      // Nothing changed. Return nil
      return false
    }
  }
  
  
  /// Return all the user script types for this page. The number of script types grows as more frames are loaded.
  @MainActor func makeUserScriptTypes() async -> Set<UserScriptType> {
    var userScriptTypes: Set<UserScriptType> = [.gpc(true)]
    
    
    let allEngineScriptTypes = await makeAllEngineScripts()
    return userScriptTypes.union(allEngineScriptTypes)
  }
  
//  func makeMainFrameEngineScriptTypes(domain: Domain) async -> Set<UserScriptType> {
//    return await adBlockStats.makeEngineScriptTypes(frameURL: mainFrameURL, isMainFrame: true, domain: domain)
//  }
//  
  func makeAllEngineScripts() async -> Set<UserScriptType> {
    // Add engine scripts for the main frame
    async let engineScripts = adBlockStats.makeEngineScriptTypes(frameURL: mainFrameURL, isMainFrame: true)
    
    // Add engine scripts for all of the known sub-frames
    async let additionalScriptTypes = allSubframeURLs.asyncConcurrentCompactMap({ frameURL in
      return await self.adBlockStats.makeEngineScriptTypes(frameURL: frameURL, isMainFrame: false)
    }).reduce(Set<UserScriptType>(), { partialResult, scriptTypes in
      return partialResult.union(scriptTypes)
    })
    
    let allEngineScripts = await (mainFrame: engineScripts, subFrames: additionalScriptTypes)
    return allEngineScripts.mainFrame.union(allEngineScripts.subFrames)
  }
}
