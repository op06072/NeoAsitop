//
//  static.swift
//  socpowerbuddy_swift
//
//  Created by Eom SeHwan on 2022/09/14.
//

import Foundation
import ArgumentParser

class File {
    init? (_ path: String) {
        errno = 0
        file = fopen(path, "r")
        if file == nil {
            perror(nil)
            return nil
        }
    }
    
    deinit {
        fclose(file)
    }

    func testIndex(line: String) -> Bool {
        guard line.lastIndex(of: "\r") == nil else {
            return false
        }
        guard line.lastIndex(of: "\n") == nil else {
            return false
        }
        guard line.lastIndex(of: "\r\n") == nil else {
            return false
        }
        return true
    }

    func getLine() -> String? {
        var line = ""
        repeat {
            var buf = [CChar](repeating: 0, count: 1024)
            errno = 0
            if fgets(&buf, Int32(buf.count), file) == nil {
                if feof(file) != 0 {
                    return nil
                } else {
                    perror(nil)
                    return nil
                }
            }
            line += String(cString: buf)
        } while testIndex(line: line)
        return line
    }
    private var file: UnsafeMutablePointer<FILE>? = nil
}

public func process(path: String, arguments: [String]) -> String? {
    let task = Process()
    task.launchPath = path
    task.arguments = arguments
    
    let outputPipe = Pipe()
    defer {
        outputPipe.fileHandleForReading.closeFile()
    }
    task.standardOutput = outputPipe
    
    do {
        try task.run()
    } catch let error {
        print("Failed to run SystemProfiler")
        print("system_profiler \(arguments[0]): \(error.localizedDescription)")
        return nil
    }
    
    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(decoding: outputData, as: UTF8.self)
    
    if output.isEmpty {
        return nil
    }
    
    return output
}

func staticInit(sd: inout static_data) {
    let procInfo = ProcessInfo()
    let systemVersion = procInfo.operatingSystemVersion
    sd.os_ver = "macOS \(systemVersion.majorVersion).\(systemVersion.minorVersion)"

    generateDvfmTable(sd: &sd)
    //print("dvfm table gen finish")
    generateProcessorName(sd: &sd)
    //print("process name gen finish")
    getOSCode(sd: &sd)
    
    let tmp = sd.extra[0].lowercased()
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
}

func generateDvfmTable(sd: inout static_data) {
    autoreleasepool {
        var iter = io_iterator_t()
        var port = mach_port_t()
        
        var servicedict: Unmanaged<CFMutableDictionary>? = nil
        
        if #available(macOS 12, *) {
            port = kIOMainPortDefault
        } else {
            port = kIOMasterPortDefault
        }
        
        for i in stride(from: 2, to: -1, by: -1) {
            if let service: CFMutableDictionary = IOServiceMatching("AppleARMIODevice") {
                if IOServiceGetMatchingServices(port, service, &iter) != kIOReturnSuccess {
                    print("Failed to access AppleARMIODevice service in IORegistry")
                    exit(1)
                }
            } else {
                print("Failed to find AppleARMIODevice service in IORegistry")
                exit(1)
            }
            
            while case let entry = IOIteratorNext(iter), entry != IO_OBJECT_NULL {
                if IORegistryEntryCreateCFProperties(entry, &servicedict, kCFAllocatorDefault, 0) != kIOReturnSuccess {
                    print("Failed to create CFProperties for AppleARMIODevice service in IORegistry")
                    exit(1)
                }
                
                guard let serviceDict = servicedict?.takeRetainedValue() as? [String : AnyObject] else { continue }
                var data: AnyObject? = nil
                
                switch i {
                case 2:
                    data = serviceDict["voltage-states1-sram"]
                case 1:
                    data = serviceDict["voltage-states5-sram"]
                case 0:
                    data = serviceDict["voltage-states9"]
                default:
                    break
                }
                
                if data != nil {
                    sd.dvfm_states_holder.append([])
                    let databytes = data?.bytes?.assumingMemoryBound(to: UInt8.self)
                    
                    for ii in stride(from:4, to:data!.length+4, by:8) {
                        let datastrng = String(format:"0x%02x%02x%02x%02x", databytes![ii-1], databytes![ii-2], databytes![ii-3], databytes![ii-4])
                        let freq = atof(datastrng) * 1e-6
                        if freq != 0 {
                            sd.dvfm_states_holder[2-i].append(freq)
                        }
                    }
                    IOObjectRelease(entry)
                    break
                }
            }
            IOObjectRelease(iter)
        }
    }
}

