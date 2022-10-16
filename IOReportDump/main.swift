//
//  main.swift
//  IOReportDump
//
//  Created by Eom SeHwan on 2022/09/28.
//

import Foundation

enum kIORep: Int32 {
    case kIOReportInvalidFormat
    case kIOReportFormatSimple
    case kIOReportFormatState
    case kIOReportFormatSimpleArray
}

extension kIORep {
    var val: Int32 {
        switch self {
        case .kIOReportInvalidFormat:     return 0
        case .kIOReportFormatSimple:      return 1
        case .kIOReportFormatState:       return 2
        case .kIOReportFormatSimpleArray: return 4
        }
    }
}

var subchn: Unmanaged<CFMutableDictionary>? = nil
var chn = IOReportCopyAllChannels(0, 0)
var sub = IOReportCreateSubscription(nil, chn?.takeUnretainedValue(), &subchn, 0, nil)

let interval: Double = 175

var samples_a = IOReportCreateSamples(sub, subchn?.takeUnretainedValue(), nil).takeUnretainedValue()

Thread.sleep(forTimeInterval: interval*1e-3)

var samples_b = IOReportCreateSamples(sub, subchn?.takeUnretainedValue(), nil).takeUnretainedValue()

let samp_delta = Array((IOReportCreateSamplesDelta(
    samples_a, samples_b, nil
).takeUnretainedValue() as Dictionary).values)[0] as! Array<CFDictionary>

/*func IOReportGetInt(_ data: CFDictionary, _ mode: UInt8) {
    var data2 = (data as! Dictionary<String, AnyObject>)["RawElements"] as! NSData
    var arr = Array<UInt32>(repeating: 0, count: data2.count/MemoryLayout<UInt32>.stride)
    arr.withUnsafeMutableBytes { data2.copyBytes(to: $0) }
    print(arr)
}*/

for sample in samp_delta {
    let group = IOReportChannelGetGroup(sample)
    var subgroup = IOReportChannelGetSubGroup(sample)
    let chann_name = IOReportChannelGetChannelName(sample)
    let names = ["CPU Stats", "GPU Stats", "AMC Stats", "CLPC Stats", "PMP", "Energy Model"]
    if names.contains(group!) {
        switch IOReportChannelGetFormat(sample) {
        case kIORep.kIOReportFormatSimple.rawValue:
            // IOReportGetInt(sample, 0)
            if subgroup == nil {
                subgroup = ""
            }
            print("Grp: \(group!) Subgrp: \(subgroup!) Chn: \(chann_name!) "+String(format: "Value: %ld\n", IOReportSimpleGetIntegerValue(sample, 0)))
            break
        case kIORep.kIOReportFormatState.rawValue:
            // IOReportGetInt(sample, 1)
            for i in 0..<IOReportStateGetCount(sample) {
                let tmp = IOReportStateGetResidency(sample, i)
                print("Grp: \(group!) Subgrp: \(subgroup!) Chn: \(chann_name!) "+String(format: "State: \(IOReportStateGetNameForIndex(sample, i)!) Res: %lld\n", tmp))
            }
            break
        case kIORep.kIOReportFormatSimpleArray.rawValue:
            // IOReportGetInt(sample, 2)
            for i in stride(from: 2, to: -1, by: -1) {
                print("Grp: \(group!) Subgrp: \(subgroup!) Chn: \(chann_name!) "+String(format: "Arr: %llu\n", IOReportArrayGetValueAtIndex(sample, Int32(2-i))))
            }
            break
        default:break
        }
    }
}

