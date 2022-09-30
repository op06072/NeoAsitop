//
//  sampler.swift
//  socpowerbuddy_swift
//
//  Created by Eom SeHwan on 2022/09/15.
//

import Foundation
import PythonKit
import Darwin
import SwiftShell

func sample(iorep: iorep_data,
            sd: static_data,
            vd: inout variating_data,
            cmd: cmd_data) {
    autoreleasepool {
        let ptype_state = "P"
        let vtype_state = "V"
        let idletype_state = "IDLE"
        let offtype_state = "OFF"
        
        let cpusamp_a = IOReportCreateSamples(
            iorep.cpusub, iorep.cpusubchn?.takeUnretainedValue(), nil
        ).takeUnretainedValue()
        let pwrsamp_a = IOReportCreateSamples(
            iorep.pwrsub, iorep.pwrsubchn?.takeUnretainedValue(), nil
        ).takeUnretainedValue()
        let clpcsamp_a = IOReportCreateSamples(
            iorep.clpcsub, iorep.clpcsubchn?.takeUnretainedValue(), nil
        ).takeUnretainedValue()
        let bwsamp_a = IOReportCreateSamples(
            iorep.bwsub, iorep.bwsubchn?.takeUnretainedValue(), nil
        ).takeUnretainedValue()
        
        if cmd.interval > 0 {
            Thread.sleep(forTimeInterval: cmd.interval*1e-3)
        }
        
        let cpusamp_b = IOReportCreateSamples(
            iorep.cpusub, iorep.cpusubchn?.takeUnretainedValue(), nil
        ).takeUnretainedValue()
        let pwrsamp_b = IOReportCreateSamples(
            iorep.pwrsub, iorep.pwrsubchn?.takeUnretainedValue(), nil
        ).takeUnretainedValue()
        let clpcsamp_b = IOReportCreateSamples(
            iorep.clpcsub, iorep.clpcsubchn?.takeUnretainedValue(), nil
        ).takeUnretainedValue()
        let bwsamp_b = IOReportCreateSamples(
            iorep.bwsub, iorep.bwsubchn?.takeUnretainedValue(), nil
        ).takeUnretainedValue()
        
        let cpu_delta = Array((IOReportCreateSamplesDelta(
            cpusamp_a, cpusamp_b, nil
        ).takeUnretainedValue() as Dictionary).values)[0] as! Array<CFDictionary>
        let pwr_delta = Array((IOReportCreateSamplesDelta(
            pwrsamp_a, pwrsamp_b, nil
        ).takeUnretainedValue() as Dictionary).values)[0] as! Array<CFDictionary>
        let clpc_delta = Array((IOReportCreateSamplesDelta(
            clpcsamp_a, clpcsamp_b, nil
        ).takeUnretainedValue() as Dictionary).values)[0] as! Array<CFDictionary>
        let bw_delta = Array((IOReportCreateSamplesDelta(
            bwsamp_a, bwsamp_b, nil
        ).takeUnretainedValue() as Dictionary).values)[0] as! Array<CFDictionary>
        
        for sample in cpu_delta {
            for i in stride(from: 0, to: IOReportStateGetCount(sample), by: 1) {
                let subgroup = IOReportChannelGetSubGroup(sample)
                let idx_name = IOReportStateGetNameForIndex(sample, i)
                let chann_name = IOReportChannelGetChannelName(sample)
                let residency = IOReportStateGetResidency(sample, i)
                
                for ii in 0..<sd.complex_freq_channels.count {
                    if subgroup == "CPU Complex Performance States" || subgroup == "GPU Performance States" {
                        if chann_name == sd.complex_freq_channels[ii] {
                            if idx_name!.contains(ptype_state) || idx_name!.contains(vtype_state) {
                                vd.cluster_sums[ii] += residency
                                vd.cluster_residencies[ii].append(Float(residency))
                            } else if idx_name!.contains(idletype_state) || idx_name!.contains(offtype_state) {
                                vd.cluster_use[ii] = Float(residency)
                            }
                        }
                    } else if subgroup == "CPU Core Performance States" {
                        if ii <= sd.cluster_core_counts.count-1 {
                            for iii in 0..<Int(sd.cluster_core_counts[ii]) {
                                if chann_name == String(format: "%@%d", sd.core_freq_channels[ii], iii) {
                                    if idx_name!.contains(ptype_state) || idx_name!.contains(vtype_state) {
                                        vd.core_sums[ii][iii] += residency
                                        vd.core_residencies[ii][iii].append(Float(residency))
                                    } else if idx_name!.contains(idletype_state) || idx_name!.contains(offtype_state) {
                                        vd.core_use[ii][iii] = residency
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        //var package = 0
        for sample in pwr_delta {
            let chann_name = IOReportChannelGetChannelName(sample)
            let group = IOReportChannelGetGroup(sample)
            let value = IOReportSimpleGetIntegerValue(sample, 0)
            
            /*if group == "Energy Model" {
                if chann_name!.lowercased().contains("energy") == false {
                    package += value
                }
            }*/
            
            for ii in 0..<sd.complex_pwr_channels.count {
                /*if group == "PMP" {
                    if chann_name!.contains("RD") && (chann_name!.contains("BW") == false) && (value > 0) {
                        let samp = sample as Dictionary
                        print()
                    }
                }*/
                if group == "Energy Model" {
                    if chann_name == sd.complex_pwr_channels[ii] {
                        vd.cluster_pwrs[ii] = Float(value)/Float(cmd.interval/1e+3)
                    }
                        
                    if ii <= sd.cluster_core_counts.count-1 {
                        for iii in 0..<Int(sd.cluster_core_counts[ii]) {
                            if chann_name == String(format: "%@%d", sd.core_pwr_channels[ii], iii) {
                                vd.core_pwrs[ii][iii] = Float(value)/Float(cmd.interval/1e+3)
                            }
                        }
                    }
                }
                
                if sd.extra[0].lowercased() == "apple m1" || sd.extra[0].lowercased() == "apple m2" {
                    if group?.uppercased() == "PMP" && chann_name?.uppercased() == "GPU" {
                        vd.cluster_pwrs[-1] = Float(value)/Float(cmd.interval/1e+3)
                    }
                }
            }
        }
        
        for sample in clpc_delta {
            let chann_name = IOReportChannelGetChannelName(sample)
            
            for i in 0..<sd.cluster_core_counts.count {
                let value = IOReportArrayGetValueAtIndex(sample, Int32(i))
                
                if chann_name == "CPU cycles, by cluster" {
                    vd.cluster_instrcts_clk.append(CLong(value))
                } else if chann_name == "CPU instructions, by cluster" {
                    vd.cluster_instrcts_ret.append(CLong(value))
                }
            }
            
            if vd.cluster_instrcts_ret.count == sd.cluster_core_counts.count {
                break
            }
        }
        
        var last_name = ""
        for i in 0..<bw_delta.count {
            let sample = bw_delta[i]
            let chann_name = IOReportChannelGetChannelName(sample).lowercased()
            if chann_name.contains("dcs") && (chann_name.contains("rd") || chann_name.contains("wr")) {
                let raw = Double(IOReportSimpleGetIntegerValue(sample, 0))
                
                if chann_name == last_name+" wr" {
                    vd.bandwidth_cnt[last_name]!.append(raw/1e9)
                } else if chann_name.contains(" rd") {
                    let last_tmp = chann_name.split(separator: " ")
                    last_name = last_tmp[0..<last_tmp.count-1].joined(separator: " ")
                    vd.bandwidth_cnt[last_name] = [raw/1e9]
                }
            }
        }
    }
}

func appleSiliconSensors(page: Int32, usage: Int32, typ: Int32) -> Dictionary<String, IOHIDFloat>? {
    let dict = ["PrimaryUsagePage": page, "PrimaryUsage": usage] as CFDictionary
    
    let systm = IOHIDEventSystemClientCreate(kCFAllocatorDefault).takeUnretainedValue()
    IOHIDEventSystemClientSetMatching(systm, dict)
    let services = IOHIDEventSystemClientCopyServices(systm) as? Array<IOHIDServiceClient>
    if services == nil {
        return nil
    }
    
    var dctionary: Dictionary<String, IOHIDFloat> = [:]
    for i in 0..<services!.count {
        let service = services![i]
        let name = IOHIDServiceClientCopyProperty(service, "Product" as CFString)
        
        let event = IOHIDServiceClientCopyEvent(service, Int64(typ), 0, 0)
        if event == nil {
            continue
        }
        
        if (name != nil) && (event != nil) {
            dctionary[name as! String] = IOHIDEventGetFloatValue(event, (typ << 16))
        }
    }
    return dctionary
}

func getSensorVal(vd: inout variating_data, set_mode: Bool = false, sd: inout static_data) {
    let sens = Sensors()
    let sen = sens.sensorsReader
    sen.read()
    let sense = sen.list
    for idx in 0..<sense.count {
        let sns = sense[idx]
        if sns.type == SensorType.temperature {
            vd.soc_temp[sns.name] = sns.value
        } else if sns.type == SensorType.fan {
            vd.fan_speed[sns.name] = sns.value
            if sns.name != "Fastest Fan" {
                let tmp = sns as! Fan
                if set_mode {
                    if sns.name == "Left fan" {
                        sd.fan_limit[0][0] = tmp.minSpeed
                        sd.fan_limit[0][1] = tmp.maxSpeed
                    } else {
                        sd.fan_limit[1][0] = tmp.minSpeed
                        sd.fan_limit[1][1] = tmp.maxSpeed
                    }
                }
            }
        } else if sns.type == SensorType.power {
            vd.soc_power[sns.name] = sns.value
        } else if sns.type == SensorType.energy {
            vd.soc_energy = sns.value
        }
    }
}

func getMemUsage(vd: inout variating_data) {
    var totalSize: Double = 0
    
    var hostInfo = host_basic_info()
    var count = UInt32(MemoryLayout<host_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
    
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &hostInfo) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            host_info(mach_host_self(), HOST_BASIC_INFO, $0, &count)
        }
    }
    
    if kerr == KERN_SUCCESS {
        totalSize = Double(hostInfo.max_mem)
    }
    
    var stats = vm_statistics64()
    count = UInt32(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
    
    let result: kern_return_t = withUnsafeMutablePointer(to: &stats) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
        }
    }
    
    if result == KERN_SUCCESS {
        let active = Double(stats.active_count) * Double(vm_page_size)
        let speculative = Double(stats.speculative_count) * Double(vm_page_size)
        let inactive = Double(stats.inactive_count) * Double(vm_page_size)
        let wired = Double(stats.wire_count) * Double(vm_page_size)
        let compressed = Double(stats.compressor_page_count) * Double(vm_page_size)
        let purgeable = Double(stats.purgeable_count) * Double(vm_page_size)
        let external = Double(stats.external_page_count) * Double(vm_page_size)
        
        let used = active + inactive + speculative + wired + compressed - purgeable - external
        let free = totalSize - used
        
        var stringSize: size_t = MemoryLayout<xsw_usage>.size
        var swap: xsw_usage = xsw_usage()
        sysctlbyname("vm.swapusage", &swap, &stringSize, nil, 0)
        vd.mem_stat.total = convertToGB(totalSize)
        vd.mem_stat.used = convertToGB(used)
        vd.mem_stat.free = convertToGB(free)
        vd.swap_stat.total = convertToGB(Double(swap.xsu_total))
        vd.swap_stat.used = convertToGB(Double(swap.xsu_used))
        vd.swap_stat.free = convertToGB(Double(swap.xsu_avail))
        vd.mem_percent = 100 - free/totalSize*100
    }
}

func format(sd: inout static_data, vd: inout variating_data) {
    for i in 0..<sd.complex_freq_channels.count {
        for ii in 0..<vd.cluster_residencies[i].count {
            let res = vd.cluster_residencies[i][ii]
            if res != 0 {
                let perc = res/Float(vd.cluster_sums[i])
                vd.cluster_freqs[i] += Float(sd.dvfm_states[i][ii])*perc
                vd.cluster_residencies[i][ii] = perc
            }
            
            if i <= sd.cluster_core_counts.count-1 {
                for iii in 0..<Int(sd.cluster_core_counts[i]) {
                    let core_res = vd.core_residencies[i][iii][ii]
                    if core_res != 0 {
                        let core_perc = Float(core_res) / Float(vd.core_sums[i][iii])
                        vd.core_freqs[i][iii] += Float(sd.dvfm_states[i][ii])*core_perc
                        vd.core_residencies[i][iii][ii] = core_perc
                    }
                }
            }
        }
        
        vd.cluster_use[i] /= Float(vd.cluster_sums[i])+vd.cluster_use[i]
        vd.cluster_use[i] *= 100
        if i <= sd.cluster_core_counts.count-1 {
            for iii in 0..<Int(sd.cluster_core_counts[i]) {
                let tmp = Float(vd.core_sums[i][iii])+Float(vd.core_use[i][iii] as! UInt64)
                vd.core_use[i][iii] = 100-(Float(vd.core_use[i][iii] as! UInt64)/tmp)*100
            }
        }
    }
    
    for i in ["pcpu", "jpg", "venc"] {
        vd.bandwidth_cnt["\(i) dcs"] = [0, 0]
        for ii in 0...4 {
            if vd.bandwidth_cnt.keys.contains("\(i)\(ii) dcs") {
                for iii in 0...1 {
                    vd.bandwidth_cnt[i+" dcs"]![iii] += vd.bandwidth_cnt["\(i)\(ii) dcs"]![iii]
                }
            }
        }
    }
    vd.bandwidth_cnt["media dcs"] = [0, 0]
    for i in ["isp", "strm codec", "prores", "vdec", "venc", "jpg"] {
        for ii in 0...1 {
            if vd.bandwidth_cnt.keys.contains("\(i) dcs") {
                vd.bandwidth_cnt["media dcs"]![ii] += vd.bandwidth_cnt["\(i) dcs"]![ii]
            }
        }
    }
}

func summary(sd: static_data, vd: variating_data, rd: inout render_data, rvd: inout render_value_data, opt: [Double]) {
    let average = Int(opt[0])
    var cores = [0, 0]
    for key in vd.soc_temp.keys {
        if key.contains("efficiency core") {
            rd.ecpu.temp += vd.soc_temp[key]!
            cores[0] += 1
        } else if key.contains("performance core") {
            rd.pcpu.temp += vd.soc_temp[key]!
            cores[1] += 1
        } else if key.contains("Average GPU") {
            rd.gpu.temp = vd.soc_temp[key]!
        }
    }
    rd.ecpu.temp /= Double(cores[0])
    rd.pcpu.temp /= Double(cores[1])
    
    var ecpu = 0
    var pcpu = 0
    var gpu = 0
    var ecpu_use: Float = 0
    var pcpu_use: Float = 0
    for (idx, cluster) in sd.complex_freq_channels.enumerated() {
        if cluster.contains("ECPU") {
            rd.ecpu.usage += vd.cluster_use[idx]
            for (i, freq) in vd.core_freqs[idx].enumerated() {
                rd.ecpu.freq += freq*(vd.core_use[idx][i] as! Float)
                ecpu_use += (vd.core_use[idx][i] as! Float)
            }
            // rd.ecpu.freq += vd.cluster_freqs[idx]
            ecpu += 1
        } else if cluster.contains("PCPU") {
            rd.pcpu.usage += vd.cluster_use[idx]
            for (i, freq) in vd.core_freqs[idx].enumerated() {
                rd.pcpu.freq += freq*(vd.core_use[idx][i] as! Float)
                pcpu_use += (vd.core_use[idx][i] as! Float)
            }
            // rd.pcpu.freq += vd.cluster_freqs[idx]
            pcpu += 1
        } else if cluster.contains("GPU") {
            rd.gpu.usage += vd.cluster_use[idx]
            rd.gpu.freq += vd.cluster_freqs[idx]
            gpu += 1
        }
    }
    rd.ecpu.usage = 100 - rd.ecpu.usage/Float(ecpu)
    // rd.ecpu.freq /= Float(ecpu)
    rd.ecpu.freq /= ecpu_use
    rd.pcpu.usage = 100 - rd.pcpu.usage/Float(pcpu)
    // rd.pcpu.freq /= Float(pcpu)
    rd.pcpu.freq /= pcpu_use
    rd.gpu.usage = 100 - rd.gpu.usage/Float(gpu)
    rd.gpu.freq /= Float(gpu)
    
    rvd.ecpu.title = PythonObject(String(format:"E-CPU Usage %.1f%% @ %.0f MHz (%.1f°C)", rd.ecpu.usage, rd.ecpu.freq, rd.ecpu.temp))
    rvd.ecpu.val = PythonObject(rd.ecpu.usage)
    rvd.pcpu.title = PythonObject(String(format:"P-CPU Usage %.1f%% @ %.0f MHz (%.1f°C)", rd.pcpu.usage, rd.pcpu.freq, rd.pcpu.temp))
    rvd.pcpu.val = PythonObject(rd.pcpu.usage)
    rvd.gpu.title = PythonObject(String(format:"GPU Usage %.1f%% @ %.0f MHz (%.1f°C)", rd.gpu.usage, rd.gpu.freq, rd.gpu.temp))
    rvd.gpu.val = PythonObject(rd.gpu.usage)
    
    var ane_value: Float = 0
    for (i, v) in sd.complex_pwr_channels.enumerated() {
        if v.contains("ANE") {
            ane_value += vd.cluster_pwrs[i] as! Float / 1024
        }
    }
    rvd.ane.title = PythonObject(
        String(
            format:"ANE Usage: %.1f%% @ %.1f W",
            (ane_value/sd.max_pwr[2]/Float(interval)*100),
            (ane_value/Float(interval))
        )
    )
    rvd.ane.val = PythonObject(ane_value/sd.max_pwr[2]/Float(interval)*100)
    
    if sd.fan_exist {
        var left_ratio = (vd.fan_speed["Left fan"]!-sd.fan_limit[0][0])/(sd.fan_limit[0][1]-sd.fan_limit[0][0])*100
        var right_ratio = (vd.fan_speed["Right fan"]!-sd.fan_limit[1][0])/(sd.fan_limit[1][1]-sd.fan_limit[1][0])*100
        
        if left_ratio < 0 {
            left_ratio = 0
        }
        if right_ratio < 0 {
            right_ratio = 0
        }
        
        rvd.lfan.title = PythonObject(
            String(
                format:"Fan Usage: %.2f%% & %.2f%%",
                left_ratio,
                right_ratio
            )
        )
        rvd.lfan.val = PythonObject((vd.fan_speed["Left fan"]!-sd.fan_limit[0][0])/(sd.fan_limit[0][1]-sd.fan_limit[0][0])*100)
        rvd.rfan.val = PythonObject((vd.fan_speed["Right fan"]!-sd.fan_limit[1][0])/(sd.fan_limit[1][1]-sd.fan_limit[1][0])*100)
        
        if vd.soc_temp["Airflow left"] != nil {
            rvd.lf_label = PythonObject(
                String(
                    format:"Left Fan: %.1f RPM (%.1f°C)", vd.fan_speed["Left fan"]!, vd.soc_temp["Airflow left"]!
                )
            )
            rvd.rf_label = PythonObject(
                String(
                    format:"Right Fan: %.1f RPM (%.1f°C)", vd.fan_speed["Right fan"]!, vd.soc_temp["Airflow right"]!
                )
            )
        } else if vd.soc_temp["Airflow front left"] != nil {
            rvd.lf_label = PythonObject(
                String(
                    format:"Left Fan: %.1f RPM (Front: %.1f°C Rear: %.1f°C)", vd.fan_speed["Left fan"]!, vd.soc_temp["Airflow front left"]!, vd.soc_temp["Airflow rear left"]!
                )
            )
            rvd.rf_label = PythonObject(
                String(
                    format:"Right Fan: %.1f RPM (Front: %.1f°C Rear: %.1f°C)", vd.fan_speed["Right fan"]!, vd.soc_temp["Airflow front right"]!, vd.soc_temp["Airflow rear right"]!
                )
            )
        }
    }
    
    var ram_power: Float = 0
    for (idx, vl) in sd.complex_pwr_channels.enumerated() {
        if vl.lowercased().contains("dram") {
            ram_power += vd.cluster_pwrs[idx] as! Float
        }
    }
    ram_power /= Float(interval)*1000
    if rvd.ram_pwr_max < ram_power {
        rvd.ram_pwr_max = ram_power
    }
    rvd.ram_pwr_avg.append(ram_power)
    if rvd.ram_pwr_avg.count > average {
        rvd.gpu_pwr_avg = rvd.gpu_pwr_avg[1..<average]
    }
    if vd.swap_stat.total < 0.1 {
        rvd.ram.title = PythonObject(
            String(
                format: "RAM Usage: %.1f/%.1fGB - swap inactive",
                vd.mem_stat.used,
                vd.mem_stat.total
            )
        )
    } else {
        rvd.ram.title = PythonObject(
            String(
                format: "RAM Usage: %.1f/%.1fGB - swap: %.1f/%.1fGB",
                vd.mem_stat.used,
                vd.mem_stat.total,
                vd.swap_stat.used,
                vd.swap_stat.total
            )
        )
    }
    rvd.ram.title += PythonObject(
        String(
            format: " [RAM Power: %.2fW (avg: %.2fW peak: %.2fW)]",
            ram_power,
            Float(rvd.ram_pwr_avg.reduce(PythonObject(0), +))!/Float(rvd.ram_pwr_avg.count),
            rvd.ram_pwr_max
        )
    )
    rvd.ram.val = PythonObject(Int(vd.mem_percent))
    var w = winsize()
    var baseLen = 0
    var LongShort = 0
    var rw_disp = false
    if ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) == 0 {
        if w.ws_col >= 177 {
            LongShort = 2
        } else if w.ws_col >= 164 {
            LongShort = 1
        }
        if w.ws_col >= 152 {
            baseLen = 1
        }
        if w.ws_col >= 136 {
            rw_disp = true
        }
    }
    var form = ""
    
    let ecpu_total_bw = (vd.bandwidth_cnt["ecpu dcs"]![0]+vd.bandwidth_cnt["ecpu dcs"]![1])/interval
    form = "E-CPU: %.\(LongShort)f GB/s"
    if rw_disp {
        form += " (R:%.\(LongShort)f GB/s W:%.\(LongShort)f GB/s)"
    }
    rvd.ecpu_bw.title = PythonObject(
        String(
            format: form,
            ecpu_total_bw,
            vd.bandwidth_cnt["ecpu dcs"]![0]/interval,
            vd.bandwidth_cnt["ecpu dcs"]![1]/interval
        )
    )
    rvd.ecpu_bw.val = PythonObject(ecpu_total_bw/Double(sd.max_bw[0])/interval*100)
    
    let pcpu_total_bw = (vd.bandwidth_cnt["pcpu dcs"]![0]+vd.bandwidth_cnt["pcpu dcs"]![1])/interval
    form = "P-CPU: %.\(LongShort)f GB/s"
    if rw_disp {
        form += " (R:%.\(LongShort)f GB/s W:%.\(LongShort)f GB/s)"
    }
    rvd.pcpu_bw.title = PythonObject(
        String(
            format: form,
            pcpu_total_bw,
            vd.bandwidth_cnt["pcpu dcs"]![0]/interval,
            vd.bandwidth_cnt["pcpu dcs"]![1]/interval
        )
    )
    rvd.pcpu_bw.val = PythonObject(pcpu_total_bw/Double(sd.max_bw[0])/interval*100)
    
    let gpu_total_bw = (vd.bandwidth_cnt["gfx dcs"]![0]+vd.bandwidth_cnt["gfx dcs"]![1])/interval
    form = "GPU: %.\(baseLen+LongShort)f GB/s"
    if rw_disp {
        form += " (R:%.\(baseLen+LongShort)f GB/s W:%.\(baseLen+LongShort)f GB/s)"
    }
    rvd.gpu_bw.title = PythonObject(
        String(
            format: form,
            gpu_total_bw,
            vd.bandwidth_cnt["gfx dcs"]![0]/interval,
            vd.bandwidth_cnt["gfx dcs"]![1]/interval
        )
    )
    rvd.gpu_bw.val = PythonObject(gpu_total_bw/Double(sd.max_bw[1])/interval*100)
    
    let media_total_bw = (vd.bandwidth_cnt["media dcs"]![0]+vd.bandwidth_cnt["media dcs"]![1])/interval
    form = "Media: %.\(baseLen+LongShort)f GB/s"
    if rw_disp {
        form += " (R:%.\(baseLen+LongShort)f GB/s W:%.\(baseLen+LongShort)f GB/s)"
    }
    rvd.media_bw.title = PythonObject(
        String(
            format: form,
            media_total_bw,
            vd.bandwidth_cnt["media dcs"]![0]/interval,
            vd.bandwidth_cnt["media dcs"]![1]/interval
        )
    )
    rvd.media_bw.val = PythonObject(media_total_bw/Double(sd.max_bw[2])/interval*100)
    
    let total_bw = (vd.bandwidth_cnt["dcs"]![0]+vd.bandwidth_cnt["dcs"]![1])/interval
    rvd.total_bw = PythonObject(
        String(
            format: "Memory Bandwidth: %.3f GB/s (R:%.3f GB/s W:%.3f GB/s)",
            total_bw,
            vd.bandwidth_cnt["dcs"]![0]/interval,
            vd.bandwidth_cnt["dcs"]![1]/interval
        )
    )
    
    let sys_pwr_W = vd.soc_power["System Total"]!/interval
    if rvd.sys_pwr_max < sys_pwr_W {
        rvd.sys_pwr_max = sys_pwr_W
    }
    rvd.sys_pwr_avg.append(sys_pwr_W)
    if rvd.sys_pwr_avg.count > average {
        rvd.sys_pwr_avg = rvd.sys_pwr_avg[1..<average]
    }
    rvd.system_pwr = PythonObject(
        String(
            format: "System Power: %.2fW (avg: %.2fW peak: %.2fW)",
            sys_pwr_W,
            Double(rvd.sys_pwr_avg.reduce(PythonObject(0), +))!/Double(rvd.sys_pwr_avg.count),
            rvd.sys_pwr_max
        )
    )
    
    var cpu_power: Float = 0
    for (idx, vl) in sd.complex_pwr_channels.enumerated() {
        if vl.lowercased().contains("cpu") {
            cpu_power += vd.cluster_pwrs[idx] as! Float
        }
    }
    cpu_power /= Float(interval)*1000
    if rvd.cpu_pwr_max < cpu_power {
        rvd.cpu_pwr_max = cpu_power
    }
    rvd.cpu_pwr_avg.append(cpu_power)
    if rvd.cpu_pwr_avg.count > average {
        rvd.cpu_pwr_avg = rvd.cpu_pwr_avg[1..<average]
    }
    rvd.cpu_pwr.title = PythonObject(
        String(
            format: "CPU: %.2fW (avd: %.2fW peak: %.2fW)",
            cpu_power,
            Float(rvd.cpu_pwr_avg.reduce(PythonObject(0), +))!/Float(rvd.cpu_pwr_avg.count),
            rvd.cpu_pwr_max
        )
    )
    rvd.cpu_pwr.val.append(PythonObject(cpu_power/sd.max_pwr[0]*100))
    if rvd.cpu_pwr.val.count > 500 {
        rvd.cpu_pwr.val = rvd.cpu_pwr.val[1..<500]
    }
    
    var gpu_power: Float = 0
    for (idx, vl) in sd.complex_pwr_channels.enumerated() {
        if vl.lowercased().contains("gpu") {
            gpu_power += vd.cluster_pwrs[idx] as! Float
        }
    }
    gpu_power /= Float(interval)*1000
    if rvd.gpu_pwr_max < gpu_power {
        rvd.gpu_pwr_max = gpu_power
    }
    rvd.gpu_pwr_avg.append(gpu_power)
    if rvd.gpu_pwr_avg.count > average {
        rvd.gpu_pwr_avg = rvd.gpu_pwr_avg[1..<average]
    }
    rvd.gpu_pwr.title = PythonObject(
        String(
            format: "GPU: %.2fW (avg: %.2fW peak: %.2fW)",
            gpu_power,
            Float(rvd.gpu_pwr_avg.reduce(PythonObject(0), +))!/Float(rvd.gpu_pwr_avg.count),
            rvd.gpu_pwr_max
        )
    )
    rvd.gpu_pwr.val.append(PythonObject(gpu_power/sd.max_pwr[1]*100))
    if rvd.gpu_pwr.val.count > 500 {
        rvd.gpu_pwr.val = rvd.gpu_pwr.val[1..<500]
    }
}
