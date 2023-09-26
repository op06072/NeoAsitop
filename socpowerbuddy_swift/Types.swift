//
//  Types.swift
//  socpowerbuddy_swift
//
//  Created by Eom SeHwan on 2022/09/17.
//

public struct Stack_t: KeyValue_p {
    public var key: String
    public var value: String
    public var additional: Any?
    
    var index: Int {
        get {
            Store.shared.int(key: "stack_\(self.key)_index", defaultValue: -1)
        }
        set {
            Store.shared.set(key: "stack_\(self.key)_index", value: newValue)
        }
    }
    
    public init(key: String, value: String, additional: Any? = nil) {
        self.key = key
        self.value = value
        self.additional = additional
    }
}

public enum FanValue: String {
    case rpm
    case percentage
}
public let FanValues: [KeyValue_t] = [
    KeyValue_t(key: "rpm", value: "RPM", additional: FanValue.rpm),
    KeyValue_t(key: "percentage", value: "Percentage", additional: FanValue.percentage)
]

public let TemperatureUnits: [KeyValue_t] = [
    KeyValue_t(key: "system", value: "System"),
    KeyValue_t(key: "separator", value: "separator"),
    KeyValue_t(key: "celsius", value: "Celsius", additional: UnitTemperature.celsius),
    KeyValue_t(key: "fahrenheit", value: "Fahrenheit", additional: UnitTemperature.fahrenheit)
]

public enum DataSizeBase: String {
    case bit
    case byte
}
