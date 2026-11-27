//
//  CosmeticFilterModel.swift
//

import Foundation

/// Model containing information on scripts, selectors
/// and other information that needs to be processed on a web frame.
struct CosmeticFilterModel: Codable {
  /// These are the selectors that should be hidden on the frame.
  /// Contains hide selectors such as the ones needed for cookie consent blocking.
  let hideSelectors: [String]
  /// Procedural filters and filters with an action (`:style()`, `:remove()`, `:has-text()`, ...),
  /// each a JSON string such as
  /// `{"selector":[{"type":"css-selector","arg":".ad"}],"action":{"type":"style","arg":"opacity: 0"}}`.
  /// adblock-rust 0.13 returns these instead of the old `style_selectors`.
  let proceduralActions: [String]
  /// These are exceptions that should be given back to the engine
  /// when retrieving additional selectors given by the `SelectorsPollerScript.js` script.
  let exceptions: [String]
  /// This is the script that should be injected into the frame.
  /// May contain scripts such as de-amp, youtube ad-block, etc.
  let injectedScript: String
  /// A boolean indicating if generic hide is enabled on the web frame
  /// and given to the `SelectorsPollerScript.js` script during its initialization.
  let genericHide: Bool
  
  enum CodingKeys: String, CodingKey {
    case hideSelectors = "hide_selectors"
    case proceduralActions = "procedural_actions"
    case exceptions = "exceptions"
    case injectedScript = "injected_script"
    case genericHide = "generichide"
  }
}
