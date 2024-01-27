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

// dump static_data
var sd = static_data()

staticInit(sd: &sd)

// sensor reader
let sens = SensorsReader()
sens.read()
if sd.fan_exist {
    generateFanLimit(sd: &sd, sense: sens.value!.sensors)
}

print("static data")

let encoder = JSONEncoder()
encoder.outputFormatting = .prettyPrinted

do {
    let data = try encoder.encode(sd)  //convert user to json data here
    print(String(data: data, encoding: .utf8)!)   //print to console
} catch {
    print("fail")
}

// dump ioreport
var cpu = sd.extra[0]
var clusters = 2

cpu = cpu.lowercased()

clusters = sd.cluster_core_counts.count

var subchn: Unmanaged<CFMutableDictionary>? = nil
var chn = IOReportCopyAllChannels(0, 0)
var sub = IOReportCreateSubscription(nil, chn?.takeRetainedValue(), &subchn, 0, nil)

let interval: Double = 175

var samples_a = IOReportCreateSamples(sub, subchn?.takeUnretainedValue(), nil)

Thread.sleep(forTimeInterval: interval*1e-3)

var samples_b = IOReportCreateSamples(sub, subchn?.takeUnretainedValue(), nil)

let samp_delta = IOReportCreateSamplesDelta(samples_a?.takeUnretainedValue(), samples_b?.takeUnretainedValue(), nil)

samples_a?.release()
samples_b?.release()

let names = ["CPU Stats", "GPU Stats", "AMC Stats", "CLPC Stats", "PMP", "Energy Model"]
print("ioreport data")
IOReportIterate(samp_delta?.takeUnretainedValue(), { sample in
    autoreleasepool {
        var group = IOReportChannelGetGroup(sample)
        var subgroup = IOReportChannelGetSubGroup(sample)
        var chann_name = IOReportChannelGetChannelName(sample)
        if names.contains(group!) {
            switch IOReportChannelGetFormat(sample) {
            case kIORep.kIOReportFormatSimple.rawValue:
                var tmp: Int? = IOReportSimpleGetIntegerValue(sample, 0)
                print("Grp: \(group!) Subgrp: \(subgroup ?? "") Chn: \(chann_name!) "+String(format: "Value: %ld\n", tmp!))
                tmp = nil
            case kIORep.kIOReportFormatState.rawValue:
                for i in 0..<IOReportStateGetCount(sample) {
                    var tmp: UInt64? = IOReportStateGetResidency(sample, i)
                    var idx = IOReportStateGetNameForIndex(sample, i)
                    print("Grp: \(group!) Subgrp: \(subgroup!) Chn: \(chann_name!) "+String(format: "State: \(idx!) Res: %lld\n", tmp!))
                    tmp = nil
                    idx = nil
                }
            case kIORep.kIOReportFormatSimpleArray.rawValue:
                for i in 0..<clusters {
                    var idx: UInt64? = IOReportArrayGetValueAtIndex(sample, Int32(2-i))
                    print("Grp: \(group!) Subgrp: \(subgroup!) Chn: \(chann_name!) "+String(format: "Arr: %llu\n", idx!))
                    idx = nil
                }
            default: break
            }
        }
        group = nil
        subgroup = nil
        chann_name = nil
    }
    return Int32(kIOReportIterOk)
})
