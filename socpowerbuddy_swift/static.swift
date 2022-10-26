//
//  static.swift
//  socpowerbuddy_swift
//
//  Created by Eom SeHwan on 2022/09/14.
//

import Foundation

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
            let service:CFMutableDictionary! = IOServiceMatching("AppleARMIODevice")
            if (service == nil) {
                print("Failed to find AppleARMIODevice service in IORegistry")
                exit(1)
            }
            if IOServiceGetMatchingServices(port, service, &iter) != kIOReturnSuccess {
                print("Failed to access AppleARMIODevice service in IORegistry")
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
        
        size = 0
        let getfan = "hw.model"
        sysctlbyname(getfan, nil, &size, nil, 0)
        var model = [CChar](repeating: 0,  count: size)
        sysctlbyname(getfan, &model, &size, nil, 0)

        if strcmp(model, "") != 0 {
            var ttmp = ""
            model.withUnsafeBufferPointer {
                ptr in ttmp += String(cString: ptr.baseAddress!)
            }
            if ttmp.lowercased().contains("air") {
                sd.fan_exist = false
            } else if ttmp.lowercased().contains("mini") {
                sd.fan_mode = 1
            } else {
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
        
        var service = IOServiceMatching("AppleARMIODevice")
        if service == nil {
            print("Failed to find AppleARMIODevice service in IORegistry")
            exit(1)
        }
        if IOServiceGetMatchingServices(port, service, &iter) != kIOReturnSuccess {
            print("Failed to access AppleARMIODevice service in IORegistry")
            exit(1)
        }
        
        while case let entry = IOIteratorNext(iter), entry != IO_OBJECT_NULL {
            if IORegistryEntryCreateCFProperties(entry, &servicedict, kCFAllocatorDefault, 0) != kIOReturnSuccess {
                print("Failed to create CFProperties for AppleARMIODevice service in IORegistry")
                exit(1)
            }
            
            guard let serviceDict = servicedict?.takeRetainedValue() as? [String : AnyObject] else { continue }
            
            if case let data = serviceDict["clusters"], data != nil {
                let databytes = data?.bytes?.assumingMemoryBound(to: UInt8.self)
                for ii in stride(from:0, to:data!.length, by:4) {
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
        
        service = IOServiceMatching("AGXAccelerator")
        if (service == nil) {
            print("Failed to find AGXAccelerator service in IORegistry")
            exit(1)
        }
        if IOServiceGetMatchingServices(port, service, &iter) != kIOReturnSuccess {
            print("Failed to access AGXAccelerator service in IORegistry")
            exit(1)
        }
        
        while case let entry = IOIteratorNext(iter), entry != IO_OBJECT_NULL {
            let gpucorecnt = IORegistryEntrySearchCFProperty(entry, kIOServicePlane, "gpu-core-count" as CFString, kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively + kIORegistryIterateParents))
            if (gpucorecnt == nil) {
                print("Failed to read \"gpu-core-count\" from AGXAccelerator service in IORegistry")
                exit(1)
            }
            sd.gpu_core_count = gpucorecnt as? Int ?? 0
            IOObjectRelease(entry)
        }
        IOObjectRelease(iter)
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
        
        let service = IOServiceMatching("IOPlatformExpertDevice")
        if service == nil {
            siliconError(sd: &sd)
        }
        if IOServiceGetMatchingServices(port, service, &iter) != kIOReturnSuccess {
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
        var tmp = ""
        if sd.extra.count == 0 {
            tmp = "T****"
        } else {
            let ttmp = sd.extra[0]
            if ttmp.contains("M1") {
                if ttmp.contains("Pro") {
                    tmp = "T6000"
                } else if ttmp.contains("Max") {
                    tmp = "T6001"
                } else if ttmp.contains("Ultra") {
                    tmp = "T6002"
                } else {
                    tmp = "T8103"
                }
            } else if ttmp.contains("M2") {
                if ttmp == "Apple M2" {
                    tmp = "T8112"
                }
            } else {
                tmp = "T****"
            }
        }
        sd.extra.append(tmp)
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
            ))
        } else {
            archError(sd: &sd)
        }
        
        service = IORegistryEntryFromPath(port, String(format: "IOService:/AppleARMPE/cpu%d", cores))
        if case let data = IORegistryEntryCreateCFProperty(service, "compatible" as CFString, kCFAllocatorDefault, 0), data != nil {
            sd.extra.append(String(
                format: "%s",
                (data?.takeRetainedValue().bytes?.assumingMemoryBound(to: UInt8.self))!
            ))
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
        let ttmp = tmp[0]
        if ttmp.contains("M1") {
            tmp.append("Icestorm")
            tmp.append("Firestorm")
        } else if ttmp.contains("M2") {
            tmp.append("Blizzard")
            tmp.append("Avalanche")
        } else {
            tmp.append("Unknown")
            tmp.append("Unknown")
        }
    }
    
    sd.extra = tmp
}

func generateSocMax(sd: inout static_data) {
    if ["apple", "rosetta 2"].contains(sd.extra[sd.extra.count-1].lowercased()) {
        let tmp = sd.extra[0].lowercased()
        if tmp.contains("m1") {
            if tmp.contains("pro") {
                sd.max_pwr = [30, 30]
                sd.max_bw = [200, 200]
            } else if tmp.contains("max") {
                sd.max_pwr = [30, 60]
                sd.max_bw = [250, 400]
            } else if tmp.contains("ultra") {
                sd.max_pwr = [60, 120]
                sd.max_bw = [500, 800]
            } else {
                sd.max_pwr = [20, 20]
                sd.max_bw = [70, 70]
            }
        } else if tmp.contains("m2") {
            if tmp.contains("m2 ") {
                
            } else {
                sd.max_pwr = [25, 15]
                sd.max_bw = [100, 100]
            }
        } else {
            sd.max_pwr = [20, 20]
            sd.max_bw = [70, 70]
        }
    }
}