func generateCoreCounts(sd: inout static_data) {
    autoreleasepool {
        var iter = io_iterator_t()
        var port = mach_port_t()
        
        var size = 0
        let getarch = "sysctl.proc_translated"
        sysctlbyname(getarch, nil, &size, nil, 0)
        var mode = 0
        sysctlbyname(getarch, &mode, &size, nil, 0)
        
        if mode == 0 {
            size = 0
            var getcpu = "hw.perflevel0.name"
            sysctlbyname(getcpu, nil, &size, nil, 0)
            var perflevel = [CChar](repeating: 0,  count: size)
            sysctlbyname(getcpu, &perflevel, &size, nil, 0)

            if strcmp(perflevel, "") != 0 {
                var tmp = ""
                perflevel.withUnsafeBufferPointer {
                    ptr in tmp += String(cString: ptr.baseAddress!)
                }
                size = 0
                getcpu = "hw.perflevel0.logicalcpu"
                sysctlbyname(getcpu, nil, &size, nil, 0)
                var cpucore = [UInt8](repeating: 0,  count: size)
                sysctlbyname(getcpu, &cpucore, &size, nil, 0)
                if tmp.lowercased() == "performance" {
                    sd.core_ep_counts[1] = cpucore[0]
                    
                    size = 0
                    getcpu = "hw.perflevel1.logicalcpu"
                    sysctlbyname(getcpu, nil, &size, nil, 0)
                    cpucore = [UInt8](repeating: 0,  count: size)
                    sysctlbyname(getcpu, &cpucore, &size, nil, 0)
                    
                    sd.core_ep_counts[0] = cpucore[0]
                } else {
                    sd.core_ep_counts[0] = cpucore[0]
                    
                    size = 0
                    getcpu = "hw.perflevel1.logicalcpu"
                    sysctlbyname(getcpu, nil, &size, nil, 0)
                    cpucore = [UInt8](repeating: 0,  count: size)
                    sysctlbyname(getcpu, &cpucore, &size, nil, 0)
                    
                    sd.core_ep_counts[1] = cpucore[0]
                }
            }
        } else if mode == 1 {
            size = 0
            let getcpu = "hw.logicalcpu"
            sysctlbyname(getcpu, nil, &size, nil, 0)
            var cpucore = [UInt8](repeating: 0,  count: size)
            sysctlbyname(getcpu, &cpucore, &size, nil, 0)
            
            sd.core_ep_counts[0] = cpucore[0]
        }
        
        var model_name = ""
        
        if let res = process(path: "/usr/sbin/system_profiler", arguments: ["SPHardwareDataType", "-json"]) {
            do {
                if let json = try JSONSerialization.jsonObject(with: Data(res.utf8), options: []) as? [String: Any], let obj = json["SPHardwareDataType"] as? [[String: Any]], !obj.isEmpty, let val = obj.first, let name = val["machine_name"] as? String {
                    model_name = name
                }
            } catch let err as NSError {
                print("error to parse system_profiler SPHardwareDataType: \(err.localizedDescription)")
                exit(1)
            }
        } else {
            // legacy
            // This method is proper up to M1 Max
            
            size = 0
            let getfan = "hw.model"
            sysctlbyname(getfan, nil, &size, nil, 0)
            var model = [CChar](repeating: 0,  count: size)
            sysctlbyname(getfan, &model, &size, nil, 0)
            
            if strcmp(model, "") != 0 {
                model.withUnsafeBufferPointer {
                    ptr in model_name += String(cString: ptr.baseAddress!)
                }
            }
        }
        
        if let count = SMC.shared.getValue("FNum") {
            switch count {
            case 0.0:
                sd.fan_exist = false
            case 1.0:
                sd.fan_mode = 1
            default:
                sd.fan_mode = 2
            }
        } else {
            sd.fan_exist = false
        }
        
        var servicedict: Unmanaged<CFMutableDictionary>? = nil
        
        if #available(macOS 12, *) {
            port = kIOMainPortDefault
        } else {
            port = kIOMasterPortDefault
        }
        
        func regAccessFailed(_ name: String) {
            print("Failed to access \(name) service in IORegistry")
            exit(1)
        }
        
        let option_bits = IOOptionBits(kIORegistryIterateRecursively + kIORegistryIterateParents)
        
        var name = "product"
        if let service = IOServiceNameMatching(name) {
            if IOServiceGetMatchingServices(port, service, &iter) != kIOReturnSuccess {
                regAccessFailed(name)
            }
        } else {
            regAccessFailed(name)
        }
        
        while case let entry = IOIteratorNext(iter), entry != IO_OBJECT_NULL {
            if let productname = IORegistryEntrySearchCFProperty(entry, kIOServicePlane, "product-name" as CFString, kCFAllocatorDefault, option_bits) {
                sd.marketing_name = ""
                let prodname = productname.bytes?.assumingMemoryBound(to: CChar.self)
                for ii in 0...productname.length {
                    sd.marketing_name += String(format: "%c", prodname![ii])
                }
            } else {
                print("Failed to read \"product-name\" from \(name) service in IORegistry")
                exit(1)
            }
            IOObjectRelease(entry)
        }
        
        name = "AppleARMIODevice"
        if let service = IOServiceMatching(name) {
            if IOServiceGetMatchingServices(port, service, &iter) != kIOReturnSuccess {
                regAccessFailed(name)
            }
        } else {
            regAccessFailed(name)
        }
        
        while case let entry = IOIteratorNext(iter), entry != IO_OBJECT_NULL {
            if IORegistryEntryCreateCFProperties(entry, &servicedict, kCFAllocatorDefault, 0) != kIOReturnSuccess {
                print("Failed to create CFProperties for \(name) service in IORegistry")
                exit(1)
            }
            
            guard let serviceDict = servicedict?.takeRetainedValue() as? [String : AnyObject] else { continue }
            
            //if case let data = serviceDict["clusters"], data != nil {
            if let data = serviceDict["clusters"] {
                let databytes = data.bytes?.assumingMemoryBound(to: UInt8.self)
                for ii in stride(from:0, to:data.length, by:4) {
                    let cores = UInt8(atoi(String(format: "%02x", databytes![ii])))
                    sd.cluster_core_counts.append(cores)
                    var die_num = 1
                    var exist = 1
                    while exist != 0 {
                        exist = 0
                        for i in sd.core_freq_channels {
                            if i == "DIE_\(die_num)_ECPU_CPU" {
                                sd.cluster_core_counts.append(cores)
                                die_num += 1
                                exist = 1
                            }
                        }
                    }
                    IOObjectRelease(entry)
                }
            }
        }
        
        name = "AGXAccelerator"
        if let service = IOServiceMatching(name) {
            if IOServiceGetMatchingServices(port, service, &iter) != kIOReturnSuccess {
                regAccessFailed(name)
            }
        } else {
            regAccessFailed(name)
        }
        
        while case let entry = IOIteratorNext(iter), entry != IO_OBJECT_NULL {
            if IORegistryEntryCreateCFProperties(entry, &servicedict, kCFAllocatorDefault, 0) != kIOReturnSuccess {
                print("Failed to create CFProperties for \(name) service in IORegistry")
                exit(1)
            }
            
            guard let serviceDict = servicedict?.takeRetainedValue() as? [String : AnyObject] else { continue }
            
            if let gpucorecnt = serviceDict["gpu-core-count"] {
                sd.gpu_core_count = gpucorecnt as? Int ?? 0
                IOObjectRelease(entry)
            } else {
                print("Failed to read \"gpu-core-count\" from \(name) service in IORegistry")
                exit(1)
            }
            
            if let gpuname = serviceDict["IOClass"] {
                sd.gpu_arch_name = gpuname as? String ?? ""
                if let range = sd.gpu_arch_name.range(of: name) {
                    sd.gpu_arch_name.removeSubrange(range)
                }
            } else {
                print("Failed to read \"gpu-arch-name\" from \(name) service in IORegistry")
                exit(1)
            }
            IOObjectRelease(entry)
        }
        IOObjectRelease(iter)
    }
}

