//
//  reader.swift
//  socpowerbuddy_swift
//
//  Created by Eom SeHwan on 2022/09/17.
//

public protocol Reader_p {
    var optional: Bool { get }
    var popup: Bool { get }
    
    func setup()
    func read()
    func terminate()
    
    func getValue<T>() -> T
    
    func start()
    func pause()
    func stop()
    
    func lock()
    func unlock()
    
    func initStoreValues(title: String)
    func setInterval(_ value: Int)
}

public protocol ReaderInternal_p {
    associatedtype T
    
    var value: T? { get }
    func read()
}

open class Reader<T>: NSObject, ReaderInternal_p {
    public var log: NextLog {
        return NextLog.shared.copy(category: "\(String(describing: self))")
    }
    public var value: T?
    public var interval: Double? = nil
    public var defaultInterval: Double = 1
    public var optional: Bool = false
    public var popup: Bool = false
    
    public var readyCallback: () -> Void = {}
    public var callbackHandler: (T?) -> Void = {_ in }
    
    private var repeatTask: Repeater?
    private var nilCallbackCounter: Int = 0
    private var ready: Bool = false
    private var locked: Bool = true
    private var initlizalized: Bool = false
    public var active: Bool = false
    
    private var history: [T]? = []
    
    public init(popup: Bool = false) {
        self.popup = popup
        
        super.init()
        self.setup()
    }
    
    public func initStoreValues(title: String) {
        guard self.interval == nil else {
            return
        }
        
        let updateIntervalString = Store.shared.string(key: "\(title)_updateInterval", defaultValue: "\(self.defaultInterval)")
        if let updateInterval = Double(updateIntervalString) {
            self.interval = updateInterval
        }
    }
    
    public func callback(_ value: T?) {
        if !self.optional && !self.ready {
            if self.value == nil && value != nil {
                self.ready = true
                self.readyCallback()
            } else if self.value == nil && value != nil {
                if self.nilCallbackCounter > 5 {
                    print("Callback receive nil value more than 5 times. Please check this reader!")
                    self.stop()
                    return
                } else {
                    self.nilCallbackCounter += 1
                    self.read()
                    return
                }
            } else if self.nilCallbackCounter != 0 && value != nil {
                self.nilCallbackCounter = 0
            }
        }
        
        self.value = value
        if value != nil {
            if self.history?.count ?? 0 >= 300 {
                self.history!.remove(at: 0)
            }
            self.history?.append(value!)
            self.callbackHandler(value!)
        }
    }
    
    open func read() {}
    open func setup() {}
    open func terminate() {}
    
    open func start() {
        if self.popup && self.locked {
            if !self.ready {
                DispatchQueue.global(qos: .background).async {
                    self.read()
                }
            }
            return
        }
        
        if let interval = self.interval, self.repeatTask == nil {
            
            self.repeatTask = Repeater.init(seconds: Int(interval)) { [weak self] in
                self?.read()
            }
        }
        
        if !self.initlizalized {
            DispatchQueue.global(qos: .background).async {
                self.read()
            }
            self.initlizalized = true
        }
        self.repeatTask?.start()
        self.active = true
    }
    
    open func pause() {
        self.repeatTask?.pause()
        self.active = false
    }
    
    open func stop() {
        self.repeatTask?.pause()
        self.repeatTask = nil
        self.active = false
        self.initlizalized = false
    }
    
    public func setInterval(_ value: Int) {
        self.interval = Double(value)
        self.repeatTask?.reset(seconds: value, restart: true)
    }
}

extension Reader: Reader_p {
    public func getValue<T>() -> T {
        return self.value as! T
    }
    
    public func lock() {
        self.locked = true
    }
    
    public func unlock() {
        self.locked = false
    }
}
