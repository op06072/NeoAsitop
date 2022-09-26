//
//  main.swift
//  socpowerbuddy_swift
//
//  Created by Eom SeHwan on 2022/09/14.
//

import Foundation
import IOKit.graphics
import SwiftShell
import ArgumentParser

struct NeoasitopOptions: ParsableArguments {
    @Option(name: .shortAndLong, help: "Display interval and sampling interval for info gathering (seconds)")
    var interval = 1
    
    @Option(name: .shortAndLong, help: "Choose display color (0~8)")
    var color: UInt8 = 2
    
    @Option(name: .long, help: "Interval for averaged values (seconds)")
    var avg = 30
}

let options = NeoasitopOptions.parseOrExit()

var iorep = iorep_data()
var sd = static_data()
var cmd = cmd_data()
var rendering = renderer()
var rvd = render_value_data()
var fan_set = true

let color = options.color
let avg = Double(options.avg)
let interval = Double(options.interval)

print("\nNeoAsitop - Sudoless performance monitoring CLI tool for Apple Silicon")
print("Get help at `https://github.com/op06072/NeoAsitop")
print("Thanks to all the projects that inspired and referenced.")
print("\n [1/2] Loading NeoAsitop\n")

cmd.interval = 175
cmd.samples = 1

generateDvfmTable(sd: &sd)
generateCoreCounts(sd: &sd)
generateProcessorName(sd: &sd)
generateSiliconsIds(sd: &sd)
generateMicroArchs(sd: &sd)

if sd.extra[0].lowercased().contains("apple") {
    if run(bash: "uname -m").stdout.lowercased() == "arm64" {
        sd.extra.append("Apple")
    } else {
        sd.extra.append("Rosetta 2")
    }
}

generateSocMax(sd: &sd)
sd.max_pwr.append(8)
sd.max_bw.append(7)

var cpu_peak_pwr: Float = 0
var gpu_peak_pwr: Float = 0
var system_peak_pwr: Float = 0
var cpu_avg_pwr_list: [Float] = []
var gpu_avg_pwr_list: [Float] = []
var system_avg_pwr_list: [Float] = []

var tmp = sd.extra[0].lowercased()
if tmp.contains("pro") || tmp.contains("max") {
    sd.complex_pwr_channels = ["EACC_CPU", "PACC0_CPU", "PACC1_CPU", "GPU0", "ANE0", "DRAM0"]
    sd.core_pwr_channels = ["EACC_CPU", "PACC0_CPU", "PACC1_CPU"]
    
    sd.complex_freq_channels = ["ECPU", "PCPU", "PCPU1", "GPUPH"]
    sd.core_freq_channels = ["ECPU0", "PCPU0", "PCPU1"]
    
    let ttmp = sd.dvfm_states_holder
    sd.dvfm_states = [ttmp[0], ttmp[1], ttmp[1], ttmp[2]]
} else if tmp.contains("ultra") {
    sd.complex_pwr_channels = ["EACC_CPU0", "EACC_CPU1", "PACC0_CPU", "PACC1_CPU", "PACC2_CPU", "PACC3_CPU", "GPU0", "ANE0", "DRAM0"]
    sd.core_pwr_channels = ["EACC_CPU0", "EACC_CPU1", "PACC0_CPU", "PACC1_CPU", "PACC2_CPU", "PACC3_CPU"]
    
    sd.complex_freq_channels = ["ECPU", "ECPU1", "PCPU", "PCPU1", "PCPU2", "PCPU3", "GPUPH"]
    sd.core_freq_channels = ["ECPU0", "ECPU1", "PCPU0", "PCPU1", "PCPU2", "PCPU3"]
    
    let ttmp = sd.dvfm_states_holder
    sd.dvfm_states = [ttmp[0], ttmp[1], ttmp[1], ttmp[1], ttmp[1], ttmp[2]]
} else {
    sd.complex_pwr_channels = ["ECPU", "PCPU", "GPU", "ANE", "DRAM"]
    sd.core_pwr_channels = ["ECPU", "PCPU"]
    
    sd.complex_freq_channels = ["ECPU", "PCPU", "GPUPH"]
    sd.core_freq_channels = ["ECPU", "PCPU"]
    
    let ttmp = sd.dvfm_states_holder
    sd.dvfm_states = [ttmp[0], ttmp[1], ttmp[2]]
}

iorep.cpusubchn = nil
iorep.pwrsubchn = nil
iorep.clpcsubchn = nil
iorep.bwsubchn = nil
iorep.cpuchn_cpu = IOReportCopyChannelsInGroup("CPU Stats", nil, 0, 0, 0)
iorep.cpuchn_gpu = IOReportCopyChannelsInGroup("GPU Stats", nil, 0, 0, 0)
iorep.pwrchn_eng = IOReportCopyChannelsInGroup("Energy Model", nil, 0, 0, 0)
iorep.pwrchn_pmp = IOReportCopyChannelsInGroup("PMP", nil, 0, 0, 0)
iorep.clpcchn = IOReportCopyChannelsInGroup("CLPC Stats", nil, 0, 0, 0)
iorep.bwchn = IOReportCopyChannelsInGroup("AMC Stats", nil, 0, 0, 0)

IOReportMergeChannels(
    iorep.cpuchn_cpu?.takeUnretainedValue(),
    iorep.cpuchn_gpu?.takeUnretainedValue(),
    nil
)
IOReportMergeChannels(
    iorep.pwrchn_eng?.takeUnretainedValue(),
    iorep.pwrchn_pmp?.takeUnretainedValue(),
    nil
)

iorep.cpusub = IOReportCreateSubscription(
    nil, iorep.cpuchn_cpu?.takeUnretainedValue(),
    &iorep.cpusubchn, 0, nil
)
iorep.pwrsub = IOReportCreateSubscription(
    nil, iorep.pwrchn_eng?.takeUnretainedValue(),
    &iorep.pwrsubchn, 0, nil
)
iorep.clpcsub = IOReportCreateSubscription(
    nil, iorep.clpcchn?.takeUnretainedValue(),
    &iorep.clpcsubchn, 0, nil
)
iorep.bwsub = IOReportCreateSubscription(
    nil, iorep.bwchn?.takeUnretainedValue(),
    &iorep.bwsubchn, 0, nil
)

print("\n [2/2] Gathering System Info\n")

while true {
    var rd = render_data()
    var vd = vd_init(sd: sd)
    if fan_set {
        getSensorVal(vd: &vd, set_mode: fan_set, sd: &sd) // 센서값
        fan_set = false
    } else {
        getSensorVal(vd: &vd, sd: &sd) // 센서값
    }
    getMemUsage(vd: &vd)
    sd.ram_capacity = Int(vd.mem_stat.total)
    
    sample(iorep: iorep, sd: sd, vd: &vd, cmd: cmd) // 데이터 샘플링 (애플 비공개 함수 이용)
    format(sd: &sd, vd: &vd) // 포매팅
    summary(sd: sd, vd: vd, rd: &rd, rvd: &rvd, opt: [avg, interval])
    rendering.term_layout(sd: sd, colr: color) // 레이아웃 렌더링
    eraseScreen()
    rendering.term_rendering(sd: sd, vd: vd, rvd: rvd) // 정보 출력
    Thread.sleep(forTimeInterval: interval-(cmd.interval*1e-3))
}
