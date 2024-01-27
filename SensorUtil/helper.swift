//
//  helper.swift
//  socpowerbuddy_swift
//
//  Created by Eom SeHwan on 2022/09/17.
//

import ServiceManagement
import UserNotifications

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

public protocol KeyValue_p {
    var key: String { get }
    var value: String { get }
    var additional: Any? { get }
}

public struct KeyValue_t: KeyValue_p, Codable {
    public let key: String
    public let value: String
    public let additional: Any?
    
    private enum CodingKeys: String, CodingKey {
        case key, value
    }
    
    public init(key: String, value: String, additional: Any? = nil) {
        self.key = key
        self.value = value
        self.additional = additional
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try container.decode(String.self, forKey: .key)
        self.value = try container.decode(String.self, forKey: .value)
        self.additional = nil
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key, forKey: .key)
        try container.encode(value, forKey: .value)
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
    defer {
        pointer.deallocate()
    }
    
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
