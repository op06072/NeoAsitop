//
//  render.swift
//  socpowerbuddy_swift
//
//  Created by Eom SeHwan on 2022/09/22.
//

import Foundation
import SwiftShell
import PythonKit

class renderer {
    private var dashing: PythonObject?
    private var ui: PythonObject?
    
    init() {
        var pyframework = "/Library/Developer/CommandLineTools/Library/Frameworks/Python3.framework"
        if case let findpy = run(bash: "find /Library/Developer/CommandLineTools -name '*Python3.framework' -type d").stdout, findpy != "" {
            pyframework = String(findpy.split(separator: "\n")[0])
        }
        
        let ver = pyframework + "/Versions/Current"
        let pylib = ver + "/Python3"
        PythonLibrary.useLibrary(at: pylib)
        let tui = "dashing"
        do {
            try Python.attemptImport(tui)
        } catch {
            print("No module named \(tui)")
            print("Installing \(tui)...")
            module_install: while true {
                run(bash: "\(ver)/bin/python3 -m pip install \(tui)")
                if run(bash: "\(ver)/bin/python3 -m pip list").stdout.contains(tui) {
                    break module_install
                }
            }
            print("Successfully installed!")
        }
        self.dashing = try? Python.attemptImport(tui)
    }
    
    func term_layout(sd: static_data, colr: UInt8 = 2) {
        var usage_gauges = self.dashing!.VSplit(
            self.dashing!.HSplit(
                self.dashing!.HGauge(
                    title: "E-CPU Usage",
                    val: 0,
                    color: colr
                ),
                self.dashing!.HGauge(
                    title: "P-CPU Usage",
                    val: 0,
                    color: colr
                )
            ),
            self.dashing!.HSplit(
                self.dashing!.HGauge(
                    title: "GPU Usage",
                    val: 0,
                    color: colr
                ),
                self.dashing!.HGauge(
                    title: "ANE",
                    val: 0,
                    color: colr
                )
            ),
            title: "Processor Utilization",
            border_color: colr
        )
        if sd.fan_exist {
            usage_gauges = self.dashing!.VSplit(
                self.dashing!.HSplit(
                    self.dashing!.HGauge(
                        title: "E-CPU Usage",
                        val: 0,
                        color: colr
                    ),
                    self.dashing!.HGauge(
                        title: "P-CPU Usage",
                        val: 0,
                        color: colr
                    )
                ),
                self.dashing!.HSplit(
                    self.dashing!.HGauge(
                        title: "GPU Usage",
                        val: 0,
                        color: colr
                    ),
                    self.dashing!.HGauge(
                        title: "ANE",
                        val: 0,
                        color: colr
                    )
                ),
                self.dashing!.HSplit(
                    self.dashing!.VSplit(
                        self.dashing!.HGauge(
                            val: 0,
                            color: colr
                        ),
                        self.dashing!.HGauge(
                            val: 0,
                            color: colr
                        ),
                        title: "Fan Speed"
                    ),
                    self.dashing!.VSplit(
                        self.dashing!.Text(
                            text: "Left Fan",
                            color: colr
                        ),
                        self.dashing!.Text(
                            text: "Right Fan",
                            color: colr
                        ),
                        title: " "
                    )
                ),
                title: "Processor Utilization",
                border_color: colr
            )
        }
        self.ui = self.dashing!.VSplit(
            usage_gauges,
            self.dashing!.VSplit(
                self.dashing!.HGauge(
                    title: "RAM Usage",
                    val: 0,
                    color: colr
                ),
                self.dashing!.HSplit(
                    self.dashing!.HGauge(
                        title: "E-CPU B/W",
                        val: 50,
                        color: colr
                    ),
                    self.dashing!.HGauge(
                        title: "P-CPU B/W",
                        val: 50,
                        color: colr
                    ),
                    self.dashing!.HGauge(
                        title: "GPU B/W",
                        val: 50,
                        color: colr
                    ),
                    self.dashing!.HGauge(
                        title: "Media B/W",
                        val: 50,
                        color: colr
                    ),
                    title: "Memory Bandwidth"
                ),
                title: "Memory",
                border_color: colr
            ),
            self.dashing!.HSplit(
                self.dashing!.HChart(
                    title: "CPU Power",
                    color: colr
                ),
                self.dashing!.HChart(
                    title: "GPU Power",
                    color: colr
                ),
                title: "Power Chart",
                border_color: colr
            )
        )
        
        
        var cpu_title = sd.extra[0]
        if case let mode = sd.extra[sd.extra.count-1], mode == "Apple" || mode == "Rosetta 2" {
            if mode == "Apple" {
                cpu_title += " (cores: \(sd.core_ep_counts[0])E+\(sd.core_ep_counts[1])P+"
            } else if mode == "Rosetta 2" {
                cpu_title += "[Rosetta 2] (cores: \(sd.core_ep_counts.reduce(0,+))C+"
            }
            cpu_title += "\(sd.gpu_core_count)GPU+\(sd.ram_capacity)GB)"
        }
        
        self.ui!.items[0].title = PythonObject(cpu_title)
    }
    
