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

let osDict: [String: String] = [
    "10.13": "High Sierra",
    "10.14": "Mojave",
    "10.15": "Catalina",
    "11": "Big Sur",
    "12": "Monterey",
    "13": "Ventura"
]
