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

public struct LaunchAtLogin {
    private static let id = "\(Bundle.main.bundleIdentifier!).LaunchAtLogin"
    
    public static var isEnabled: Bool {
        get {
            guard let jobs = (LaunchAtLogin.self as DeprecationWarningWorkaround.Type).jobsDict else {
                return false
            }
            let job = jobs.first { $0["Label"] as! String == id }
            return job?["OnDemand"] as? Bool ?? false
        }
        set {
            SMLoginItemSetEnabled(id as CFString, newValue)
        }
    }
}

private protocol DeprecationWarningWorkaround {
    static var jobsDict: [[String: AnyObject]]? { get }
}

extension LaunchAtLogin: DeprecationWarningWorkaround {
    @available(*, deprecated)
    static var jobsDict: [[String: AnyObject]]? {
        SMCopyAllJobDictionaries(kSMDomainUserLaunchd)?.takeRetainedValue() as? [[String: AnyObject]]
    }
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

public struct DiskSize {
    public let value: Int64
    
    public init(_ size: Int64) {
        self.value = size
    }
    
    public var kilobytes: Double {
        return Double(value) / 1_000
    }
    public var megabytes: Double {
        return kilobytes / 1_000
    }
    public var gigabytes: Double {
        return megabytes / 1_000
    }
    public var terabytes: Double {
        return gigabytes / 1_000
    }
    
    public func getReadableMemory() -> String {
        switch value {
        case 0..<1_000:
            return "0 KB"
        case 1_000..<(1_000 * 1_000):
            return String(format: "%.0f KB", kilobytes)
        case 1_000..<(1_000 * 1_000 * 1_000):
            return String(format: "%.0f MB", megabytes)
        case 1_000..<(1_000 * 1_000 * 1_000 * 1_000):
            return String(format: "%.1f GB", gigabytes)
        case (1_000 * 1_000 * 1_000 * 1_000)...Int64.max:
            return String(format: "%.1f TB", terabytes)
        default:
            return String(format: "%.0f KB", kilobytes)
        }
    }
}

public extension Array where Element: Equatable {
    func allEqual() -> Bool {
        if let firstElem = first {
            return !dropFirst().contains { $0 != firstElem }
        }
        return true
    }
}

public extension Array where Element: Hashable {
    func difference(from other: [Element]) -> [Element] {
        let thisSet = Set(self)
        let otherSet = Set(other)
        return Array(thisSet.symmetricDifference(otherSet))
    }
}

public func asyncShell(_ args: String) {
    let task = Process()
    task.launchPath = "/bin/sh"
    task.arguments = ["-c", args]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.launch()
}

public func syncShell(_ args: String) -> String {
    let task = Process()
    task.launchPath = "/bin/sh"
    task.arguments = ["-c", args]
    let pipe = Pipe()
    
    task.standardOutput = pipe
    task.launch()
    task.waitUntilExit()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)!
    
    return output
}

