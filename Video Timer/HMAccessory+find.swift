//
//  HMAccessory+find.swift
//  Video Timer
//
//  Created by James Perlman on 1/11/21.
//

import HomeKit

extension HMAccessory {
  func find(serviceType: String, characteristicType: String) -> HMCharacteristic? {
    return services.lazy
      .filter { $0.serviceType == serviceType }
      .flatMap { $0.characteristics }
      .first { $0.metadata?.format == characteristicType }
  }
}
