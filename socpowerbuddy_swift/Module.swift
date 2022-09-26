//
//  Module.swift
//  socpowerbuddy_swift
//
//  Created by Eom SeHwan on 2022/09/17.
//

public protocol Module_p {
    var available: Bool { get }
    var enabled: Bool { get }
    
    func mount()
    func unmount()
    
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
        self.enabled = Store.shared.bool(key: "\(self.config.name)_state", defaultValue: self.config.defaultState)
        
        if !self.available {
            // debug("Module is not available", log: self.log)
            
            if self.enabled {
                self.enabled = false
                Store.shared.set(key: "\(self.config.name)_state", value: false)
            }
            
            return
        } else if self.pauseState {
            self.disable()
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(listenForModuleToggle), name: .toggleModule, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // load function which call when app start
    public func mount() {
        guard self.enabled else {
            return
        }
        
        self.readers.forEach { (reader: Reader_p) in
            reader.initStoreValues(title: self.config.name ?? "")
            reader.start()
        }
    }
    
    // disable module
    public func unmount() {
        self.enabled = false
        self.available = false
    }
    
    // terminate function which call before app termination
    public func terminate() {
        self.willTerminate()
        self.readers.forEach{
            $0.stop()
            $0.terminate()
        }
        // debug("Module terminated", log: self.log)
    }
    
    // function to call before module terminate
    open func willTerminate() {}
    
    // set module state to enabled
    public func enable() {
        guard self.available else { return }
        
        self.enabled = true
        Store.shared.set(key: "\(self.config.name)_state", value: true)
        self.readers.forEach { (reader: Reader_p) in
            reader.initStoreValues(title: self.config.name ?? "")
            reader.start()
        }
        // debug("Module enabled", log: self.log)
    }
    
    // set module state to disabled
    public func disable() {
        guard self.available else { return }
        
        self.enabled = false
        if !self.pauseState { // omit saving the disable state when toggle by pause, need for resume state restoration
            Store.shared.set(key: "\(self.config.name)_state", value: false)
        }
        self.readers.forEach{ $0.stop() }
        // debug("Module disabled", log: self.log)
    }
    
    // toggle module state
    private func toggleEnabled() {
        if self.enabled {
            self.disable()
        } else {
            self.enable()
        }
    }
    
    // add reader to module. If module is enabled will fire a read function and start a reader
    public func addReader(_ reader: Reader_p) {
        self.readers.append(reader)
        // debug("\(reader.self) was added", log: self.log)
    }
    
    // handler for reader, calls when main reader is ready, and return first value
    public func readyHandler() {
        // debug("Reader report readiness", log: self.log)
    }
    
    // determine if module is available (can be overrided in module)
    open func isAvailable() -> Bool { return true }
    
    // call when popup appear/disappear
    private func visibilityCallback(_ state: Bool) {
        self.readers.filter{ $0.popup }.forEach { (reader: Reader_p) in
            if state {
                reader.unlock()
                reader.start()
            } else {
                reader.pause()
                reader.lock()
            }
        }
    }
    
    @objc private func listenForModuleToggle(_ notification: Notification) {
        if let name = notification.userInfo?["module"] as? String {
            if name == self.config.name {
                if let state = notification.userInfo?["state"] as? Bool {
                    if state && !self.enabled {
                        self.enable()
                    } else if !state && self.enabled {
                        self.disable()
                    }
                }
            }
        }
    }
}
