//
//  Module.swift
//  socpowerbuddy_swift
//
//  Created by Eom SeHwan on 2022/09/17.
//

public protocol Module_p {
    var available: Bool { get }
    var enabled: Bool { get }
    
    func terminate()
}

public struct module_c {
    public var name: String? = ""
    
    public var defaultState: Bool = false
    
    internal var widgetsConfig: NSDictionary = NSDictionary()
    
    init(in path: String) {
        let dict: NSDictionary? = NSDictionary(contentsOfFile: path)
        
        if let name = dict?["Name"] as? String {
            self.name = name
        }
        if let state = dict?["State"] as? Bool {
            self.defaultState = state
        }
    }
}

open class Module: Module_p {
    public var config: module_c
    
    public var available: Bool = false
    public var enabled: Bool = false
    
    private let log: NextLog
    private var readers: [Reader_p] = []
    
    private var pauseState: Bool {
        get {
            return Store.shared.bool(key: "pause", defaultValue: false)
        }
        set {
            Store.shared.set(key: "pause", value: newValue)
        }
    }
    
    public init() {
        self.config = module_c(in: Bundle(for: type(of: self)).path(forResource: "config", ofType: "plist") ?? "")
        
        self.log = NextLog.shared.copy(category: self.config.name)
        self.available = self.isAvailable()
        self.enabled = Store.shared.bool(key: "\(String(describing: self.config.name))_state", defaultValue: self.config.defaultState)
        
        if !self.available {
            
            if self.enabled {
                self.enabled = false
                Store.shared.set(key: "\(String(describing: self.config.name))_state", value: false)
            }
            
            return
        } else if self.pauseState {
            self.disable()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // terminate function which call before app termination
    public func terminate() {
        self.willTerminate()
        self.readers.forEach{
            $0.stop()
            $0.terminate()
        }
    }
    
    // function to call before module terminate
    open func willTerminate() {}
    
    // set module state to enabled
    public func enable() {
        guard self.available else { return }
        
        self.enabled = true
        Store.shared.set(key: "\(String(describing: self.config.name))_state", value: true)
        self.readers.forEach { (reader: Reader_p) in
            reader.initStoreValues(title: self.config.name ?? "")
            reader.start()
        }
    }
    
    // set module state to disabled
    public func disable() {
        guard self.available else { return }
        
        self.enabled = false
        if !self.pauseState { // omit saving the disable state when toggle by pause, need for resume state restoration
            Store.shared.set(key: "\(String(describing: self.config.name))_state", value: false)
        }
        self.readers.forEach{ $0.stop() }
    }
    
    // add reader to module. If module is enabled will fire a read function and start a reader
    public func addReader(_ reader: Reader_p) {
        self.readers.append(reader)
    }
    
    // handler for reader, calls when main reader is ready, and return first value
    public func readyHandler() {
    }
    
    // determine if module is available (can be overrided in module)
    open func isAvailable() -> Bool { return true }
}

