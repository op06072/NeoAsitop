//
//  neoasitop.swift
//  socpowerbuddy_swift
//
//  Created by Eom SeHwan on 2023/01/21.
//

import Alamofire
import Foundation
import IOKit.graphics
import ArgumentParser

var iorep = iorep_data()
var sd = static_data()
var cmd = cmd_data()
let sens = SensorsReader()

let cur_ver = "v2.7"
var newVersion = false

struct Neoasitop: ParsableCommand {
    @Flag(name: .shortAndLong, help: "Print version information")
    var version = false
    
    @Option(name: .shortAndLong, help: "Display interval and sampling interval for info gathering (seconds)")
    var interval: Double = 1
    
    @Option(name: .shortAndLong, help: "Choose display color (0~7)")
    var color: UInt8 = 2
    
    @Option(name: .long, help: "Interval for averaged values (seconds)")
    var avg: Double = 30
    
    func run() throws {
        if version {
            print(cur_ver)
        } else {
            launch()
            if newVersion {
                print("New version is released! Please update the NeoAsitop.")
            }
        }
        Neoasitop.exit(withError: ExitCode(EX_OK))
    }
    
    func launch() {
        
        print("\nNeoAsitop - Sudoless performance monitoring CLI tool for Apple Silicon")
        print("Get help at `https://github.com/op06072/NeoAsitop`")
        print("Thanks to all the projects that inspired and referenced.")
        print("\n [1/2] Loading NeoAsitop\n")

        cmd.interval = 175
        cmd.samples = 1

        while cmd.interval/1000 >= interval {
            cmd.interval /= 2
        }

        let procInfo = ProcessInfo()
        let systemVersion = procInfo.operatingSystemVersion
        sd.os_ver = "macOS \(systemVersion.majorVersion).\(systemVersion.minorVersion)"

        generateDvfmTable(sd: &sd)
        //print("dvfm table gen finish")
        generateProcessorName(sd: &sd)
        //print("process name gen finish")

        let tmp = sd.extra[0].lowercased()
        //tmp = "m1 ultra"
        if tmp.contains("virtual") {
            print("You can't use this tool on apple virtual machine.")
            Neoasitop.exit(withError: ExitCode(2))
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

        iorep.cpusubchn  = nil
        iorep.pwrsubchn  = nil
        iorep.clpcsubchn = nil
        iorep.bwsubchn   = nil
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

        iorep.cpuchn_cpu = nil
        iorep.cpuchn_gpu = nil
        iorep.pwrchn_eng = nil
        iorep.pwrchn_pmp = nil
        iorep.clpcchn    = nil
        iorep.bwchn      = nil

        print("\n [2/2] Gathering System Info\n")
        var fan_set = sd.fan_exist
        gen_screen()
        //print("gen screen")
        var monInfo = dispInfo(sd: sd)
        //print("monitor Info")
        var cpu_pwr = monInfo.cpu_pwr.val
        var gpu_pwr = monInfo.gpu_pwr.val
        var xy: [Int32] = [0, 0]
        var scrin: refreshInfo? = display(monInfo, true, nil, xy, color) // 레이아웃 렌더링
        //print("layout finish")
        var scr = scrin!.tbx
        var bottomPnt: OpaquePointer? = nil
        xy = scrin!.xy

        while true {
            autoreleasepool {
                var rd: render_data? = render_data()
                var vd: variating_data? = vd_init(sd: sd)
                sens.read()
                if fan_set {
                    getSensorVal(vd: &vd!, set_mode: fan_set, sd: &sd, sense: sens.list) // 센서값
                    fan_set = false
                } else {
                    getSensorVal(vd: &vd!, sd: &sd, sense: sens.list) // 센서값
                }
                getMemUsage(vd: &vd!)
                sd.ram_capacity = "\(Int(vd!.mem_stat.total[0]))\(ByteUnit(vd!.mem_stat.total[1]))"
                monInfo = dispInfo(sd: sd)
                monInfo.cpu_pwr.val = cpu_pwr
                monInfo.gpu_pwr.val = gpu_pwr
                
                sample(iorep: iorep, sd: sd, vd: &vd!, cmd: cmd) // 데이터 샘플링 (애플 비공개 함수 이용)
                //print("sampling finish")
                format(sd: &sd, vd: &vd!) // 포매팅
                //print("formatting finish")
                summary(sd: sd, vd: vd!, rd: &rd!, rvd: &monInfo, opt: avg)
                rd = nil
                vd = nil
            }
            
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
                print("\nGood Bye")
                return
            default:
                autoreleasepool {
                    scrin = display(monInfo, false, scr, xy, color, bottomPnt) // 정보 출력
                    scr = scrin!.tbx
                    xy = scrin!.xy
                    bottomPnt = scrin!.bottom
                    scrin = nil
                }
                wclear(scr.t.win)
                //print("render finish")
            }
            Thread.sleep(forTimeInterval: interval-(cmd.interval*1e-3))
        }
    }
}

@main
enum Executable {
    static func main() async throws {
        let headers: HTTPHeaders = [
            .accept("application/vnd.github+json")
        ]
        let dataTask = AF.request(
            "https://api.github.com/repos/op06072/NeoAsitop/releases/latest",
            headers: headers
        ).serializingData()
        switch await dataTask.result {
        case .success(let value):
            if let object = try? JSONSerialization.jsonObject(
                with: value, options: []
            ) as? NSDictionary {
                if let version = object.value(forKey: "tag_name") as? String {
                    if version.compare(cur_ver, options: .numeric) == .orderedDescending {
                        newVersion = true
                    }
                }
            }
            Neoasitop.main()
        case .failure:
            Neoasitop.main()
        }
    }
}