    func term_rendering(sd: static_data, vd: variating_data, rvd: render_value_data, colr: UInt8 = 2) {
        let usage_gauges = self.ui!.items[0]
        let memory_gauges = self.ui!.items[1]
        let power_charts = self.ui!.items[2]
        
        let cpu_gauges = usage_gauges.items[0]
        let cpu1_gauge = cpu_gauges.items[0]
        let cpu2_gauge = cpu_gauges.items[1]
        
        let acc_gauges = usage_gauges.items[1]
        let gpu_gauge = acc_gauges.items[0]
        let ane_gauge = acc_gauges.items[1]
        
        if sd.fan_exist {
            let fan_gauges = usage_gauges.items[2]
            let fan_gauge = fan_gauges.items[0]
            let fan_label = fan_gauges.items[1]
            let lfan_gauge = fan_gauge.items[0]
            let rfan_gauge = fan_gauge.items[1]
            let lfan_label = fan_label.items[0]
            let rfan_label = fan_label.items[1]
            
            fan_gauge.title = rvd.lfan.title
            lfan_gauge.value = rvd.lfan.val
            rfan_gauge.value = rvd.rfan.val
            lfan_label.text = rvd.lf_label
            rfan_label.text = rvd.rf_label
        }
        
        let ram_gauges = memory_gauges.items[0]
        
        let bw_gauges = memory_gauges.items[1]
        let ecpu_bw_gauges = bw_gauges.items[0]
        let pcpu_bw_gauges = bw_gauges.items[1]
        let gpu_bw_gauges = bw_gauges.items[2]
        let media_bw_gauges = bw_gauges.items[3]
        
        let cpu_power_chart = power_charts.items[0]
        let gpu_power_chart = power_charts.items[1]
        
        cpu1_gauge.title = rvd.ecpu.title
        cpu1_gauge.value = rvd.ecpu.val
        cpu2_gauge.title = rvd.pcpu.title
        cpu2_gauge.value = rvd.pcpu.val
        gpu_gauge.title = rvd.gpu.title
        gpu_gauge.value = rvd.gpu.val
        ane_gauge.title = rvd.ane.title
        ane_gauge.value = rvd.ane.val
        ram_gauges.title = rvd.ram.title
        ram_gauges.value = rvd.ram.val
        ecpu_bw_gauges.title = rvd.ecpu_bw.title
        ecpu_bw_gauges.value = rvd.ecpu_bw.val
        pcpu_bw_gauges.title = rvd.pcpu_bw.title
        pcpu_bw_gauges.value = rvd.pcpu_bw.val
        gpu_bw_gauges.title = rvd.gpu_bw.title
        gpu_bw_gauges.value = rvd.gpu_bw.val
        media_bw_gauges.title = rvd.media_bw.title
        media_bw_gauges.value = rvd.media_bw.val
        bw_gauges.title = rvd.total_bw
        power_charts.title = rvd.system_pwr
        cpu_power_chart.title = rvd.cpu_pwr.title
        cpu_power_chart.datapoints = rvd.cpu_pwr.val
        gpu_power_chart.title = rvd.gpu_pwr.title
        gpu_power_chart.datapoints = rvd.gpu_pwr.val
        print(self.ui!.items[0].items[0].items)
        self.ui!.display()
    }
}
