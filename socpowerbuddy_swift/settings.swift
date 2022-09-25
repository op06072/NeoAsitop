//
//  settings.swift
//  socpowerbuddy_swift
//
//  Created by Eom SeHwan on 2022/09/17.
//

open class Settings: NSStackView, Settings_p {
    public var toggleCallback: () -> Void = {}
    
    private var config: UnsafePointer<module_c>
    private var widgets: [Widget]
    private var moduleSettings: Settings_v?
    
    private var enableControl: NSControl?
    private let noWidgetsView: EmptyView = EmptyView(msg: localizedString("No available widgets to configure"))
    
    private var oneViewState: Bool {
        get {
            return Store.shared.bool(key: "\(self.config.pointee.name)_oneView", defaultValue: false)
        }
        set {
            Store.shared.set(key: "\(self.config.pointee.name)_oneView", value: newValue)
        }
    }
    
    init(config: UnsafePointer<module_c>, widgets: UnsafeMutablePointer<[Widget]>, enabled: Bool, moduleSettings: Settings_v?) {
        self.config = config
        self.widgets = widgets.pointee
        self.moduleSettings = moduleSettings
        
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Settings.width, height: Constants.Settings.height))
        
        NotificationCenter.default.addObserver(self, selector: #selector(externalModuleToggle), name: .toggleModule, object: nil)
        
        self.wantsLayer = true
        self.appearance = NSAppearance(named: .aqua)
        self.layer?.backgroundColor = NSColor(hexString: "#ececec").cgColor
        
        self.orientation = .vertical
        self.alignment = .width
        self.distribution = .fill
        self.spacing = 0
        
        self.addArrangedSubview(self.header(enabled))
        self.addArrangedSubview(self.headerSeparator)
        self.addArrangedSubview(self.body())
        
        self.addArrangedSubview(NSView())
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - parts
    
    private func header(_ enabled: Bool) -> NSStackView {
        let view: NSStackView = NSStackView()
        
        view.orientation = .horizontal
        view.distribution = .fillEqually
        view.alignment = .centerY
        view.distribution = .fillProportionally
        view.spacing = 0
        view.edgeInsets = NSEdgeInsets(
            top: Constants.Settings.margin,
            left: Constants.Settings.margin,
            bottom: Constants.Settings.margin,
            right: Constants.Settings.margin
        )
        
        let titleView = NSTextField()
        titleView.isEditable = false
        titleView.isSelectable = false
        titleView.isBezeled = false
        titleView.wantsLayer = true
        titleView.textColor = .black
        titleView.backgroundColor = .clear
        titleView.canDrawSubviewsIntoLayer = true
        titleView.alignment = .natural
        titleView.font = NSFont.systemFont(ofSize: 18, weight: .light)
        titleView.stringValue = localizedString(self.config.pointee.name)
        
        var toggleBtn: NSControl = NSControl()
        if #available(OSX 10.15, *) {
            let switchButton = NSSwitch()
            switchButton.state = enabled ? .on : .off
            switchButton.action = #selector(self.toggleEnable)
            switchButton.target = self
            
            toggleBtn = switchButton
        } else {
            let button: NSButton = NSButton()
            button.setButtonType(.switch)
            button.state = enabled ? .on : .off
            button.title = ""
            button.action = #selector(self.toggleEnable)
            button.isBordered = false
            button.isTransparent = false
            button.target = self
            
            toggleBtn = button
        }
        self.enableControl = toggleBtn
        
        view.addArrangedSubview(titleView)
        view.addArrangedSubview(NSView())
        view.addArrangedSubview(toggleBtn)
        
        return view
    }
    
    private func body() -> NSStackView {
        let view: NSStackView = NSStackView()
        
        view.translatesAutoresizingMaskIntoConstraints = false
        view.orientation = .vertical
        view.edgeInsets = NSEdgeInsets(
            top: Constants.Settings.margin,
            left: Constants.Settings.margin,
            bottom: Constants.Settings.margin,
            right: Constants.Settings.margin
        )
        view.spacing = Constants.Settings.margin
        
        view.addArrangedSubview(WidgetSelectorView(module: self.config.pointee.name, widgets: self.widgets, stateCallback: self.loadWidget))
        view.addArrangedSubview(self.settings())
        
        return view
    }
    
    // MARK: - views
    
    private func settings() -> NSView {
        let view: NSTabView = NSTabView(frame: NSRect(x: 0, y: 0,
            width: Constants.Settings.width - Constants.Settings.margin*2,
            height: Constants.Settings.height - 40 - Constants.Widget.height - (Constants.Settings.margin*5)
        ))
        view.widthAnchor.constraint(equalToConstant: view.frame.width).isActive = true
        view.heightAnchor.constraint(equalToConstant: view.frame.height).isActive = true
        view.tabViewType = .topTabsBezelBorder
        view.tabViewBorderType = .line
        
        let moduleTab: NSTabViewItem = NSTabViewItem()
        moduleTab.label = localizedString("Module settings")
        moduleTab.view = {
            let view = ScrollableStackView(frame: view.frame)
            self.moduleSettingsContainer = view.stackView
            self.loadModuleSettings()
            return view
        }()
        
        let widgetTab: NSTabViewItem = NSTabViewItem()
        widgetTab.label = localizedString("Widget settings")
        widgetTab.view = {
            let view = ScrollableStackView(frame: view.frame)
            view.stackView.spacing = 0
            self.widgetSettingsContainer = view.stackView
            self.loadWidgetSettings()
            return view
        }()
        
        view.addTabViewItem(moduleTab)
        view.addTabViewItem(widgetTab)
        
        return view
    }
    
    // MARK: - helpers
    
    @objc private func toggleEnable(_ sender: Any) {
        self.toggleCallback()
    }
    
    @objc private func externalModuleToggle(_ notification: Notification) {
        if let name = notification.userInfo?["module"] as? String {
            if name == self.config.pointee.name {
                if let state = notification.userInfo?["state"] as? Bool {
                    toggleNSControlState(self.enableControl, state: state ? .on : .off)
                }
            }
        }
    }
    
    public func setState(_ newState: Bool) {
        toggleNSControlState(self.enableControl, state: newState ? .on : .off)
    }
    
    private func loadWidget() {
        self.loadModuleSettings()
        self.loadWidgetSettings()
    }
    
    private func loadModuleSettings() {
        self.moduleSettingsContainer?.subviews.forEach{ $0.removeFromSuperview() }
        
        if let settingsView = self.moduleSettings {
            settingsView.load(widgets: self.widgets.filter{ $0.isActive }.map{ $0.type })
            self.moduleSettingsContainer?.addArrangedSubview(settingsView)
        } else {
            self.moduleSettingsContainer?.addArrangedSubview(NSView())
        }
    }
    
    private func loadWidgetSettings() {
        self.widgetSettingsContainer?.subviews.forEach{ $0.removeFromSuperview() }
        let list = self.widgets.filter({ $0.isActive && $0.type != .label })
        
        guard !list.isEmpty else {
            self.widgetSettingsContainer?.addArrangedSubview(self.noWidgetsView)
            return
        }
        
        if self.widgets.filter({ $0.isActive }).count > 1 {
            let container = NSStackView()
            container.orientation = .vertical
            container.distribution = .gravityAreas
            container.translatesAutoresizingMaskIntoConstraints = false
            container.edgeInsets = NSEdgeInsets(
                top: Constants.Settings.margin,
                left: Constants.Settings.margin,
                bottom: Constants.Settings.margin,
                right: Constants.Settings.margin
            )
            container.spacing = Constants.Settings.margin
            
            container.addArrangedSubview(toggleSettingRow(
                title: "\(localizedString("Merge widgets"))",
                action: #selector(self.toggleOneView),
                state: self.oneViewState
            ))
            
            self.widgetSettingsContainer?.addArrangedSubview(container)
        }
        
        for i in 0...list.count - 1 {
            self.widgetSettingsContainer?.addArrangedSubview(WidgetSettings(
                title: list[i].type.name(),
                image: list[i].image,
                settingsView: list[i].item.settings()
            ))
        }
    }
    
    @objc private func toggleOneView(_ sender: NSControl) {
        var state: NSControl.StateValue? = nil
        if #available(OSX 10.15, *) {
            state = sender is NSSwitch ? (sender as! NSSwitch).state: nil
        } else {
            state = sender is NSButton ? (sender as! NSButton).state: nil
        }
        
        self.oneViewState = state! == .on ? true : false
        NotificationCenter.default.post(name: .toggleOneView, object: nil, userInfo: ["module": self.config.pointee.name])
    }
}
