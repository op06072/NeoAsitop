//
//  SystemKit.swift
//  socpowerbuddy_swift
//
//  Created by Eom SeHwan on 2022/09/17.
//

import Foundation

public enum Platform: String {
    case intel
    
    case m1
    case m1Pro
    case m1Max
    case m1Ultra
    
    case m2
    
    public static var apple: [Platform] {
        return [.m1, .m1Pro, .m1Max, .m1Ultra, .m2]
    }
    
    public static var all: [Platform] {
        return apple + [.intel]
    }
}

public enum deviceType: Int {
    case unknown = -1
    case macMini = 1
    case macPro = 2
    case imac = 3
    case imacpro = 4
    case macbook = 5
    case macbookAir = 6
    case macbookPro = 7
    case macStudio = 8
}

public enum coreType: Int {
    case unknown = -1
    case efficiency = 1
    case performance = 2
}

public struct model_s {
    public let name: String
    public let year: Int
    public let type: deviceType
}

public struct os_s {
    public let name: String
    public let version: OperatingSystemVersion
    public let build: String
}

public struct core_s {
    public var id: Int32
    public var name: String
    public var type: coreType
}

public struct cpu_s {
    public var name: String? = nil
    public var physicalCores: Int8? = nil
    public var logicalCores: Int8? = nil
    public var eCores: Int32? = nil
    public var pCores: Int32? = nil
    public var cores: [core_s]? = nil
}


public struct info_s {
    public var cpu: cpu_s? = nil
}

public struct device_s {
    public var model: model_s = model_s(name: localizedString("Unknown"), year: Calendar.current.component(.year, from: Date()), type: deviceType.unknown)
    public var modelIdentifier: String? = nil
    public var serialNumber: String? = nil
    public var bootDate: Date? = nil
    
    public var os: os_s? = nil
    public var info: info_s = info_s()
    public var platform: Platform? = nil
}

public class SystemKit {
    public static let shared = SystemKit()
    
    public var device: device_s = device_s()
    private let log: NextLog = NextLog.shared.copy(category: "SystemKit")
    
    public init() {
        if let modelName = self.modelName() {
            if let modelInfo = deviceDict[modelName] {
                self.device.model = modelInfo
            } else {
                print("unknown device \(modelName)")
            }
        }
        
        let procInfo = ProcessInfo()
        let systemVersion = procInfo.operatingSystemVersion
        
        var build = localizedString("Unknown")
        let buildArr = procInfo.operatingSystemVersionString.split(separator: "(")
        if buildArr.indices.contains(1) {
            build = buildArr[1].replacingOccurrences(of: "Build ", with: "").replacingOccurrences(of: ")", with: "")
        }
        
        let version = systemVersion.majorVersion > 10 ? "\(systemVersion.majorVersion)" : "\(systemVersion.majorVersion).\(systemVersion.minorVersion)"
        self.device.os = os_s(name: osDict[version] ?? localizedString("Unknown"), version: systemVersion, build: build)
        
        self.device.info.cpu = self.getCPUInfo()
        
        if let name = self.device.info.cpu?.name?.lowercased() {
            if name.contains("intel") {
                self.device.platform = .intel
            } else if name.contains("m1") {
                if name.contains("pro") {
                    self.device.platform = .m1Pro
                } else if name.contains("max") {
                    self.device.platform = .m1Max
                } else if name.contains("ultra") {
                    self.device.platform = .m1Ultra
                } else {
                    self.device.platform = .m1
                }
            } else if name.contains("m2") {
                self.device.platform = .m2
            }
        }
    }
    
    public func modelName() -> String? {
        var mib = [CTL_HW, HW_MODEL]
        var size = MemoryLayout<io_name_t>.size
        
        let pointer = UnsafeMutablePointer<io_name_t>.allocate(capacity: 1)
        defer {
            pointer.deallocate()
        }
        let result = sysctl(&mib, u_int(mib.count), pointer, &size, nil, 0)
        
        if result == KERN_SUCCESS {
            return String(cString: UnsafeRawPointer(pointer).assumingMemoryBound(to: CChar.self))
        }
        
        print("error call sysctl(): \(String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error")")
        return nil
    }
    
