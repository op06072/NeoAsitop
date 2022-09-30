//
//  helper.swift
//  socpowerbuddy_swift
//
//  Created by Eom SeHwan on 2022/09/17.
//

import ServiceManagement
import UserNotifications

public struct Version {
    var major: Int = 0
    var minor: Int = 0
    var patch: Int = 0
    
    var beta: Int? = nil
}

public class Store {
    public static let shared = Store()
    private let defaults = UserDefaults.standard
    
    public init() {}
    
    public func exist(key: String) -> Bool {
        return self.defaults.object(forKey: key) == nil ? false : true
    }
    
    public func remove(_ key: String) {
        self.defaults.removeObject(forKey: key)
    }
    
    public func bool(key: String, defaultValue value: Bool) -> Bool {
        return !self.exist(key: key) ? value : defaults.bool(forKey: key)
    }
    
    public func string(key: String, defaultValue value: String) -> String {
        return (!self.exist(key: key) ? value : defaults.string(forKey: key))!
    }
    
    public func int(key: String, defaultValue value: Int) -> Int {
        return (!self.exist(key: key) ? value : defaults.integer(forKey: key))
    }
    
    public func set(key: String, value: Bool) {
        self.defaults.set(value, forKey: key)
    }
    
    public func set(key: String, value: String) {
        self.defaults.set(value, forKey: key)
    }
    
    public func set(key: String, value: Int) {
        self.defaults.set(value, forKey: key)
    }
    
    public func reset() {
        self.defaults.dictionaryRepresentation().keys.forEach { key in
            self.defaults.removeObject(forKey: key)
        }
    }
}

private protocol DeprecationWarningWorkaround {
    static var jobsDict: [[String: AnyObject]]? { get }
}

public protocol KeyValue_p {
    var key: String { get }
    var value: String { get }
    var additional: Any? { get }
}

public struct KeyValue_t: KeyValue_p {
    public let key: String
    public let value: String
    public let additional: Any?
    
    public init(key: String, value: String, additional: Any? = nil) {
        self.key = key
        self.value = value
        self.additional = additional
    }
}

public struct Units {
    public let bytes: Int64
    
    public init(bytes: Int64) {
        self.bytes = bytes
    }
    
    public var kilobytes: Double {
        return Double(bytes) / 1_024
    }
    public var megabytes: Double {
        return kilobytes / 1_024
    }
    public var gigabytes: Double {
        return megabytes / 1_024
    }
    public var terabytes: Double {
        return gigabytes / 1_024
    }
    
    public func getReadableTuple(base: DataSizeBase = .byte) -> (String, String) {
        let stringBase = base == .byte ? "B" : "b"
        let multiplier: Double = base == .byte ? 1 : 8
        
        switch bytes {
        case 0..<1_024:
            return ("0", "K\(stringBase)/s")
        case 1_024..<(1_024 * 1_024):
            return (String(format: "%.0f", kilobytes*multiplier), "K\(stringBase)/s")
        case 1_024..<(1_024 * 1_024 * 100):
            return (String(format: "%.1f", megabytes*multiplier), "M\(stringBase)/s")
        case (1_024 * 1_024 * 100)..<(1_024 * 1_024 * 1_024):
            return (String(format: "%.0f", megabytes*multiplier), "M\(stringBase)/s")
        case (1_024 * 1_024 * 1_024)...Int64.max:
            return (String(format: "%.1f", gigabytes*multiplier), "G\(stringBase)/s")
        default:
            return (String(format: "%.0f", kilobytes*multiplier), "K\(stringBase)B/s")
        }
    }
    
