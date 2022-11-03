//
//  main.swift
//  socpowerbuddy_swift
//
//  Created by Eom SeHwan on 2022/09/14.
//

import Foundation
import IOKit.graphics
import ArgumentParser

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
//print("dvfm table gen finish")
generateProcessorName(sd: &sd)
//print("process name gen finish")

var tmp = sd.extra[0].lowercased()
//tmp = "m1 ultra"
if tmp.contains("virtual") {
    print("You can't use this tool on apple virtual machine.")
    exit(2)
} else if tmp.contains("pro") || tmp.contains("max") {
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
//print("channel name table gen finish")
generateCoreCounts(sd: &sd)
//print("core counting finish")
generateSiliconsIds(sd: &sd)
//print("id gen finish")
generateMicroArchs(sd: &sd)
//print("arch get finish")

if sd.extra[0].lowercased().contains("apple") {
    var size = 0
    let getarch = "sysctl.proc_translated"
    sysctlbyname(getarch, nil, &size, nil, 0)
    var mode = 0
    sysctlbyname(getarch, &mode, &size, nil, 0)
    if mode == 0 {
        sd.extra.append("Apple")
    } else if mode == 1 {
        sd.extra.append("Rosetta 2")
    }
}

generateSocMax(sd: &sd)
//print("soc max gen finish")
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
    iorep.cpuchn_gpu?.takeRetainedValue(),
    nil
)
IOReportMergeChannels(
    iorep.pwrchn_eng?.takeUnretainedValue(),
    iorep.pwrchn_pmp?.takeRetainedValue(),
    nil
)

iorep.cpusub = IOReportCreateSubscription(
    nil, iorep.cpuchn_cpu?.takeRetainedValue(),
    &iorep.cpusubchn, 0, nil
)
iorep.pwrsub = IOReportCreateSubscription(
    nil, iorep.pwrchn_eng?.takeRetainedValue(),
    &iorep.pwrsubchn, 0, nil
)
iorep.clpcsub = IOReportCreateSubscription(
    nil, iorep.clpcchn?.takeRetainedValue(),
    &iorep.clpcsubchn, 0, nil
)
iorep.bwsub = IOReportCreateSubscription(
    nil, iorep.bwchn?.takeRetainedValue(),
    &iorep.bwsubchn, 0, nil
)

print("\n [2/2] Gathering System Info\n")
var fan_set = sd.fan_exist
gen_screen()
//print("gen screen")
var monInfo = dispInfo(sd: sd)
//print("monitor Info")
var cpu_pwr = monInfo.cpu_pwr.val
var gpu_pwr = monInfo.gpu_pwr.val
var xy: [Int32] = [0, 0]
var scrin = display(monInfo, true, nil, xy, options.color) // 레이아웃 렌더링
//print("layout finish")
var scr = scrin.tbx
xy = scrin.xy

while true {
    autoreleasepool {
        var rd = render_data()
        var vd = vd_init(sd: sd)
        if fan_set {
            getSensorVal(vd: &vd, set_mode: fan_set, sd: &sd) // 센서값
            fan_set = false
        } else {
            getSensorVal(vd: &vd, sd: &sd) // 센서값
        }
        getMemUsage(vd: &vd)
        sd.ram_capacity = "\(Int(vd.mem_stat.total[0]))\(ByteUnit(vd.mem_stat.total[1]))"
        monInfo = dispInfo(sd: sd)
        monInfo.cpu_pwr.val = cpu_pwr
        monInfo.gpu_pwr.val = gpu_pwr
        
        sample(iorep: iorep, sd: sd, vd: &vd, cmd: cmd) // 데이터 샘플링 (애플 비공개 함수 이용)
        //print("sampling finish")
        format(sd: &sd, vd: &vd) // 포매팅
        //print("formatting finish")
        summary(sd: sd, vd: vd, rd: &rd, rvd: &monInfo, opt: options.avg)
        cpu_pwr = monInfo.cpu_pwr.val
        gpu_pwr = monInfo.gpu_pwr.val
        //print("summarize finish")
        
        switch getch() {
        // Wait for user input
        // Exit on 'q'
        case Int32(UnicodeScalar("q").value):
            endwin()
            if scr.items.count != 0 {
                if scr.items[0].items.count != 0 {
                    if sd.fan_exist {
                        del_tbox(tbx: &scr.items[0].items[2].items[0])
                    }
                    for i in (0...2).reversed() {
                        del_tbox(tbx: &scr.items[0].items[i])
                    }
                }
                if scr.items[1].items.count != 0 {
                    for i in (0...1).reversed() {
                        del_tbox(tbx: &scr.items[1].items[i])
                    }
                }
                for i in 0...2 {
                    del_tbox(tbx: &scr.items[i])
                }
            }
            del_tbox(tbx: &scr)
            exit(EX_OK)
        default:
            scrin = display(monInfo, false, scr, xy, options.color) // 정보 출력
            scr = scrin.tbx
            xy = scrin.xy
            wclear(scr.t.win)
            
            //dfs_kill(tbx: &scr)
            
            var first_box = 1
            if fan_set {
                del_tbox(tbx: &scr.items[0].items[2].items[0])
                first_box = 2
            }
            for i in (0...first_box).reversed() {
                del_tbox(tbx: &scr.items[0].items[i])
            }
            for i in (0...1).reversed() {
                del_tbox(tbx: &scr.items[1].items[i])
            }
            for i in 0...2 {
                del_tbox(tbx: &scr.items[i])
            }
            del_tbox(tbx: &scr)
            //print("render finish")
        }
        Thread.sleep(forTimeInterval: options.interval-(cmd.interval*1e-3))
    }
}