func getOSCode(sd: inout static_data) {
    autoreleasepool {
        let code_file = File("/System/Library/CoreServices/Setup Assistant.app/Contents/Resources/en.lproj/OSXSoftwareLicense.rtf")
        while let code_line = code_file?.getLine() {
            if code_line.contains("SOFTWARE LICENSE AGREEMENT FOR macOS") {
                sd.os_code_name = String(code_line.split(separator: " ").last ?? "").replacingOccurrences(of: "\\\n", with: "")
            }
        }
    }
}

func generateProcessorName(sd: inout static_data) {
    autoreleasepool {
        var size = 0
        let getcpu = "machdep.cpu.brand_string"
        sysctlbyname(getcpu, nil, &size, nil, 0)
        var cpubrand = [CChar](repeating: 0,  count: size)
        sysctlbyname(getcpu, &cpubrand, &size, nil, 0)
        
        
        if strcmp(cpubrand, "") != 0 {
            var ttmp = ""
            cpubrand.withUnsafeBufferPointer {
                ptr in ttmp += String(cString: ptr.baseAddress!)
            }
            sd.extra.append(ttmp)
        } else {
            sd.extra.append("Unknown SoC")
        }
    }
}

func generateSiliconsIds(sd: inout static_data) {
    autoreleasepool {
        var iter = io_iterator_t()
        var port = mach_port_t()
        
        var servicedict: Unmanaged<CFMutableDictionary>? = nil
        
        if #available(macOS 12, *) {
            port = kIOMainPortDefault
        } else {
            port = kIOMasterPortDefault
        }
        
        if let service = IOServiceMatching("IOPlatformExpertDevice") {
            if IOServiceGetMatchingServices(port, service, &iter) != kIOReturnSuccess {
                siliconError(sd: &sd)
            }
        } else {
            siliconError(sd: &sd)
        }
        
        while case let entry = IOIteratorNext(iter), entry != IO_OBJECT_NULL {
            if IORegistryEntryCreateCFProperties(entry, &servicedict, kCFAllocatorDefault, 0) != kIOReturnSuccess {
                siliconError(sd: &sd)
            }
            
            guard let serviceDict = servicedict?.takeRetainedValue() as? [String : AnyObject] else { continue }
            if case let data = serviceDict["platform-name"], data != nil {
                sd.extra.append(String(
                    format: "%s",
                    (data?.bytes?.assumingMemoryBound(to: UInt8.self))!
                ))
            } else {
                siliconError(sd: &sd)
            }
            IOObjectRelease(entry)
        }
        IOObjectRelease(iter)
    }
}

