//
//  util.swift
//  socpowerbuddy_swift
//
//  Created by Eom SeHwan on 2022/09/24.
//

import Foundation

func convertToGB(_ num: Double) -> [Double] {
    var res = [num, 0]
    while res[0] > 1024 {
        res[0] /= 1024
        res[1] += 1
    }
    res[0] = round(res[0] * 1000)/1000.0
    return res
}

func ByteUnit(_ num: Double) -> String {
    var unit = ""
    switch num {
    case 0: unit = "B"
    case 1: unit = "KB"
    case 2: unit = "MB"
    case 3: unit = "GB"
    case 4: unit = "TB"
    default: break
    }
    return unit
}

func vd_init(sd: static_data) -> variating_data {
    var vd = variating_data()
    autoreleasepool {
        let cores = sd.cluster_core_counts
        for i in 0..<sd.complex_pwr_channels.count {
            vd.cluster_residencies.append([])
            vd.cluster_pwrs.append(0)
            vd.cluster_freqs.append(0)
            vd.cluster_use.append(0)
            vd.cluster_sums.append(0)
            
            if i <= cores.count-1 {
                vd.core_pwrs.append([])
                vd.core_residencies.append([])
                vd.core_freqs.append([])
                vd.core_sums.append([])
                vd.core_use.append([])
            }
        }

        for i in 0..<cores.count {
            for _ in 0..<cores[i] {
                vd.core_pwrs[i].append([])
                vd.core_residencies[i].append([])
                vd.core_use[i].append(0)
                vd.core_freqs[i].append(0)
                vd.core_sums[i].append(0)
            }
        }
    }
    return vd
}

extension String {
    func getRegexArr(regex: String) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: "m[0-9]+")
            let results = regex.matches(in: self, range: NSRange(self.startIndex..., in: self))
            return results.map {
                String(self[Range($0.range, in:self)!])
            }
        } catch _ {
            // print("invalid regex: \(error.localizedDescription)")
            return []
        }
    }
}

