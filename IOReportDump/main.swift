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
var sub = IOReportCreateSubscription(nil, chn?.takeRetainedValue(), &subchn, 0, nil)

let interval: Double = 175

var samples_a = IOReportCreateSamples(sub, subchn?.takeUnretainedValue(), nil).takeRetainedValue()

Thread.sleep(forTimeInterval: interval*1e-3)

var samples_b = IOReportCreateSamples(sub, subchn?.takeUnretainedValue(), nil).takeRetainedValue()

let samp_delta = Array((IOReportCreateSamplesDelta(
    samples_a, samples_b, nil
).takeRetainedValue() as Dictionary).values)[0] as! Array<CFDictionary>

for sample in samp_delta {
    let group = IOReportChannelGetGroup(sample)
    var subgroup = IOReportChannelGetSubGroup(sample)
    let chann_name = IOReportChannelGetChannelName(sample)
    let names = ["CPU Stats", "GPU Stats", "AMC Stats", "CLPC Stats", "PMP", "Energy Model"]
    if names.contains(group!) {
        switch IOReportChannelGetFormat(sample) {
        case kIORep.kIOReportFormatSimple.rawValue:
            if subgroup == nil {
                subgroup = ""
            }
            print("Grp: \(group!) Subgrp: \(subgroup!) Chn: \(chann_name!) "+String(format: "Value: %ld\n", IOReportSimpleGetIntegerValue(sample, 0)))
            break
        case kIORep.kIOReportFormatState.rawValue:
            for i in 0..<IOReportStateGetCount(sample) {
                let tmp = IOReportStateGetResidency(sample, i)
                print("Grp: \(group!) Subgrp: \(subgroup!) Chn: \(chann_name!) "+String(format: "State: \(IOReportStateGetNameForIndex(sample, i)!) Res: %lld\n", tmp))
            }
            break
        case kIORep.kIOReportFormatSimpleArray.rawValue:
            for i in stride(from: 2, to: -1, by: -1) {
                print("Grp: \(group!) Subgrp: \(subgroup!) Chn: \(chann_name!) "+String(format: "Arr: %llu\n", IOReportArrayGetValueAtIndex(sample, Int32(2-i))))
            }
            break
        default:break
        }
    }
}

