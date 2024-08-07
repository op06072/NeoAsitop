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

let cur_ver = "v2.11"
var newVersion = false
var beta = false

struct Neoasitop: ParsableCommand {
    @Flag(name: .shortAndLong, help: "Print version information")
    var version = false
    
    @Flag(name: .long, help: "Show detail information of this system like OS codename, CPU architecture name, etc.")
    var verbose = false
    
    @Flag(name: .shortAndLong, help: "Test the features with dumped file from iorepdump.")
    var test = false
    
    @Option(name: .shortAndLong, help: "Display interval and sampling interval for info gathering (seconds) [0.01~]")
    var interval: Double = 1
    
    @Option(name: .shortAndLong, help: "Choose display color (0~7)")
    var color: UInt8 = 2
    
    @Option(name: .long, help: "Interval for averaged values (seconds)")
    var avg: Double = 30
    
    @Option(name: .shortAndLong, help: "Path of the dumped file.")
    var dump = ""
    
    mutating func run() throws {
        if version {
            print(cur_ver)
        } else {
            if test && dump == "" {
                print("Please give the dump file path with dump option for using test option.")
                Neoasitop.exit(withError: ExitCode(EX_USAGE))
            }
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
        
        sd.verbosed = verbose

        staticInit(sd: &sd)

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
        let fan_set = sd.fan_exist
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
        
        var pwr_max: peak_pwr = peak_pwr()
        var pwr_avg: avg_pwr = avg_pwr()
        
        sens.read()
        if fan_set {
            generateFanLimit(sd: &sd, sense: sens.value!.sensors)
        }

        while true {
            autoreleasepool {
                var rd: render_data? = render_data()
                var vd: variating_data? = vd_init(sd: sd)
                sens.read()
                getSensorVal(vd: &vd!, sd: &sd, sense: sens.value!.sensors) // sensor value
                getMemUsage(vd: &vd!)
                sd.ram_capacity = "\(Int(vd!.mem_stat.total[0]))\(ByteUnit(vd!.mem_stat.total[1]))"
                monInfo = dispInfo(sd: sd)
                monInfo.cpu_pwr.val = cpu_pwr
                monInfo.gpu_pwr.val = gpu_pwr
                
                monInfo.sys_pwr_max = pwr_max.sys
                monInfo.cpu_pwr_max = pwr_max.cpu
                monInfo.gpu_pwr_max = pwr_max.gpu
                monInfo.ram_pwr_max = pwr_max.ram
                
                monInfo.sys_pwr_avg = pwr_avg.sys
                monInfo.cpu_pwr_avg = pwr_avg.cpu
                monInfo.gpu_pwr_avg = pwr_avg.gpu
                monInfo.ram_pwr_avg = pwr_avg.ram
                
                
                let repData = test ? report_data(dump_path: dump) : report_data(iorep: iorep)
                
                report(repData: repData, vd: &vd!, cmd: cmd, test: test) // 데이터 샘플링 (애플 비공개 함수 이용)
                // print("sampling finish")
                format(sd: &sd, vd: &vd!) // 포매팅
                // print("formatting finish")
                summary(sd: sd, vd: vd!, rd: &rd!, rvd: &monInfo, opt: avg)
                
                pwr_max.sys = monInfo.sys_pwr_max
                pwr_max.cpu = monInfo.cpu_pwr_max
                pwr_max.gpu = monInfo.gpu_pwr_max
                pwr_max.ram = monInfo.ram_pwr_max
                
                pwr_avg.sys = monInfo.sys_pwr_avg
                pwr_avg.cpu = monInfo.cpu_pwr_avg
                pwr_avg.gpu = monInfo.gpu_pwr_avg
                pwr_avg.ram = monInfo.ram_pwr_avg
                
                rd = nil
                vd = nil
            }
            
            cpu_pwr = monInfo.cpu_pwr.val
            gpu_pwr = monInfo.gpu_pwr.val
            // print("summarize finish")
            
            switch getch() {
            // Wait for user input
            // Exit on 'q'
            case Int32(UnicodeScalar("q").value):
                fin(scr: &scr)
                print("\nGood Bye\(beta ? " Beta User!" : "!")")
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
            if test {
                fin(scr: &scr)
                print("\nGood Bye Test User!")
                return
            }
            Thread.sleep(forTimeInterval: interval-(cmd.interval*1e-3))
        }
    }
    
    func fin(scr: inout tbox) {
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
                    } else if version.compare(cur_ver, options: .numeric) == .orderedAscending {
                        beta = true
                    }
                }
            }
            Neoasitop.main()
        case .failure:
            Neoasitop.main()
        }
    }
}
