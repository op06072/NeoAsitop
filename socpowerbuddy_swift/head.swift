//
//  head.swift
//  socpowerbuddy_swift
//
//  Created by Eom SeHwan on 2022/09/15.
//

import Foundation

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
    var fan_mode = 0
    var fan_limit: [[Double]] = [[0, 0], [0, 0]]
    var os_ver: String = "macOS"
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
    var thermal_pressure: Int = 0
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

struct mem_info {
    var total: Double = 0
    var used: Double = 0
    var free: Double = 0
}