public func isNewestVersion(currentVersion: String, latestVersion: String) -> Bool {
    let currentNumber = currentVersion.replacingOccurrences(of: "v", with: "")
    let latestNumber = latestVersion.replacingOccurrences(of: "v", with: "")
    
    let currentArray = currentNumber.condenseWhitespace().split(separator: ".")
    let latestArray = latestNumber.condenseWhitespace().split(separator: ".")
    
    var current = Version(major: Int(currentArray[0]) ?? 0, minor: Int(currentArray[1]) ?? 0, patch: Int(currentArray[2]) ?? 0)
    var latest = Version(major: Int(latestArray[0]) ?? 0, minor: Int(latestArray[1]) ?? 0, patch: Int(latestArray[2]) ?? 0)
    
    if let patch = currentArray.last, patch.contains("-") {
        let arr = patch.split(separator: "-")
        if let patchNumber = arr.first {
            current.patch = Int(patchNumber) ?? 0
        }
        if let beta = arr.last {
            current.beta = Int(beta.replacingOccurrences(of: "beta", with: "")) ?? 0
        }
    }
    
    if let patch = latestArray.last, patch.contains("-") {
        let arr = patch.split(separator: "-")
        if let patchNumber = arr.first {
            latest.patch = Int(patchNumber) ?? 0
        }
        if let beta = arr.last {
            latest.beta = Int(beta.replacingOccurrences(of: "beta", with: "")) ?? 0
        }
    }
    
    // current is not beta + latest is not beta
    if current.beta == nil && latest.beta == nil {
        if latest.major > current.major {
            return true
        }
        
        if latest.minor > current.minor && latest.major >= current.major {
            return true
        }
        
        if latest.patch > current.patch && latest.minor >= current.minor && latest.major >= current.major {
            return true
        }
    }
    
    // current version is beta + last version is not beta
    if current.beta != nil && latest.beta == nil {
        if latest.major > current.major {
            return true
        }
        
        if latest.minor > current.minor && latest.major >= current.major {
            return true
        }
        
        if latest.patch >= current.patch && latest.minor >= current.minor && latest.major >= current.major {
            return true
        }
    }
    
    // current version is beta + last version is beta
    if current.beta != nil && latest.beta != nil {
        if latest.major > current.major {
            return true
        }
        
        if latest.minor > current.minor && latest.major >= current.major {
            return true
        }
        
        if latest.patch >= current.patch && latest.minor >= current.minor && latest.major >= current.major {
            return true
        }
        
        if latest.beta! > current.beta! && latest.patch >= current.patch && latest.minor >= current.minor && latest.major >= current.major {
            return true
        }
    }
    
    return false
}

@available(macOS 10.14, *)
public func showNotification(title: String, subtitle: String? = nil, userInfo: [AnyHashable: Any] = [:], delegate: UNUserNotificationCenterDelegate? = nil) -> String {
    let id = UUID().uuidString
    
    let content = UNMutableNotificationContent()
    content.title = title
    if let value = subtitle {
        content.subtitle = value
    }
    content.userInfo = userInfo
    content.sound = UNNotificationSound.default
    
    let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
    let center = UNUserNotificationCenter.current()
    center.delegate = delegate
    
    center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    center.add(request) { (error: Error?) in
        if let err = error {
            print(err)
        }
    }
    
    return id
}

@available(macOS 10.14, *)
public func removeNotification(_ id: String) {
    let center = UNUserNotificationCenter.current()
    center.removeDeliveredNotifications(withIdentifiers: [id])
}

public func showNSNotification(title: String, subtitle: String? = nil, body: String? = nil, userInfo: [AnyHashable: Any] = [:]) -> String {
    let notification = NSUserNotification()
    let id = UUID().uuidString
    
    notification.identifier = id
    notification.title = title
    notification.subtitle = subtitle
    notification.informativeText = body
    notification.soundName = NSUserNotificationDefaultSoundName
    notification.hasActionButton = false
    
    NSUserNotificationCenter.default.deliver(notification)
    
    return id
}

public func removeNSNotification(_ id: String) {
    let notificationCenter = NSUserNotificationCenter.default
    if let notification = notificationCenter.deliveredNotifications.first(where: { $0.identifier == id }) {
        notificationCenter.removeScheduledNotification(notification)
    }
}

public func getIOParent(_ obj: io_registry_entry_t) -> io_registry_entry_t? {
    var parent: io_registry_entry_t = 0
    
    if IORegistryEntryGetParentEntry(obj, kIOServicePlane, &parent) != KERN_SUCCESS {
        return nil
    }
    
    if IOObjectConformsTo(parent, "IOBlockStorageDriver") == 0 {
        IOObjectRelease(parent)
        return nil
    }
    
    return parent
}

