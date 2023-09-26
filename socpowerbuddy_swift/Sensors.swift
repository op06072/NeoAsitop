//
//  Sensors.swift
//  socpowerbuddy_swift
//
//  Created by Eom SeHwan on 2022/09/17.
//

public class Sensors: Module {
    private var sensorsReader: SensorsReader
    
    private var fanValueState: FanValue {
        FanValue(rawValue: Store.shared.string(key: "\(self.config.name ?? "left")_fanValue", defaultValue: "percentage")) ?? .percentage
    }
    
    public override init() {
        self.sensorsReader = SensorsReader()
        
        super.init()
        guard self.available else { return }
        
        self.sensorsReader.callbackHandler = { [unowned self] value in
            self.usageCallback(value)
        }
        self.sensorsReader.readyCallback = { [unowned self] in
            self.readyHandler()
        }
        
        self.addReader(self.sensorsReader)
    }
    
    public override func isAvailable() -> Bool {
        return !self.sensorsReader.list.sensors.isEmpty
    }
    
    private func usageCallback(_ raw: Sensors_List?) {
        guard let value = raw, self.enabled else {
            return
        }
        
        var list: [Stack_t] = []
        var flatList: [[Double]] = []
        
        value.sensors.forEach { (s: Sensor_p) in
            if s.state {
                var value = s.formattedMiniValue
                if let f = s as? Fan {
                    flatList.append([((f.value*100)/f.maxSpeed)/100])
                    if self.fanValueState == .percentage {
                        value = "\(f.percentage)%"
                    }
                }
                list.append(Stack_t(key: s.key, value: value, additional: s.name))
            }
        }
    }
}
