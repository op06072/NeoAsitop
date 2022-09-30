//
//  Types.swift
//  socpowerbuddy_swift
//
//  Created by Eom SeHwan on 2022/09/17.
//

public enum AppUpdateInterval: String {
    case silent = "Silent"
    case atStart = "At start"
    case separator1 = "separator_1"
    case oncePerDay = "Once per day"
    case oncePerWeek = "Once per week"
    case oncePerMonth = "Once per month"
    case separator2 = "separator_2"
    case never = "Never"
}
public let AppUpdateIntervals: [KeyValue_t] = [
    KeyValue_t(key: "Silent", value: AppUpdateInterval.silent.rawValue),
    KeyValue_t(key: "At start", value: AppUpdateInterval.atStart.rawValue),
    KeyValue_t(key: "separator_1", value: "separator_1"),
    KeyValue_t(key: "Once per day", value: AppUpdateInterval.oncePerDay.rawValue),
    KeyValue_t(key: "Once per week", value: AppUpdateInterval.oncePerWeek.rawValue),
    KeyValue_t(key: "Once per month", value: AppUpdateInterval.oncePerMonth.rawValue),
    KeyValue_t(key: "separator_2", value: "separator_2"),
    KeyValue_t(key: "Never", value: AppUpdateInterval.never.rawValue)
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
public let SpeedBase: [KeyValue_t] = [
    KeyValue_t(key: "bit", value: "Bit", additional: DataSizeBase.bit),
    KeyValue_t(key: "byte", value: "Byte", additional: DataSizeBase.byte)
]

public let SensorsWidgetMode: [KeyValue_t] = [
    KeyValue_t(key: "automatic", value: "Automatic"),
    KeyValue_t(key: "separator", value: "separator"),
    KeyValue_t(key: "oneRow", value: "One row"),
    KeyValue_t(key: "twoRows", value: "Two rows")
]

public let SpeedPictogram: [KeyValue_t] = [
    KeyValue_t(key: "none", value: "None"),
    KeyValue_t(key: "separator", value: "separator"),
    KeyValue_t(key: "dots", value: "Dots"),
    KeyValue_t(key: "arrows", value: "Arrows"),
    KeyValue_t(key: "chars", value: "Characters")
]

public let BatteryAdditionals: [KeyValue_t] = [
    KeyValue_t(key: "none", value: "None"),
    KeyValue_t(key: "separator", value: "separator"),
    KeyValue_t(key: "innerPercentage", value: "Percentage inside the icon"),
    KeyValue_t(key: "separator", value: "separator"),
    KeyValue_t(key: "percentage", value: "Percentage"),
    KeyValue_t(key: "time", value: "Time"),
    KeyValue_t(key: "percentageAndTime", value: "Percentage and time"),
    KeyValue_t(key: "timeAndPercentage", value: "Time and percentage")
]

public let ShortLong: [KeyValue_t] = [
    KeyValue_t(key: "short", value: "Short"),
    KeyValue_t(key: "long", value: "Long")
]

public let ReaderUpdateIntervals: [Int] = [1, 2, 3, 5, 10, 15, 30]
public let NumbersOfProcesses: [Int] = [0, 3, 5, 8, 10, 15]

public typealias Bandwidth = (upload: Int64, download: Int64)
public let NetworkReaders: [KeyValue_t] = [
    KeyValue_t(key: "interface", value: "Interface based"),
    KeyValue_t(key: "process", value: "Processes based")
]

public struct Color: KeyValue_p, Equatable {
    public let key: String
    public let value: String
    public var additional: Any?
    
    public static func == (lhs: Color, rhs: Color) -> Bool {
        return lhs.key == rhs.key
    }
}

public typealias colorZones = (orange: Double, red: Double)

public struct Scale: KeyValue_p, Equatable {
    public let key: String
    public let value: String
    public var additional: Any?
    
    public static func == (lhs: Scale, rhs: Scale) -> Bool {
        return lhs.key == rhs.key
    }
}

extension Scale: CaseIterable {
    public static var none: Scale { return Scale(key: "none", value: "None") }
    public static var separator: Scale { return Scale(key: "separator", value: "separator") }
    public static var linear: Scale { return Scale(key: "linear", value: "Linear") }
    public static var square: Scale { return Scale(key: "square", value: "Square") }
    public static var cube: Scale { return Scale(key: "cube", value: "Cube") }
    public static var logarithmic: Scale { return Scale(key: "logarithmic", value: "Logarithmic") }
    
    public static var allCases: [Scale] {
        return [.none, .separator, .linear, .square, .cube, .logarithmic]
    }
    
    public static func fromString(_ key: String, defaultValue: Scale = .linear) -> Scale {
        return Scale.allCases.first{ $0.key == key } ?? defaultValue
    }
}
