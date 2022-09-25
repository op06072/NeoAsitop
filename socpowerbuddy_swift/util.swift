//
//  util.swift
//  socpowerbuddy_swift
//
//  Created by Eom SeHwan on 2022/09/24.
//

import Foundation

func convertToGB(_ num: Double) -> Double {
    var res = num
    while res >= 1024 {
        res /= 1024
    }
    return round(res * 1000)/1000.0
}

func eraseScreen() {
    print("\u{001B}[H\u{001B}[0J")
}
