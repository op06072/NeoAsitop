//
//  sampler.swift
//  socpowerbuddy_swift
//
//  Created by Eom SeHwan on 2022/09/15.
//

import Foundation
import Darwin

func sample(iorep: iorep_data,
            sd: static_data,
            vd: inout variating_data,
            cmd: cmd_data) {
    autoreleasepool {
        let ptype_state = "P"
        let vtype_state = "V"
        let idletype_state = "IDLE"
        let offtype_state = "OFF"
        
        var tmp_samp = IOReportCreateSamples(
            iorep.cpusub, iorep.cpusubchn?.takeUnretainedValue(), nil
        ).takeRetainedValue()
        
        let cpusamp_a = tmp_samp
        tmp_samp = IOReportCreateSamples(
            iorep.pwrsub, iorep.pwrsubchn?.takeUnretainedValue(), nil
        ).takeRetainedValue()
        let pwrsamp_a = tmp_samp
        tmp_samp = IOReportCreateSamples(
            iorep.clpcsub, iorep.clpcsubchn?.takeUnretainedValue(), nil
        ).takeRetainedValue()
        let clpcsamp_a = tmp_samp
        tmp_samp = IOReportCreateSamples(
            iorep.bwsub, iorep.bwsubchn?.takeUnretainedValue(), nil
        ).takeRetainedValue()
        let bwsamp_a = tmp_samp
        
        if cmd.interval > 0 {
            Thread.sleep(forTimeInterval: cmd.interval*1e-3)
        }
        
        tmp_samp = IOReportCreateSamples(
            iorep.cpusub, iorep.cpusubchn?.takeUnretainedValue(), nil
        ).takeRetainedValue()
        let cpusamp_b = tmp_samp
        tmp_samp = IOReportCreateSamples(
            iorep.pwrsub, iorep.pwrsubchn?.takeUnretainedValue(), nil
        ).takeRetainedValue()
        let pwrsamp_b = tmp_samp
        tmp_samp = IOReportCreateSamples(
            iorep.bwsub, iorep.bwsubchn?.takeUnretainedValue(), nil
        ).takeRetainedValue()
        let clpcsamp_b = tmp_samp
        tmp_samp = IOReportCreateSamples(
            iorep.bwsub, iorep.bwsubchn?.takeUnretainedValue(), nil
        ).takeRetainedValue()
        let bwsamp_b = tmp_samp
        
        var ttmp = IOReportCreateSamplesDelta(cpusamp_a, cpusamp_b, nil)?.takeRetainedValue()
        
        let cpu_delta = Array((ttmp as! Dictionary<String, Any>).values)[0] as? Array<CFDictionary>
        ttmp = IOReportCreateSamplesDelta(pwrsamp_a, pwrsamp_b, nil)?.takeRetainedValue()
        let pwr_delta = Array((ttmp as! Dictionary<String, Any>).values)[0] as? Array<CFDictionary>
        ttmp = IOReportCreateSamplesDelta(clpcsamp_a, clpcsamp_b, nil)?.takeRetainedValue()
        let clpc_delta = Array((ttmp as! Dictionary<String, Any>).values)[0] as? Array<CFDictionary>
        ttmp = IOReportCreateSamplesDelta(bwsamp_a, bwsamp_b, nil)?.takeRetainedValue()
        let bw_delta = Array((ttmp as! Dictionary<String, Any>).values)[0] as? Array<CFDictionary>
        
        for sample in cpu_delta! {
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
        for sample in pwr_delta! {
            let chann_name = IOReportChannelGetChannelName(sample)
            let group = IOReportChannelGetGroup(sample)
            let value = IOReportSimpleGetIntegerValue(sample, 0)
            
            for ii in 0..<sd.complex_pwr_channels.count {
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
                    if group?.uppercased() == "PMP" {
                        if chann_name?.uppercased() == "GPU" {
                            vd.cluster_pwrs[2] = Float(value)/Float(cmd.interval/1e+3)
                        } else if chann_name?.uppercased() == "ANE" {
                            vd.cluster_pwrs[3] = Float(value)/Float(cmd.interval/1e+3)
                        } else if chann_name?.uppercased() == "DRAM" {
                            vd.cluster_pwrs[4] = Float(value)/Float(cmd.interval/1e+3)
                        }
                    }
                }
            }
        }
        
        for sample in clpc_delta! {
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
        for i in 0..<bw_delta!.count {
            let sample = bw_delta![i]
            let chann_name = IOReportChannelGetChannelName(sample).lowercased()
            if chann_name.contains("dcs") && (chann_name.contains("rd") || chann_name.contains("wr")) {
                let raw = Double(IOReportSimpleGetIntegerValue(sample, 0))
                
                if chann_name == last_name+" wr" {
                    vd.bandwidth_cnt[last_name]!.append(raw/Double(cmd.interval/1e+3)/1e9)
                } else if chann_name.contains(" rd") {
                    let last_tmp = chann_name.split(separator: " ")
                    last_name = last_tmp[0..<last_tmp.count-1].joined(separator: " ")
                    vd.bandwidth_cnt[last_name] = [raw/Double(cmd.interval/1e+3)/1e9]
                }
            }
        }
    }
}

func appleSiliconSensors(page: Int32, usage: Int32, typ: Int32) -> Dictionary<String, IOHIDFloat>? {
    var dctionary: Dictionary<String, IOHIDFloat> = [:]
    let dict = ["PrimaryUsagePage": page, "PrimaryUsage": usage] as CFDictionary
    
    let systm = IOHIDEventSystemClientCreate(kCFAllocatorDefault).takeUnretainedValue()
    IOHIDEventSystemClientSetMatching(systm, dict)
    let services = IOHIDEventSystemClientCopyServices(systm) as? Array<IOHIDServiceClient>
    if services == nil {
        return nil
    }
    
    autoreleasepool {
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
    }
    return dctionary
}

func getSensorVal(vd: inout variating_data, set_mode: Bool = false, sd: inout static_data) {
    autoreleasepool {
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
                        if sd.fan_mode == 2{
                            if sns.name == "Left fan" {
                                sd.fan_limit[0][0] = tmp.minSpeed
                                sd.fan_limit[0][1] = tmp.maxSpeed
                            } else {
                                sd.fan_limit[1][0] = tmp.minSpeed
                                sd.fan_limit[1][1] = tmp.maxSpeed
                            }
                        } else if sd.fan_mode == 1 {
                            sd.fan_limit[0][0] = tmp.minSpeed
                            sd.fan_limit[0][1] = tmp.maxSpeed
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
}

func getMemUsage(vd: inout variating_data) {
    autoreleasepool {
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
}

func format(sd: inout static_data, vd: inout variating_data) {
    autoreleasepool {
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
}

func summary(sd: static_data, vd: variating_data, rd: inout render_data, rvd: inout dispInfo, opt: Double) {
    autoreleasepool {
        let average = Int(opt)
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
        
        var ecpu: Float = 0
        var pcpu: Float = 0
        var gpu: Float = 0
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
        //print("cluster calc finish")
        rd.ecpu.usage = 100 - rd.ecpu.usage/ecpu
        // rd.ecpu.freq /= Float(ecpu)
        rd.ecpu.freq /= ecpu_use
        rd.pcpu.usage = 100 - rd.pcpu.usage/pcpu
        // rd.pcpu.freq /= Float(pcpu)
        rd.pcpu.freq /= pcpu_use
        rd.gpu.usage = 100 - rd.gpu.usage/gpu
        rd.gpu.freq /= gpu
        
        rvd.ecpu_usg.title = String(format:"E-CPU Usage %.1f%% @ %.0f MHz", rd.ecpu.usage, rd.ecpu.freq)
        rvd.ecpu_usg.val = rd.ecpu.usage
        rvd.pcpu_usg.title = String(format:"P-CPU Usage %.1f%% @ %.0f MHz", rd.pcpu.usage, rd.pcpu.freq)
        rvd.pcpu_usg.val = rd.pcpu.usage
        rvd.gpu_usg.title = String(format:"GPU Usage %.1f%% @ %.0f MHz", rd.gpu.usage, rd.gpu.freq)
        rvd.gpu_usg.val = rd.gpu.usage
        
        var ane_value: Float = 0
        for (i, v) in sd.complex_pwr_channels.enumerated() {
            if v.contains("ANE") {
                ane_value += vd.cluster_pwrs[i] as! Float / 1024
            }
        }
        rvd.ane_usg.title = String(
            format:"ANE Usage: %.1f%% @ %.1f W",
            (ane_value/sd.max_pwr[2]*100),
            (ane_value)
        )
        rvd.ane_usg.val = ane_value/sd.max_pwr[2]*100
        
        if sd.fan_mode > 0 {
            if sd.fan_mode == 2 {
                var left_ratio = (vd.fan_speed["Left fan"]!-sd.fan_limit[0][0])/(sd.fan_limit[0][1]-sd.fan_limit[0][0])*100
                var right_ratio = (vd.fan_speed["Right fan"]!-sd.fan_limit[1][0])/(sd.fan_limit[1][1]-sd.fan_limit[1][0])*100
                
                if left_ratio < 0 {
                    left_ratio = 0
                }
                if right_ratio < 0 {
                    right_ratio = 0
                }
                
                rvd.fan_usg.title = String(
                    format:"Fan Usage: %.2f%% & %.2f%%",
                    left_ratio,
                    right_ratio
                )
                rvd.fan_usg.val[0] = Float(left_ratio)
                rvd.fan_usg.val[1] = Float(right_ratio)
                
                if vd.soc_temp["Airflow left"] != nil {
                    rvd.airflow_info[0] = String(
                        format:"Left Fan: %.1f RPM (%.1f°C)", vd.fan_speed["Left fan"]!, vd.soc_temp["Airflow left"]!
                    )
                    if rvd.airflow_info.count == 1 {
                        rvd.airflow_info.append(
                            String(
                                format:"Right Fan: %.1f RPM (%.1f°C)", vd.fan_speed["Right fan"]!, vd.soc_temp["Airflow right"]!
                            )
                        )
                    } else {
                        rvd.airflow_info[1] = String(
                            format:"Right Fan: %.1f RPM (%.1f°C)", vd.fan_speed["Right fan"]!, vd.soc_temp["Airflow right"]!
                        )
                    }
                } else if vd.soc_temp["Airflow front left"] != nil {
                    rvd.airflow_info[0] = String(
                        format:"Left Fan: %.1f RPM (Front: %.1f°C Rear: %.1f°C)", vd.fan_speed["Left fan"]!, vd.soc_temp["Airflow front left"]!, vd.soc_temp["Airflow rear left"]!
                    )
                    rvd.airflow_info.append(
                        String(
                            format:"Right Fan: %.1f RPM (Front: %.1f°C Rear: %.1f°C)", vd.fan_speed["Right fan"]!, vd.soc_temp["Airflow front right"]!, vd.soc_temp["Airflow rear right"]!
                        )
                    )
                }
            } else if sd.fan_mode == 1 {
                var ratio = (vd.fan_speed["Fan #0"]!-sd.fan_limit[0][0])/(sd.fan_limit[0][1]-sd.fan_limit[0][0])*100
                if ratio < 0 {
                    ratio = 0
                }
                
                rvd.fan_usg.title = String(
                    format: "Fan Usage: %2.f%%",
                    ratio
                )
                rvd.fan_usg.val[0] = Float(ratio)
                
                rvd.airflow_info[0] = String(
                    format: "Fan: %.1f RPM",
                    vd.fan_speed["Fan #0"]!
                )
            }
        }
        
        var ram_power: Float = 0
        for (idx, vl) in sd.complex_pwr_channels.enumerated() {
            if vl.lowercased().contains("dram") {
                ram_power += vd.cluster_pwrs[idx] as! Float
            }
        }
        ram_power /= 1000
        if rvd.ram_pwr_max < ram_power {
            rvd.ram_pwr_max = ram_power
        }
        rvd.ram_pwr_avg.append(ram_power)
        if rvd.ram_pwr_avg.count > average {
            rvd.gpu_pwr_avg = Array(rvd.gpu_pwr_avg[1..<average])
        }
        if vd.swap_stat.total < 0.1 {
            rvd.ram_usg.title = String(
                format: "RAM Usage: %.1f/%.1fGB - swap inactive",
                vd.mem_stat.used,
                vd.mem_stat.total
            )
        } else {
            rvd.ram_usg.title = String(
                format: "RAM Usage: %.1f/%.1fGB - swap: %.1f/%.1fGB",
                vd.mem_stat.used,
                vd.mem_stat.total,
                vd.swap_stat.used,
                vd.swap_stat.total
            )
        }
        rvd.ram_usg.val = Float(vd.mem_percent)
        var w = winsize()
        var baseLen = 0
        var LongShort = 0
        var rw_disp = false
        var stat_disp = false
        var pwr_unit = 0
        var bw_unit = 3
        var total_pwr = 2
        // 변동 레이아웃
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) == 0 {
            var space = 0
            var space0 = 0 // 추가 내용 뺀 부분의 여분길이
            var space1 = 0
            // CPU & GPU 온도
            if w.ws_col >= 73 {
                rvd.gpu_usg.title += String(
                    format:" (%.1f°C)", rd.gpu.temp
                )
                if w.ws_col >= 80 {
                    rvd.ecpu_usg.title += String(
                        format:" (%.1f°C)", 100.0//rd.ecpu.temp
                    )
                    rvd.pcpu_usg.title += String(
                        format:" (%.1f°C)", 100.0//rd.pcpu.temp
                    )
                }
            }
            // Memory Bandwidth
            space = 0
            var tmp_val = 200.0
            var sum_num: Double = 0
            for i in ["ecpu", "pcpu", "gfx", "media"] {
                sum_num = 0
                for j in 0...1 {
                    tmp_val = vd.bandwidth_cnt["\(i) dcs"]![j]
                    space += String(Int(tmp_val)).count - 1
                    sum_num += tmp_val
                    //space += 2
                }
                space0 += String(Int(sum_num)).count - 1
                //space += 2
            }
            sum_num = 0
            for i in vd.bandwidth_cnt["dcs"]! {
                tmp_val = i
                //tmp_val = 200.0
                space1 += String(Int(tmp_val)).count - 1
                sum_num += tmp_val
            }
            space1 += String(Int(sum_num)).count - 1
            //print(space1)
            space += space0
            if w.ws_col >= 143 + space {
                rw_disp = true
                if w.ws_col >= 191 + space {
                    LongShort = 2
                } else if w.ws_col >= 175 + space {
                    LongShort = 1
                }
                if w.ws_col >= 167 + space {
                    baseLen = 1
                }
            } else {
                if w.ws_col >= 79 + space0 {
                    LongShort = 2
                } else if w.ws_col >= 71 + space0 {
                    LongShort = 1
                }
                if w.ws_col >= 71 + space0 {
                    baseLen = 1
                } else if w.ws_col < 59 + space1 {
                    bw_unit = 2
                }
            }
            // CPU GPU pwr
            if w.ws_col >= 82 {
                stat_disp = true
                pwr_unit = 1
                if w.ws_col >= 86 {
                    pwr_unit = 2
                }
            } else {
                pwr_unit = 2
                if w.ws_col < 65 {
                    total_pwr = 1
                }
            }
        }
        
        var form = ""
        
        let ecpu_total_bw = (vd.bandwidth_cnt["ecpu dcs"]![0]+vd.bandwidth_cnt["ecpu dcs"]![1])
        form = "E-CPU: %.\(LongShort)f GB/s"
        if rw_disp {
            form += " (R:%.\(LongShort)f GB/s W:%.\(LongShort)f GB/s)"
        }
        rvd.ecpu_bw.title = String(
            format: form,
            ecpu_total_bw,
            vd.bandwidth_cnt["ecpu dcs"]![0],
            vd.bandwidth_cnt["ecpu dcs"]![1]
            /*200.0,
            200.0,
            200.0*/
        )
        rvd.ecpu_bw.val = Float(ecpu_total_bw/Double(sd.max_bw[0])*100)
        
        let pcpu_total_bw = (vd.bandwidth_cnt["pcpu dcs"]![0]+vd.bandwidth_cnt["pcpu dcs"]![1])
        form = "P-CPU: %.\(LongShort)f GB/s"
        if rw_disp {
            form += " (R:%.\(LongShort)f GB/s W:%.\(LongShort)f GB/s)"
        }
        rvd.pcpu_bw.title = String(
            format: form,
            pcpu_total_bw,
            vd.bandwidth_cnt["pcpu dcs"]![0],
            vd.bandwidth_cnt["pcpu dcs"]![1]
            /*200.0,
            200.0,
            200.0*/
        )
        rvd.pcpu_bw.val = Float(pcpu_total_bw/Double(sd.max_bw[0])*100)
        
        let gpu_total_bw = (vd.bandwidth_cnt["gfx dcs"]![0]+vd.bandwidth_cnt["gfx dcs"]![1])
        form = "GPU: %.\(baseLen+LongShort)f GB/s"
        if rw_disp {
            form += " (R:%.\(baseLen+LongShort)f GB/s W:%.\(baseLen+LongShort)f GB/s)"
        }
        rvd.gpu_bw.title = String(
            format: form,
            gpu_total_bw,
            vd.bandwidth_cnt["gfx dcs"]![0],
            vd.bandwidth_cnt["gfx dcs"]![1]
            /*200.0,
            200.0,
            200.0*/
        )
        rvd.gpu_bw.val = Float(gpu_total_bw/Double(sd.max_bw[1])*100)
        
        let media_total_bw = (vd.bandwidth_cnt["media dcs"]![0]+vd.bandwidth_cnt["media dcs"]![1])
        form = "Media: %.\(baseLen+LongShort)f GB/s"
        if rw_disp {
            form += " (R:%.\(baseLen+LongShort)f GB/s W:%.\(baseLen+LongShort)f GB/s)"
        }
        rvd.media_bw.title = String(
            format: form,
            media_total_bw,
            vd.bandwidth_cnt["media dcs"]![0],
            vd.bandwidth_cnt["media dcs"]![1]
            /*200.0,
            200.0,
            200.0*/
        )
        rvd.media_bw.val = Float(media_total_bw/Double(sd.max_bw[2])*100)
        
        let total_bw = (vd.bandwidth_cnt["dcs"]![0]+vd.bandwidth_cnt["dcs"]![1])
        rvd.bw_grp = String(
            format: "Memory Bandwidth: %.\(bw_unit)f GB/s (R:%.\(bw_unit)f GB/s W:%.\(bw_unit)f GB/s)",
            total_bw,
            vd.bandwidth_cnt["dcs"]![0],
            vd.bandwidth_cnt["dcs"]![1]
            /*200.0,
            200.0,
            200.0*/
        )
        
        let sys_pwr_W = vd.soc_power["System Total"]!
        if rvd.sys_pwr_max < sys_pwr_W {
            rvd.sys_pwr_max = sys_pwr_W
        }
        rvd.sys_pwr_avg.append(sys_pwr_W)
        if rvd.sys_pwr_avg.count > average {
            rvd.sys_pwr_avg = Array(rvd.sys_pwr_avg[1..<average])
        }
        var throttle = ""
        switch ProcessInfo.processInfo.thermalState.rawValue {
        case 0:
            throttle = " throttle: no"
            break
        case 1, 2, 3:
            throttle = " throttle: yes"
            break
        default:
            break
        }
        rvd.pwr_grp = String(
            format: "System Power: %.\(total_pwr)fW (avg: %.\(total_pwr)fW peak: %.\(total_pwr)fW)%@",
            sys_pwr_W,
            rvd.sys_pwr_avg.reduce(0, +)/Double(rvd.sys_pwr_avg.count),
            rvd.sys_pwr_max,
            /*200.0,
            200.0,
            200.0,*/
            throttle
        )
        
        var cpu_power: Float = 0
        for (idx, vl) in sd.complex_pwr_channels.enumerated() {
            if vl.lowercased().contains("cpu") {
                cpu_power += vd.cluster_pwrs[idx] as! Float
            }
        }
        cpu_power /= 1000
        if rvd.cpu_pwr_max < cpu_power {
            rvd.cpu_pwr_max = cpu_power
        }
        rvd.cpu_pwr_avg.append(cpu_power)
        if rvd.cpu_pwr_avg.count > average {
            rvd.cpu_pwr_avg = Array(rvd.cpu_pwr_avg[1..<average])
        }
        form = "CPU: %.2fW"
        if stat_disp {
            form += " (avd: %.\(pwr_unit)fW peak: %.\(pwr_unit)fW)"
        }
        rvd.cpu_pwr.title = String(
            format: form,
            cpu_power,
            rvd.cpu_pwr_avg.reduce(0, +)/Float(rvd.cpu_pwr_avg.count),
            rvd.cpu_pwr_max
            /*100.0,
             100.0,
             100.0*/
        )
        rvd.cpu_pwr.val.append(cpu_power/sd.max_pwr[0]*100)
        if rvd.cpu_pwr.val.count > 500 {
            rvd.cpu_pwr.val = Array(rvd.cpu_pwr.val[1..<500])
        }
        
        var gpu_power: Float = 0
        for (idx, vl) in sd.complex_pwr_channels.enumerated() {
            if vl.lowercased().contains("gpu") {
                gpu_power += vd.cluster_pwrs[idx] as! Float
            }
        }
        gpu_power /= 1000
        if rvd.gpu_pwr_max < gpu_power {
            rvd.gpu_pwr_max = gpu_power
        }
        rvd.gpu_pwr_avg.append(gpu_power)
        if rvd.gpu_pwr_avg.count > average {
            rvd.gpu_pwr_avg = Array(rvd.gpu_pwr_avg[1..<average])
        }
        form = "GPU: %.2fW"
        if stat_disp {
            form += " (avd: %.\(pwr_unit)fW peak: %.\(pwr_unit)fW)"
        }
        rvd.gpu_pwr.title = String(
            format: form,
            gpu_power,
            rvd.gpu_pwr_avg.reduce(0, +)/Float(rvd.gpu_pwr_avg.count),
            rvd.gpu_pwr_max
            /*100.0,
             100.0,
             100.0*/
        )
        rvd.gpu_pwr.val.append(gpu_power/sd.max_pwr[1]*100)
        if rvd.gpu_pwr.val.count > 500 {
            rvd.gpu_pwr.val = Array(rvd.gpu_pwr.val[1..<500])
        }
    }
}