    private func getCPUInfo() -> cpu_s? {
        var cpu = cpu_s()
        
        var sizeOfName = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &sizeOfName, nil, 0)
        var nameChars = [CChar](repeating: 0, count: sizeOfName)
        sysctlbyname("machdep.cpu.brand_string", &nameChars, &sizeOfName, nil, 0)
        var name = String(cString: nameChars)
        if name != "" {
            name = name.replacingOccurrences(of: "(TM)", with: "")
            name = name.replacingOccurrences(of: "(R)", with: "")
            name = name.replacingOccurrences(of: "CPU", with: "")
            name = name.replacingOccurrences(of: "@", with: "")
            
            cpu.name = name.condenseWhitespace()
        }
        
        var size = UInt32(MemoryLayout<host_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
        let hostInfo = host_basic_info_t.allocate(capacity: 1)
        defer {
            hostInfo.deallocate()
        }
        
        let result = hostInfo.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
            host_info(mach_host_self(), HOST_BASIC_INFO, $0, &size)
        }
        
        if result != KERN_SUCCESS {
            print("read cores number: \(String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error")")
            return nil
        }
        
        let data = hostInfo.move()
        cpu.physicalCores = Int8(data.physical_cpu)
        cpu.logicalCores = Int8(data.logical_cpu)
        
        if let cores = getCPUCores() {
            cpu.eCores = cores.0
            cpu.pCores = cores.1
            cpu.cores = cores.2
        }
        
        return cpu
    }
    
    func getCPUCores() -> (Int32?, Int32?, [core_s])? {
        var iterator: io_iterator_t = io_iterator_t()
        let result = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("AppleARMPE"), &iterator)
        if result != kIOReturnSuccess {
            print("Error find AppleARMPE: " + (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
            return nil
        }
        
        var service: io_registry_entry_t = 1
        var list: [core_s] = []
        var pCores: Int32? = nil
        var eCores: Int32? = nil
        
        while service != 0 {
            service = IOIteratorNext(iterator)
            
            var entry: io_iterator_t = io_iterator_t()
            if IORegistryEntryGetChildIterator(service, kIOServicePlane, &entry) != kIOReturnSuccess {
                continue
            }
            var child: io_registry_entry_t = 1
            while child != 0 {
                child = IOIteratorNext(entry)
                guard child != 0 else {
                    continue
                }
                
                guard let name = getIOName(child),
                      let props = getIOProperties(child) else { continue }
                
                if name.matches("^cpu\\d") {
                    var type: coreType = .unknown
                    
                    if let rawType = props.object(forKey: "cluster-type") as? Data,
                       let typ = String(data: rawType, encoding: .utf8)?.trimmed {
                        switch typ {
                        case "E":
                            type = .efficiency
                        case "P":
                            type = .performance
                        default:
                            type = .unknown
                        }
                    }
                    
                    let rawCPUId = props.object(forKey: "cpu-id") as? Data
                    let id = rawCPUId?.withUnsafeBytes { pointer in
                        return pointer.load(as: Int32.self)
                    }
                    
                    list.append(core_s(id: id ?? -1, name: name, type: type))
                } else if name.trimmed == "cpus" {
                    eCores = (props.object(forKey: "e-core-count") as? Data)?.withUnsafeBytes { pointer in
                        return pointer.load(as: Int32.self)
                    }
                    pCores = (props.object(forKey: "p-core-count") as? Data)?.withUnsafeBytes { pointer in
                        return pointer.load(as: Int32.self)
                    }
                }
                
                IOObjectRelease(child)
            }
            IOObjectRelease(entry)
            
            IOObjectRelease(service)
        }
        
        IOObjectRelease(iterator)
        
        return (eCores, pCores, list)
    }
}

