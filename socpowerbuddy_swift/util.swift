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

func vd_init(sd: static_data) -> variating_data {
    var vd = variating_data()
    for i in 0..<sd.cluster_core_counts.count+3 {
        vd.cluster_residencies.append([])
        vd.cluster_pwrs.append(0)
        vd.cluster_freqs.append(0)
        vd.cluster_use.append(0)
        vd.cluster_sums.append(0)
        
        if i <= sd.cluster_core_counts.count-1 {
            vd.core_pwrs.append([])
            vd.core_residencies.append([])
            vd.core_freqs.append([])
            vd.core_sums.append([])
            vd.core_use.append([])
        }
    }

    for i in 0..<sd.cluster_core_counts.count {
        for _ in 0..<sd.cluster_core_counts[i] {
            vd.core_pwrs[i].append([])
            vd.core_residencies[i].append([])
            vd.core_use[i].append(0)
            vd.core_freqs[i].append(0)
            vd.core_sums[i].append(0)
        }
    }
    return vd
}
