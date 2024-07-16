//
//  reporter.swift
//  socpowerbuddy_swift
//
//  Created by Eom SeHwan on 1/5/24.
//

import Foundation
import ArgumentParser
import PathKit

extension String {
    var isNumber: Bool {
        return self.allSatisfy { character in
            character.isNumber
        }
    }
}

extension Collection where Indices.Iterator.Element == Index {
    subscript (safe index: Index) -> Iterator.Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

func dumpParser(dumpPath: String, vd: inout variating_data) {
    let filePath = Path(dumpPath).absolute()
    if !filePath.exists {
        print("There's no such static dump file!")
        Neoasitop.exit(withError: ExitCode(EX_OSFILE))
    }
    do {
        let dumpData: String = try filePath.read()
        let dumpArr: [String]? = dumpData.components(separatedBy: "static data\n")
        guard let dumpList = dumpArr?[safe: 1]?.components(separatedBy: "\nioreport data\n") else {
            throw ExitCode(EX_IOERR)
        }
        sdParser(sdDump: dumpList[0], sd: &sd)
        vd = vd_init(sd: sd)
        dummySensor(vd: &vd)
        dumpLoader(dumpedData: dumpList[1], vd: &vd)
        // print(dumpList)
    } catch {
        print("Cannot read the static dump file!")
        Neoasitop.exit(withError: ExitCode(EX_IOERR))
    }
}

func dummySensor(vd: inout variating_data) {
    if sd.fan_mode > 0 {
        if sd.fan_mode == 2 {
            vd.fan_speed["Left fan"] = 0
            vd.fan_speed["Right fan"] = 0
        } else if sd.fan_mode == 1 {
            vd.fan_speed["Fan #0"] = 0
        }
    }
    vd.soc_power["System Total"] = 0
}

func sdParser(sdDump: String, sd: inout static_data) {
    do {
        let staticDump: Data = Data(sdDump.utf8)
        let decoder = JSONDecoder()
        if let json = try? decoder.decode(static_data.self, from: staticDump) {
            // print(json)
            sd = json
        } else {
            throw ExitCode(EX_IOERR)
        }
    } catch {
        print("Cannot read the static dump json data!")
        Neoasitop.exit(withError: ExitCode(EX_IOERR))
    }
}

func dumpLoader(dumpedData: String, vd: inout variating_data) {
    let dumpArr = dumpedData.components(separatedBy: "\n\n")
    var dumpList: [dump_data] = []
    
    for dumpLine in dumpArr {
        if dumpLine != "" {
            var dumpData = dump_data()
            var tmpLine = Array(dumpLine.components(separatedBy: "Grp: ")[1...])
            tmpLine = tmpLine[0].components(separatedBy: " Subgrp: ")
            dumpData.grp = tmpLine[0]
            tmpLine = tmpLine[1].components(separatedBy: " Chn: ")
            dumpData.subgrp = tmpLine[0]
            if tmpLine[1].contains(" Value: ") {
                tmpLine = tmpLine[1].components(separatedBy: " Value: ")
                dumpData.chn = tmpLine[0]
                dumpData.value = CLong(tmpLine[1])
            } else if tmpLine[1].contains(" State: ") {
                tmpLine = tmpLine[1].components(separatedBy: " State: ")
                dumpData.chn = tmpLine[0]
                tmpLine = tmpLine[1].components(separatedBy: " Res: ")
                dumpData.state = tmpLine[0]
                dumpData.res = CLongLong(tmpLine[1])
            } else if tmpLine[1].contains(" Arr: ") {
                tmpLine = tmpLine[1].components(separatedBy: " Arr: ")
                dumpData.chn = tmpLine[0]
                dumpData.arr = CUnsignedLongLong(tmpLine[1])
            }
            // print("\n \(dumpData)")
            dumpList.append(dumpData)
        }
    }
    // print(dumpRep.split(separator: "\n"))
    // Neoasitop.exit(withError: ExitCode(EX_OK))
    dumpSampleTest(dumpArr: dumpList, vd: &vd)
}

func report(repData: report_data,
            vd: inout variating_data,
            cmd: cmd_data,
            test: Bool = false) {
    if test {
        // print(repData.dump_path!)
        dumpParser(dumpPath: repData.dump_path!, vd: &vd)
    } else {
        sample(iorep: repData.iorep!, sd: sd, vd: &vd, cmd: cmd)
    }
}

func dumpSampleTest(dumpArr: [dump_data], vd: inout variating_data) {
    let ptype_state    = "P"
    let vtype_state    = "V"
    let idletype_state = "IDLE"
    let offtype_state  = "OFF"
    
    var last_name: String? = ""
    var tmp_vd: variating_data? = vd
    
    for data in dumpArr {
        if data.state != nil {
            var subgroup: String?   = data.subgrp
            var idx_name: String?   = data.state
            var chann_name: String? = data.chn
            let residency = data.res ?? 0
            
            for i in 0..<sd.complex_freq_channels.count {
                if subgroup == "CPU Complex Performance States" || subgroup == "GPU Performance States" {
                    if chann_name == sd.complex_freq_channels[i] {
                        if idx_name!.contains(ptype_state) || idx_name!.contains(vtype_state) {
                            var tmp_sum: UInt64? = tmp_vd!.cluster_sums[i] + UInt64(residency)
                            var tmp_flt: Float? = Float(residency)
                            tmp_vd!.cluster_sums[i] = tmp_sum!
                            tmp_vd!.cluster_residencies[i].append(tmp_flt!)
                            tmp_sum = nil
                            tmp_flt = nil
                        } else if idx_name!.contains(idletype_state) || idx_name!.contains(offtype_state) {
                            var tmp_flt: Float? = Float(residency)
                            tmp_vd!.cluster_use[i] = tmp_flt!
                            tmp_flt = nil
                        }
                    }
                } else if subgroup == "CPU Core Performance States" {
                    if i <= sd.cluster_core_counts.count - 1 {
                        for ii in 0..<Int(sd.cluster_core_counts[i]) {
                            autoreleasepool {
                                var key: String? = String(format: "%@%d", sd.core_freq_channels[i], ii)
                                if chann_name!.starts(with: key!) {
                                    if idx_name!.contains(ptype_state) || idx_name!.contains(vtype_state) {
                                        var tmp_sum: UInt64? = tmp_vd!.core_sums[i][ii] + UInt64(residency)
                                        var tmp_flt: Float? = Float(residency)
                                        // print(tmp_flt)
                                        tmp_vd!.core_sums[i][ii] = tmp_sum!
                                        tmp_vd!.core_residencies[i][ii].append(tmp_flt!)
                                        tmp_sum = nil
                                        tmp_flt = nil
                                    } else if idx_name!.contains(idletype_state) || idx_name!.contains(offtype_state) {
                                        var tmp: UInt64? = UInt64(residency)
                                        tmp_vd!.core_use[i][ii] = tmp!
                                        tmp = nil
                                    }
                                }
                                key = nil
                            }
                        }
                    }
                }
            }
            
            chann_name = nil
            subgroup   = nil
            idx_name   = nil
        } else if data.value != nil {
            var chann_name: String? = data.chn
            var chann_name_s: String? = chann_name!.lowercased()
            
            if chann_name_s!.contains("dcs") && (chann_name_s!.contains("rd") || chann_name_s!.contains("wr")) {
                var raw: Double? = (Double(data.value!)/Double(cmd.interval/1e3))/1e9
                
                if chann_name_s! == last_name!+" wr" {
                    tmp_vd!.bandwidth_cnt[last_name!]!.append(raw!)
                } else if chann_name_s!.contains(" rd") {
                    var last_tmp: Array<String>? = chann_name_s!.components(separatedBy: " ")
                    var tmp_name: String? = last_tmp![0..<last_tmp!.count-1].joined(separator: " ")
                    var tmp: Array<Double>? = [raw!]
                    
                    tmp_vd!.bandwidth_cnt[tmp_name!] = tmp!
                    
                    last_name = tmp_name
                    last_tmp  = nil
                    tmp_name  = nil
                    tmp       = nil
                }
                
                raw = nil
            } else {
                var group: String? = data.grp
                var value: CLong?  = data.value
                
                for i in 0..<sd.complex_pwr_channels.count {
                    if group == "Energy Model" {
                        if chann_name! == sd.complex_pwr_channels[i] {
                            var tmp: Float? = Float(value!)/Float(cmd.interval/1e3)
                            tmp_vd!.cluster_pwrs[i] = tmp!
                            tmp = nil
                        }
                        
                        if i <= sd.cluster_core_counts.count-1 {
                            for ii in 0..<Int(sd.cluster_core_counts[i]) {
                                autoreleasepool {
                                    var val: String? = String(format: "%@%d", sd.core_pwr_channels[i], ii)
                                    if chann_name == val! {
                                        var tmp: Float? = Float(value!)/Float(cmd.interval/1e3)
                                        tmp_vd!.core_pwrs[i][ii] = tmp!
                                        tmp = nil
                                    }
                                    val = nil
                                }
                            }
                        }
                    }
                    
                    if sd.extra[0].lowercased().components(separatedBy: "apple m")[1].components(separatedBy: " ")[0].isNumber && group?.uppercased() == "PMP" {
                        var tmp_flt: Float? = Float(value!)/Float(cmd.interval/1e3)
                        switch chann_name?.uppercased() {
                        case "GPU":
                            tmp_vd!.cluster_pwrs[2] = tmp_flt!
                        case "ANE":
                            tmp_vd!.cluster_pwrs[3] = tmp_flt!
                        case "DRAM":
                            tmp_vd!.cluster_pwrs[4] = tmp_flt!
                        default:
                            continue
                        }
                        tmp_flt = nil
                    }
                }
                
                group = nil
                value = nil
            }
            chann_name = nil
            chann_name_s = nil
        } else if data.arr != nil {
            var chann_name: String? = data.chn
            
            for _ in 0..<sd.cluster_core_counts.count {
                var value: UInt64? = data.arr
                
                if chann_name == "CPU cycles, by cluster" {
                    var tmp: CLong? = CLong(value!)
                    tmp_vd!.cluster_instrcts_clk.append(tmp!)
                    tmp = nil
                } else if chann_name == "CPU instructions, by cluster" {
                    var tmp: CLong? = CLong(value!)
                    tmp_vd!.cluster_instrcts_ret.append(tmp!)
                    tmp = nil
                }
                value = nil
            }
            
            chann_name = nil
        }
    }
    
    vd = tmp_vd!
    tmp_vd = nil
    last_name = nil
}
