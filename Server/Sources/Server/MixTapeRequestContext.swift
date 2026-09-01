// SPDX-License-Identifier: AGPL-3.0-only
//
//  MixTapeRequestContext.swift
//  Server
//
//  Created by Jamie Le Souëf on 01/09/2026.
//

import Foundation
import Hummingbird
import Shared

struct MixTapeRequestContext: RequestContext {
  var coreContext: CoreRequestContextStorage

  init(source: Source) {
    self.coreContext = .init(source: source)
  }

  var responseEncoder: JSONEncoder { MixTapeJSON.encoder }

  var requestDecoder: JSONDecoder { MixTapeJSON.decoder }
}