public func fetchIOService(_ name: String) -> [NSDictionary]? {
    var iterator: io_iterator_t = io_iterator_t()
    var obj: io_registry_entry_t = 1
    var list: [NSDictionary] = []
    
    let result = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching(name), &iterator)
    if result != kIOReturnSuccess {
        print("Error IOServiceGetMatchingServices(): " + (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
        return nil
    }
    
    while obj != 0 {
        obj = IOIteratorNext(iterator)
        if let props = getIOProperties(obj) {
            list.append(props)
        }
        IOObjectRelease(obj)
    }
    IOObjectRelease(iterator)
    
    return list.isEmpty ? nil : list
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

public func getIOChildrens(_ entry: io_registry_entry_t) -> [String]? {
    var iter: io_iterator_t = io_iterator_t()
    if IORegistryEntryGetChildIterator(entry, kIOServicePlane, &iter) != kIOReturnSuccess {
        return nil
    }
    
    var iterator: io_registry_entry_t = 1
    var list: [String] = []
    while iterator != 0 {
        iterator = IOIteratorNext(iter)
        
        let pointer = UnsafeMutablePointer<io_name_t>.allocate(capacity: 1)
        if IORegistryEntryGetName(iterator, pointer) != kIOReturnSuccess {
            continue
        }
        
        list.append(String(cString: UnsafeRawPointer(pointer).assumingMemoryBound(to: CChar.self)))
        IOObjectRelease(iterator)
    }
    
    return list
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

public func isRoot() -> Bool {
    return getuid() == 0
}

public func ensureRoot() {
    if isRoot() {
        return
    }
    
    let pwd = Bundle.main.bundleURL.absoluteString.replacingOccurrences(of: "file://", with: "")
    guard let script = NSAppleScript(source: "do shell script \"\(pwd)/Contents/MacOS/Stats > /dev/null 2>&1 &\" with administrator privileges") else {
        return
    }
    
    var err: NSDictionary? = nil
    script.executeAndReturnError(&err)
    
    if err != nil {
        print("cannot run script as root: \(String(describing: err))")
        return
    }
    return
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
        // debug("system_profiler SPMemoryDataType: \(error.localizedDescription)")
        return nil
    }
    
    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(decoding: outputData, as: UTF8.self)
    
    if output.isEmpty {
        return nil
    }
    
    return output
}

public class SMCHelper {
    public static let shared = SMCHelper()
    private let smc: String
    
    public init() {
        self.smc = Bundle.main.path(forResource: "smc", ofType: nil)!
    }
    
    public func setFanSpeed(_ id: Int, speed: Int) {
        if !self.checkRights() {
            if !self.ensureRights() {
                return
            }
        }
        
        _ = syncShell("\(self.smc) fan -id \(id) -v \(speed)")
    }
    
    public func setFanMode(_ id: Int, mode: Int) {
        if !self.checkRights() {
            if !self.ensureRights() {
                return
            }
        }
        
        _ = syncShell("\(self.smc) fan -id \(id) -m \(mode)")
    }
    
    public func checkRights() -> Bool {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: self.smc)
            guard let owner = attributes[FileAttributeKey(rawValue: "NSFileOwnerAccountName")] as? String,
                  let ownerGroup = attributes[FileAttributeKey(rawValue: "NSFileGroupOwnerAccountName")] as? String,
                  let permissions = attributes[FileAttributeKey(rawValue: "NSFilePosixPermissions")]  as? Int else {
                print("some of the smc attributes is missing")
                return false
            }
            
            if owner == "root" && ownerGroup == "admin" && permissions == 3437 {
                return true
            }
        } catch let error {
            print("get smc attributes, \(error)")
            return false
        }
        
        return false
    }
    
    private func ensureRights() -> Bool {
        guard let script = NSAppleScript(source: "do shell script \"/usr/sbin/chown root:admin \(self.smc) && /bin/chmod 6555 \(self.smc)\" with administrator privileges") else {
            return false
        }
        
        var err: NSDictionary? = nil
        script.executeAndReturnError(&err)
        if err != nil {
            print("cannot upgrade owner to root: \(String(describing: err))")
            return false
        }
        
        return true
    }
}

public func saveNSStatusItemPosition(id: String) {
    let position = Store.shared.int(key: "NSStatusItem Preferred Position \(id)", defaultValue: -1)
    if position != -1 {
        Store.shared.set(key: "NSStatusItem Restore Position \(id)", value: position)
    }
}
public func restoreNSStatusItemPosition(id: String) {
    let prevPosition = Store.shared.int(key: "NSStatusItem Restore Position \(id)", defaultValue: -1)
    if prevPosition != -1 {
        Store.shared.set(key: "NSStatusItem Preferred Position \(id)", value: prevPosition)
        Store.shared.remove("NSStatusItem Restore Position \(id)")
    }
}
