//
//  Sensors.swift
//  socpowerbuddy_swift
//
//  Created by Eom SeHwan on 2022/09/17.
//

public class Sensors: Module {
    var sensorsReader: SensorsReader
    
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
        return !self.sensorsReader.list.isEmpty
    }
    
    private func checkIfNoSensorsEnabled() {
        if self.sensorsReader.list.filter({ $0.state }).isEmpty {
            NotificationCenter.default.post(name: .toggleModule, object: nil, userInfo: ["module": self.config.name, "state": false])
        }
    }
    
    private func usageCallback(_ raw: [Sensor_p]?) {
        guard let value = raw, self.enabled else {
            return
        }
        
        var list: [KeyValue_t] = []
        
        value.forEach { (s: Sensor_p) in
            if s.state {
                list.append(KeyValue_t(key: s.key, value: s.formattedMiniValue, additional: s.name))
            }
        }
    }
}
