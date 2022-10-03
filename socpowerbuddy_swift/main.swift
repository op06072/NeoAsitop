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

if run(bash: "xcode-select -p 1>/dev/null;echo $?").stdout == "2" {
    print("Please Install the Xcode Command Line Tools first.")
    print("You can install this with:")
    print("xcode-select --install")
    exit(1)
}

struct NeoasitopOptions: ParsableArguments {
    @Option(name: .shortAndLong, help: "Display interval and sampling interval for info gathering (seconds)")
    var interval: Double = 1
    
    @Option(name: .shortAndLong, help: "Choose display color (0~8)")
    var color: UInt8 = 2
    
    @Option(name: .long, help: "Interval for averaged values (seconds)")
    var avg: Double = 30
}

let options = NeoasitopOptions.parseOrExit()

var iorep = iorep_data()
var sd = static_data()
var cmd = cmd_data()
var rendering = renderer()
var rvd = render_value_data()

print("\nNeoAsitop - Sudoless performance monitoring CLI tool for Apple Silicon")
print("Get help at `https://github.com/op06072/NeoAsitop`")
print("Thanks to all the projects that inspired and referenced.")
print("\n [1/2] Loading NeoAsitop\n")

cmd.interval = 175
cmd.samples = 1

while cmd.interval/1000 >= options.interval {
    cmd.interval /= 2
}

var cpu_peak_pwr: Float = 0
var gpu_peak_pwr: Float = 0
var system_peak_pwr: Float = 0
var cpu_avg_pwr_list: [Float] = []
var gpu_avg_pwr_list: [Float] = []
var system_avg_pwr_list: [Float] = []

let procInfo = ProcessInfo()
let systemVersion = procInfo.operatingSystemVersion
sd.os_ver = "macOS \(systemVersion.majorVersion).\(systemVersion.minorVersion)"

generateDvfmTable(sd: &sd)
generateProcessorName(sd: &sd)

var tmp = sd.extra[0].lowercased()
//tmp = "m1 ultra"
if tmp.contains("pro") || tmp.contains("max") {
    sd.complex_pwr_channels = ["EACC_CPU", "PACC0_CPU", "PACC1_CPU", "GPU0", "ANE0", "DRAM0"]
    sd.core_pwr_channels = ["EACC_CPU", "PACC0_CPU", "PACC1_CPU"]
    
    sd.complex_freq_channels = ["ECPU", "PCPU", "PCPU1", "GPUPH"]
    sd.core_freq_channels = ["ECPU0", "PCPU0", "PCPU1"]
    
    let ttmp = sd.dvfm_states_holder
    sd.dvfm_states = [ttmp[0], ttmp[1], ttmp[1], ttmp[2]]
} else if tmp.contains("ultra") {
    sd.complex_pwr_channels = ["DIE_0_EACC_CPU", "DIE_1_EACC_CPU", "DIE_0_PACC0_CPU", "DIE_0_PACC1_CPU", "DIE_1_PACC0_CPU", "DIE_1_PACC1_CPU", "GPU0_0", "ANE0_0", "ANE0_1", "DRAM0_0", "DRAM0_1"]
    sd.core_pwr_channels = ["DIE_0_EACC_CPU", "DIE_1_EACC_CPU", "DIE_0_PACC0_CPU", "DIE_0_PACC1_CPU", "DIE_1_PACC0_CPU", "DIE_1_PACC1_CPU"]
    
    sd.complex_freq_channels = ["DIE_0_ECPU", "DIE_1_ECPU", "DIE_0_PCPU", "DIE_0_PCPU1", "DIE_1_PCPU", "DIE_1_PCPU1", "GPUPH"]
    sd.core_freq_channels = ["DIE_0_ECPU_CPU", "DIE_1_ECPU_CPU", "DIE_0_PCPU_CPU", "DIE_0_PCPU1_CPU", "DIE_1_PCPU_CPU", "DIE_1_PCPU1_CPU"]
    
    let ttmp = sd.dvfm_states_holder
    sd.dvfm_states = [ttmp[0], ttmp[0], ttmp[1], ttmp[1], ttmp[1], ttmp[1], ttmp[2]]
} else {
    sd.complex_pwr_channels = ["ECPU", "PCPU", "GPU", "ANE", "DRAM"]
    sd.core_pwr_channels = ["ECPU", "PCPU"]
    
    sd.complex_freq_channels = ["ECPU", "PCPU", "GPUPH"]
    sd.core_freq_channels = ["ECPU", "PCPU"]
    
    let ttmp = sd.dvfm_states_holder
    sd.dvfm_states = [ttmp[0], ttmp[1], ttmp[2]]
}
generateCoreCounts(sd: &sd)
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
var fan_set = sd.fan_exist

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
    //print("formatting finish")
    summary(sd: sd, vd: vd, rd: &rd, rvd: &rvd, opt: options.avg)
    //print("summarize finish")
    rendering.term_layout(sd: sd, colr: options.color) // 레이아웃 렌더링
    //print("layout render finish")
    eraseScreen()
    rendering.term_rendering(sd: sd, vd: vd, rvd: rvd) // 정보 출력
    Thread.sleep(forTimeInterval: options.interval-(cmd.interval*1e-3))
}