let deviceDict: [String: model_s] = [
    // Mac Mini
    "Macmini6,1": model_s(name: "Mac mini", year: 2012, type: deviceType.macMini),
    "Macmini6,2": model_s(name: "Mac mini", year: 2012, type: deviceType.macMini),
    "Macmini7,1": model_s(name: "Mac mini", year: 2014, type: deviceType.macMini),
    "Macmini8,1": model_s(name: "Mac mini", year: 2018, type: deviceType.macMini),
    "Macmini9,1": model_s(name: "Mac mini (M1)", year: 2020, type: deviceType.macMini),
    
    // Mac Studio
    "Mac13,1": model_s(name: "Mac Studio (M1 Max)", year: 2022, type: deviceType.macStudio),
    "Mac13,2": model_s(name: "Mac Studio (M1 Ultra)", year: 2022, type: deviceType.macStudio),
    
    // Mac Pro
    "MacPro5,1": model_s(name: "Mac Pro", year: 2010, type: deviceType.macPro),
    "MacPro6,1": model_s(name: "Mac Pro", year: 2016, type: deviceType.macPro),
    "MacPro7,1": model_s(name: "Mac Pro", year: 2019, type: deviceType.macPro),
    
    // iMac
    "iMac12,1": model_s(name: "iMac 27-Inch", year: 2011, type: deviceType.imac),
    "iMac13,1": model_s(name: "iMac 21.5-Inch", year: 2012, type: deviceType.imac),
    "iMac13,2": model_s(name: "iMac 27-Inch", year: 2012, type: deviceType.imac),
    "iMac14,2": model_s(name: "iMac 27-Inch", year: 2013, type: deviceType.imac),
    "iMac15,1": model_s(name: "iMac 27-Inch", year: 2014, type: deviceType.imac),
    "iMac17,1": model_s(name: "iMac 27-Inch", year: 2015, type: deviceType.imac),
    "iMac18,1": model_s(name: "iMac 21.5-Inch", year: 2017, type: deviceType.imac),
    "iMac18,2": model_s(name: "iMac 21.5-Inch", year: 2017, type: deviceType.imac),
    "iMac18,3": model_s(name: "iMac 27-Inch", year: 2017, type: deviceType.imac),
    "iMac19,1": model_s(name: "iMac 27-Inch", year: 2019, type: deviceType.imac),
    "iMac20,1": model_s(name: "iMac 27-Inch", year: 2020, type: deviceType.imac),
    "iMac20,2": model_s(name: "iMac 27-Inch", year: 2020, type: deviceType.imac),
    "iMac21,1": model_s(name: "iMac 24-Inch (M1)", year: 2021, type: deviceType.imac),
    "iMac21,2": model_s(name: "iMac 24-Inch (M1)", year: 2021, type: deviceType.imac),
    
    // iMac Pro
    "iMacPro1,1": model_s(name: "iMac Pro", year: 2017, type: deviceType.imacpro),
    
    // MacBook
    "MacBook8,1": model_s(name: "MacBook", year: 2015, type: deviceType.macbook),
    "MacBook9,1": model_s(name: "MacBook", year: 2016, type: deviceType.macbook),
    "MacBook10,1": model_s(name: "MacBook", year: 2017, type: deviceType.macbook),
    
    // MacBook Air
    "MacBookAir5,1": model_s(name: "MacBook Air 11\"", year: 2012, type: deviceType.macbookAir),
    "MacBookAir5,2": model_s(name: "MacBook Air 13\"", year: 2012, type: deviceType.macbookAir),
    "MacBookAir6,1": model_s(name: "MacBook Air 11\"", year: 2014, type: deviceType.macbookAir),
    "MacBookAir6,2": model_s(name: "MacBook Air 13\"", year: 2014, type: deviceType.macbookAir),
    "MacBookAir7,1": model_s(name: "MacBook Air 11\"", year: 2015, type: deviceType.macbookAir),
    "MacBookAir7,2": model_s(name: "MacBook Air 13\"", year: 2015, type: deviceType.macbookAir),
    "MacBookAir8,1": model_s(name: "MacBook Air 13\"", year: 2018, type: deviceType.macbookAir),
    "MacBookAir8,2": model_s(name: "MacBook Air 13\"", year: 2019, type: deviceType.macbookAir),
    "MacBookAir9,1": model_s(name: "MacBook Air 13\"", year: 2020, type: deviceType.macbookAir),
    "MacBookAir10,1": model_s(name: "MacBook Air 13\" (M1)", year: 2020, type: deviceType.macbookAir),
    "Mac14,2": model_s(name: "MacBook Air 13\" (M2)", year: 2022, type: deviceType.macbookAir),
    
    // MacBook Pro
    "MacBookPro9,1": model_s(name: "MacBook Pro 15\"", year: 2012, type: deviceType.macbookPro),
    "MacBookPro9,2": model_s(name: "MacBook Pro 13\"", year: 2012, type: deviceType.macbookPro),
    "MacBookPro10,1": model_s(name: "MacBook Pro 15\"", year: 2012, type: deviceType.macbookPro),
    "MacBookPro10,2": model_s(name: "MacBook Pro 13\"", year: 2012, type: deviceType.macbookPro),
    "MacBookPro11,1": model_s(name: "MacBook Pro 13\"", year: 2014, type: deviceType.macbookPro),
    "MacBookPro11,2": model_s(name: "MacBook Pro 15\"", year: 2014, type: deviceType.macbookPro),
    "MacBookPro11,3": model_s(name: "MacBook Pro 15\"", year: 2014, type: deviceType.macbookPro),
    "MacBookPro11,4": model_s(name: "MacBook Pro 15\"", year: 2015, type: deviceType.macbookPro),
    "MacBookPro11,5": model_s(name: "MacBook Pro 15\"", year: 2015, type: deviceType.macbookPro),
    "MacBookPro12,1": model_s(name: "MacBook Pro 13\"", year: 2015, type: deviceType.macbookPro),
    "MacBookPro13,1": model_s(name: "MacBook Pro 13\"", year: 2016, type: deviceType.macbookPro),
    "MacBookPro13,2": model_s(name: "MacBook Pro 13\"", year: 2016, type: deviceType.macbookPro),
    "MacBookPro13,3": model_s(name: "MacBook Pro 15\"", year: 2016, type: deviceType.macbookPro),
    "MacBookPro14,1": model_s(name: "MacBook Pro 13\"", year: 2017, type: deviceType.macbookPro),
    "MacBookPro14,2": model_s(name: "MacBook Pro 13\"", year: 2017, type: deviceType.macbookPro),
    "MacBookPro14,3": model_s(name: "MacBook Pro 15\"", year: 2017, type: deviceType.macbookPro),
    "MacBookPro15,1": model_s(name: "MacBook Pro 15\"", year: 2018, type: deviceType.macbookPro),
    "MacBookPro15,2": model_s(name: "MacBook Pro 13\"", year: 2019, type: deviceType.macbookPro),
    "MacBookPro15,3": model_s(name: "MacBook Pro 15\"", year: 2019, type: deviceType.macbookPro),
    "MacBookPro15,4": model_s(name: "MacBook Pro 13\"", year: 2019, type: deviceType.macbookPro),
    "MacBookPro16,1": model_s(name: "MacBook Pro 16\"", year: 2019, type: deviceType.macbookPro),
    "MacBookPro16,2": model_s(name: "MacBook Pro 13\"", year: 2019, type: deviceType.macbookPro),
    "MacBookPro16,3": model_s(name: "MacBook Pro 13\"", year: 2020, type: deviceType.macbookPro),
    "MacBookPro17,1": model_s(name: "MacBook Pro 13\" (M1)", year: 2020, type: deviceType.macbookPro),
    "MacBookPro18,1": model_s(name: "MacBook Pro 16\" (M1 Pro)", year: 2021, type: deviceType.macbookPro),
    "MacBookPro18,2": model_s(name: "MacBook Pro 16\" (M1 Max)", year: 2021, type: deviceType.macbookPro),
    "MacBookPro18,3": model_s(name: "MacBook Pro 14\" (M1 Pro)", year: 2021, type: deviceType.macbookPro),
    "MacBookPro18,4": model_s(name: "MacBook Pro 14\" (M1 Max)", year: 2021, type: deviceType.macbookPro),
    "Mac14,7": model_s(name: "MacBook Pro 13\" (M2)", year: 2022, type: deviceType.macbookPro)
]

let osDict: [String: String] = [
    "10.13": "High Sierra",
    "10.14": "Mojave",
    "10.15": "Catalina",
    "11": "Big Sur",
    "12": "Monterey",
    "13": "Ventura"
]