func siliconError(sd: inout static_data) {
    autoreleasepool {
        var tmp: String? = "T****"
        if sd.extra.count == 0 {
            tmp = "T****"
        } else {
            let ttmp = sd.extra[0].lowercased()
            let socver = Int(
                ttmp.getRegexArr(regex: "m[0-9]+")[0].getRegexArr(regex: "[0-9]+")[0]
            )
            var socnum = 6000
            
            switch socver {
            case 1:
                if ttmp.contains("max") {
                    socnum += 1
                } else if ttmp.contains("ultra") {
                    socnum += 2
                } else if !ttmp.contains("pro") {
                    socnum = 8103
                }
            case 2:
                socnum += 20
                if ttmp.contains("max") {
                    socnum += 1
                } else if ttmp.contains("ultra") {
                    socnum += 2
                } else if ttmp.contains("extreme") {
                    socnum += 3
                } else if !ttmp.contains("pro") {
                    socnum = 8112
                }
            case 3:
                socnum += 30
                if ttmp.contains("max") {
                    if sd.core_ep_counts.reduce(0, +) < 16 {
                        socnum += 4
                    } else {
                        socnum += 1
                    }
                } else if !ttmp.contains("pro") {
                    socnum = 8122
                }
            case 4:
                socnum += 40
                if ttmp.contains("max") {
                    if sd.core_ep_counts.reduce(0, +) < 16 {
                        socnum += 4
                    } else {
                        socnum += 1
                    }
                } else if !ttmp.contains("pro") {
                    socnum = 8132
                }
            default:
                socnum = 0
            }
            if socnum != 0 {
                tmp = "T\(socnum)"
            }
        }
        sd.extra.append(tmp!)
        tmp = nil
    }
}