    public func getReadableSpeed(base: DataSizeBase = .byte, omitUnits: Bool = false) -> String {
        let stringBase = base == .byte ? "B" : "b"
        let multiplier: Double = base == .byte ? 1 : 8
        
        switch bytes*Int64(multiplier) {
        case 0..<1_024:
            let unit = omitUnits ? "" : " K\(stringBase)/s"
            return "0\(unit)"
        case 1_024..<(1_024 * 1_024):
            let unit = omitUnits ? "" : " K\(stringBase)/s"
            return String(format: "%.0f\(unit)", kilobytes*multiplier)
        case 1_024..<(1_024 * 1_024 * 100):
            let unit = omitUnits ? "" : " M\(stringBase)/s"
            return String(format: "%.1f\(unit)", megabytes*multiplier)
        case (1_024 * 1_024 * 100)..<(1_024 * 1_024 * 1_024):
            let unit = omitUnits ? "" : " M\(stringBase)/s"
            return String(format: "%.0f\(unit)", megabytes*multiplier)
        case (1_024 * 1_024 * 1_024)...Int64.max:
            let unit = omitUnits ? "" : " G\(stringBase)/s"
            return String(format: "%.1f\(unit)", gigabytes*multiplier)
        default:
            let unit = omitUnits ? "" : " K\(stringBase)/s"
            return String(format: "%.0f\(unit)", kilobytes*multiplier)
        }
    }
    
    public func getReadableMemory() -> String {
        switch bytes {
        case 0..<1_024:
            return "0 KB"
        case 1_024..<(1_024 * 1_024):
            return String(format: "%.0f KB", kilobytes)
        case 1_024..<(1_024 * 1_024 * 1_024):
            return String(format: "%.0f MB", megabytes)
        case 1_024..<(1_024 * 1_024 * 1_024 * 1_024):
            return String(format: "%.1f GB", gigabytes)
        case (1_024 * 1_024 * 1_024 * 1_024)...Int64.max:
            return String(format: "%.1f TB", terabytes)
        default:
            return String(format: "%.0f KB", kilobytes)
        }
    }
}

public func getIOProperties(_ entry: io_registry_entry_t) -> NSDictionary? {
    var properties: Unmanaged<CFMutableDictionary>? = nil
    
    if IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0) != kIOReturnSuccess {
        return nil
    }
    
    defer {
        properties?.release()
    }
    
    return properties?.takeUnretainedValue()
}

public func getIOName(_ entry: io_registry_entry_t) -> String? {
    let pointer = UnsafeMutablePointer<io_name_t>.allocate(capacity: 1)
    
    let result = IORegistryEntryGetName(entry, pointer)
    if result != kIOReturnSuccess {
        print("Error IORegistryEntryGetName(): " + (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
        return nil
    }
    
    return String(cString: UnsafeRawPointer(pointer).assumingMemoryBound(to: CChar.self))
}

public func localizedString(_ key: String, _ params: String..., comment: String = "") -> String {
    var string = NSLocalizedString(key, comment: comment)
    if !params.isEmpty {
        for (index, param) in params.enumerated() {
            string = string.replacingOccurrences(of: "%\(index)", with: param)
        }
    }
    return string
}

public extension UnitTemperature {
    static var system: UnitTemperature {
        let measureFormatter = MeasurementFormatter()
        let measurement = Measurement(value: 0, unit: UnitTemperature.celsius)
        return measureFormatter.string(from: measurement).hasSuffix("C") ? .celsius : .fahrenheit
    }
    
    static var current: UnitTemperature {
        let stringUnit: String = Store.shared.string(key: "temperature_units", defaultValue: "system")
        var unit = UnitTemperature.system
        if stringUnit != "system" {
            if let value = TemperatureUnits.first(where: { $0.key == stringUnit }), let temperatureUnit = value.additional as? UnitTemperature {
                unit = temperatureUnit
            }
        }
        return unit
    }
}

// swiftlint:disable identifier_name
public func Temperature(_ value: Double, defaultUnit: UnitTemperature = UnitTemperature.celsius) -> String {
    let formatter = MeasurementFormatter()
    formatter.locale = Locale.init(identifier: "en_US")
    formatter.numberFormatter.maximumFractionDigits = 0
    formatter.unitOptions = .providedUnit
    
    var measurement = Measurement(value: value, unit: defaultUnit)
    measurement.convert(to: UnitTemperature.current)
    
    return formatter.string(from: measurement)
}

public func sysctlByName(_ name: String) -> Int64 {
    var num: Int64 = 0
    var size = MemoryLayout<Int64>.size
    
    if sysctlbyname(name, &num, &size, nil, 0) != 0 {
        print(POSIXError.Code(rawValue: errno).map { POSIXError($0) } ?? CocoaError(.fileReadUnknown))
    }
    
    return num
}
