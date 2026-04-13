//
//  Item.swift
//  Downly
//
//  Created by Arnab Goswami on 13/04/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