func generateMicroArchs(sd: inout static_data) {
    autoreleasepool {
        var port = mach_port_t()
        
        if #available(macOS 12, *) {
            port = kIOMainPortDefault
        } else {
            port = kIOMasterPortDefault
        }
        
        let tmpcore = sd.cluster_core_counts
        let cores = tmpcore[0] + tmpcore[1] - 1
        
        var service = IORegistryEntryFromPath(port, "IOService:/AppleARMPE/cpu0")
        if case let data = IORegistryEntryCreateCFProperty(service, "compatible" as CFString, kCFAllocatorDefault, 0), data != nil {
            sd.extra.append(String(
                format: "%s",
                (data?.takeRetainedValue().bytes?.assumingMemoryBound(to: UInt8.self))!
            ).replacingOccurrences(of: "apple,", with: "").capitalized)
        } else {
            archError(sd: &sd)
        }
        
        service = IORegistryEntryFromPath(port, String(format: "IOService:/AppleARMPE/cpu%d", cores))
        if case let data = IORegistryEntryCreateCFProperty(service, "compatible" as CFString, kCFAllocatorDefault, 0), data != nil {
            sd.extra.append(String(
                format: "%s",
                (data?.takeRetainedValue().bytes?.assumingMemoryBound(to: UInt8.self))!
            ).replacingOccurrences(of: "apple,", with: "").capitalized)
        } else {
            archError(sd: &sd)
        }
    }
}

func archError(sd: inout static_data) {
    var tmp = sd.extra
    if tmp.count == 0 {
        tmp.append("Unknown")
        tmp.append("Unknown")
    } else {
        let socnum = Int(
            tmp[0].lowercased().getRegexArr(regex: "M[0-9]+")[0].getRegexArr(regex: "[0-9]+")[0]
        )
        var archs: [String] = []
        
        switch socnum {
        case 1:
            archs = ["Icestorm", "Firestorm"]
        case 2:
            archs = ["Blizzard", "Avalanche"]
        case 3, 4:
            archs = ["Sawtooth", "Everest"]
        default:
            archs = ["Unknown", "Unknown"]
        }
        tmp += archs
    }
    
    sd.extra = tmp
}

