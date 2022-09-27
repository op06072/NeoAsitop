//
//  head.swift
//  socpowerbuddy_swift
//
//  Created by Eom SeHwan on 2022/09/15.
//

import Foundation
import PythonKit

struct iorep_data {
    /* data for Energy Model*/
    var pwrsub: IOReportSubscriptionRef? = nil
    var pwrsubchn: Unmanaged<CFMutableDictionary>? = nil
    var pwrchn_eng: Unmanaged<CFMutableDictionary>? = nil
    var pwrchn_pmp: Unmanaged<CFMutableDictionary>? = nil
    
    /* data for CPU/GPU Stats */
    var cpusub: IOReportSubscriptionRef? = nil
    var cpusubchn: Unmanaged<CFMutableDictionary>? = nil
    var cpuchn_cpu: Unmanaged<CFMutableDictionary>? = nil
    var cpuchn_gpu: Unmanaged<CFMutableDictionary>? = nil
    
    /* data for CLPC Stats*/
    var clpcsub: IOReportSubscriptionRef? = nil
    var clpcsubchn: Unmanaged<CFMutableDictionary>? = nil
    var clpcchn: Unmanaged<CFMutableDictionary>? = nil
    
    /*data for BandWidth*/
    var bwsub: IOReportSubscriptionRef? = nil
    var bwsubchn: Unmanaged<CFMutableDictionary>? = nil
    var bwchn: Unmanaged<CFMutableDictionary>? = nil
}

struct static_data {
    var gpu_core_count = 0
    var dvfm_states_holder: Array<Array<Double>> = []
    var dvfm_states: Array<Array<Double>> = []
    var cluster_core_counts: Array<UInt8> = []
    var extra: Array<String> = []
    var complex_freq_channels: Array<String> = []
    var core_freq_channels: Array<String> = []
    var complex_pwr_channels: Array<String> = []
    var core_pwr_channels: Array<String> = []
    var core_ep_counts: Array<UInt8> = [0, 0]
    var ram_capacity = 0
    var max_pwr: Array<Float> = []
    var max_bw: Array<Float> = []
    var fan_exist = true
    var fan_limit: [[Double]] = [[0, 0], [0, 0]]
}

struct variating_data {
    var cluster_residencies: Array<Array<Float>> = []
    var cluster_pwrs: Array<Any> = []
    var cluster_freqs: Array<Float> = []
    var cluster_use: Array<Float> = []
    var cluster_sums: Array<UInt64> = []
    var core_pwrs: Array<Array<Any>> = []
    var core_residencies: Array<Array<Array<Float>>> = []
    var core_freqs: Array<Array<Float>> = []
    var core_use: Array<Array<Any>> = []
    var core_sums: Array<Array<UInt64>> = []
    
    var cluster_instrcts_ret: Array<CLong> = []
    var cluster_instrcts_clk: Array<CLong> = []
    
    var bandwidth_cnt: Dictionary<String, Array<Double>> = [:]
    
    var soc_temp: Dictionary<String, Double> = [:]
    var fan_speed: Dictionary<String, Double> = [:]
    var soc_power: Dictionary<String, Double> = [:]
    var soc_energy: Double = 0
    
    var mem_stat = mem_info()
    var swap_stat = mem_info()
    var mem_percent: Double = 0
}

struct cmd_data {
    var interval: Double = 0
    var samples: Int = 0
}

struct core_data {
    var usage: Float = 0
    var freq: Float = 0
    var temp: Double = 0
}

struct render_data {
    var ecpu = core_data()
    var pcpu = core_data()
    var gpu = core_data()
    var ane: [Any] = []
}

struct render_value {
    var title: PythonObject = PythonObject("")
    var val: PythonObject = PythonObject(0)
}

struct chart_render_value {
    var title: PythonObject = PythonObject("")
    var val: PythonObject = PythonObject([])
}

struct render_value_data {
    var ecpu = render_value()
    var pcpu = render_value()
    var gpu = render_value()
    var ane = render_value()
    var lfan = render_value()
    var rfan = render_value()
    var lf_label = PythonObject("")
    var rf_label = PythonObject("")
    var ram = render_value()
    var ecpu_bw = render_value()
    var pcpu_bw = render_value()
    var gpu_bw = render_value()
    var media_bw = render_value()
    var total_bw = PythonObject("")
    var system_pwr = PythonObject("")
    var cpu_pwr = chart_render_value()
    var gpu_pwr = chart_render_value()
    
    var sys_pwr_max: Double = 0
    var cpu_pwr_max: Float = 0
    var gpu_pwr_max: Float = 0
    var ram_pwr_max: Float = 0
    
    var sys_pwr_avg = PythonObject([])
    var cpu_pwr_avg = PythonObject([])
    var gpu_pwr_avg = PythonObject([])
    var ram_pwr_avg = PythonObject([])
}

struct mem_info {
    var total: Double = 0
    var used: Double = 0
    var free: Double = 0
}