func generateSocMax(sd: inout static_data) {
    if ["apple", "rosetta 2"].contains(sd.extra[sd.extra.count-1].lowercased()) {
        let tmp = sd.extra[0].lowercased()
        var ane_bw: Float?    = 7
        var ane_pwr: Float?   = 8
        var ane_ratio: Float? = 1
        let socnum = Int(
            tmp.getRegexArr(regex: "M[0-9]+")[0].getRegexArr(regex: "[0-9]+")[0]
        )
        switch socnum {
        case 1:
            if tmp.contains("pro") {
                sd.max_pwr = [30, 30]
                sd.max_bw  = [200, 200]
            } else if tmp.contains("max") {
                sd.max_pwr = [30, 60]
                sd.max_bw  = [250, 400]
            } else if tmp.contains("ultra") {
                sd.max_pwr = [60, 120]
                sd.max_bw  = [500, 800]
                ane_ratio  = 2
            } else {
                sd.max_pwr = [20, 20]
                sd.max_bw  = [70, 70]
            }
        case 2:
            if tmp.contains("pro") {
                sd.max_pwr = [30, 35]
                sd.max_bw  = [200, 200]
            } else if tmp.contains("max") {
                sd.max_pwr = [30, 70]
                sd.max_bw  = [250, 400]
            } else if tmp.contains("ultra") { // hmm...
                sd.max_pwr = [80, 140] // this is just my sweet dream
                sd.max_bw  = [500, 800] // for next gen mac studio and
                ane_ratio  = 2
            } else if tmp.contains("extreme") { // wish of all of us
                sd.max_pwr = [160, 280] // The apple silicon
                sd.max_bw  = [1000, 1600] // mac pro
                ane_ratio  = 4
            } else {
                sd.max_pwr = [20, 15]
                sd.max_bw  = [100, 100]
            }
        case 3:
            if tmp.contains("pro") {
                sd.max_pwr = [40, 40]
                sd.max_bw  = [150, 150]
            } else if tmp.contains("max") {
                sd.max_pwr = [55, 80]
                if sd.core_ep_counts.reduce(0, +) < 16 {
                    sd.max_bw  = [200, 300]
                } else {
                    sd.max_bw  = [250, 400]
                }
            } else if tmp.contains("ultra") { // hmm...
                sd.max_pwr = [110, 160] // this is just my sweet dream
                sd.max_bw  = [500, 800] // for next gen mac studio and
                ane_ratio  = 2
            } else if tmp.contains("extreme") { // wish of all of us
                sd.max_pwr = [220, 320] // The apple silicon
                sd.max_bw  = [1000, 1600] // mac pro
                ane_ratio  = 4
            } else {
                sd.max_pwr = [20, 20]
                sd.max_bw  = [100, 100]
            }
        default:
            sd.max_pwr = [20, 20]
            sd.max_bw  = [70, 70]
        }
        ane_pwr! *= ane_ratio!
        ane_bw!  *= ane_ratio!
        sd.max_pwr.append(ane_pwr!)
        sd.max_bw.append(ane_bw!)
        ane_pwr   = nil
        ane_bw    = nil
        ane_ratio = nil
    }
}

func generateFanLimit(sd: inout static_data, sense: [any Sensor_p]) {
    autoreleasepool {
        let sensecnt: Int? = sense.count
        for idx in 0..<sensecnt! {
            let sns: (any Sensor_p)? = sense[idx]
            let snsname: String? = sns!.name
            let snstype: SensorType? = sns!.type
            if snstype == SensorType.fan {
                if snsname != "Fastest Fan" {
                    var tmp = sns as! Fan?
                    var tmpmin: Double? = tmp!.minSpeed
                    var tmpmax: Double? = tmp!.maxSpeed
                    tmp = nil
                    if sd.fan_mode == 2 {
                        if snsname == "Left fan" {
                            sd.fan_limit[0][0] = tmpmin!
                            sd.fan_limit[0][1] = tmpmax!
                        } else {
                            sd.fan_limit[1][0] = tmpmin!
                            sd.fan_limit[1][1] = tmpmax!
                        }
                    } else if sd.fan_mode == 1 {
                        sd.fan_limit[0][0] = tmpmin!
                        sd.fan_limit[0][1] = tmpmax!
                    }
                    tmpmin = nil
                    tmpmax = nil
                }
            }
        }
    }
}
