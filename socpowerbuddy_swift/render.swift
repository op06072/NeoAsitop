//
//  Renders.swift
//  socpowerbuddy_swift
//
//  Created by Eom SeHwan on 2022/10/07.
//

import Foundation
import Darwin.ncurses

let black = 0
let red = 1
let green = 2
let yellow = 3
let blue = 4
let magenta = 5
let cyan = 6
let white = 7

let hbar_elements = ["▏", "▎", "▍", "▌", "▋", "▊", "▉"]
let vbar_elements = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]

enum split {
    case hsplit
    case vsplit
    case hgauge
    case vgauge
}

extension split {
    var mode: Int32 {
        switch self {
        case .hsplit, .hgauge: return 0
        case .vsplit, .vgauge: return 1
        }
    }
}

struct tileInfo {
    var title: String
    var val: Float
}

struct chartInfo {
    var title: String
    var val: [Float]
}

struct refreshInfo {
    var tbx: tbox
    var bottom: OpaquePointer?
    var xy: [Int32]
}

struct dispInfo {
    var proc_grp = "Processor Utilization"
    var mem_grp = "Memory"
    var pwr_grp = "Power Chart"
    
    var ecpu_usg = tileInfo(
        title: "E-CPU Usage",
        val: 0
    )
    var pcpu_usg = tileInfo(
        title: "P-CPU Usage",
        val: 0
    )
    var gpu_usg = tileInfo(
        title: "GPU Usage",
        val: 0
    )
    var ane_usg = tileInfo(
        title: "ANE Usage",
        val: 0
    )
    var fan_usg = chartInfo(
        title: "FAN Usage",
        val: [0, 0]
    )
    var airflow_info = ["Left fan: "]
    
    var ram_usg = tileInfo(
        title: "RAM Usage",
        val: 0
    )
    var bw_grp = "Memory Bandwidth"
    var ecpu_bw = tileInfo(
        title: "E-CPU",
        val: 50
    )
    var pcpu_bw = tileInfo(
        title: "P-CPU",
        val: 50
    )
    var gpu_bw = tileInfo(
        title: "GPU",
        val: 50
    )
    var media_bw = tileInfo(
        title: "Media",
        val: 50
    )
    
    var cpu_pwr = chartInfo(
        title: "CPU",
        val: []
    )
    var gpu_pwr = chartInfo(
        title: "GPU",
        val: []
    )
    
    var sys_pwr_max: Double = 0
    var cpu_pwr_max: Float = 0
    var gpu_pwr_max: Float = 0
    var ram_pwr_max: Float = 0
    
    var sys_pwr_avg = Array<Double>()
    var cpu_pwr_avg = Array<Float>()
    var gpu_pwr_avg = Array<Float>()
    var ram_pwr_avg = Array<Float>()
    
    init(sd: static_data) {
        autoreleasepool {
            var cpu_title = sd.extra[0]
            if case let mode = sd.extra[sd.extra.count-1], ["Apple", "Rosetta 2"].contains(mode) {
                if mode == "Apple" {
                    cpu_title += " (cores: \(sd.core_ep_counts[0])E+\(sd.core_ep_counts[1])P+"
                } else if mode == "Rosetta 2" {
                    cpu_title += "[Rosetta 2] (cores: \(sd.core_ep_counts.reduce(0,+))C+"
                }
                cpu_title += "\(sd.gpu_core_count)GPU+\(sd.ram_capacity))"
            }
            cpu_title += " \(sd.os_ver)"
            
            proc_grp = cpu_title
        }
    }
}

struct Tile {
    var x: Int32 = 0
    var y: Int32 = 0
    var w: Int32 = 0
    var h: Int32 = 0
    var c: Int = 0
    var win: OpaquePointer! = newwin(0, 0, 0, 0)
    var title: String = ""
}

struct tbox {
    var t: Tile = Tile()
    var items: [tbox] = []
}

func get_size() -> [Int32] {
    autoreleasepool {
        var w = winsize()
        var lines = Int32(w.ws_row)
        var cols = Int32(w.ws_col)
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) == 0 {
            lines = Int32(w.ws_row)
            cols = Int32(w.ws_col)
        } else {
            print("Failed to get terminal size")
            exit(1)
        }
        return [lines, cols]
    }
}

func gen_screen() {
    setlocale(LC_CTYPE, "en_US.UTF-8")
    newterm(nil, stderr, stdin)
    setlocale(LC_CTYPE, "en_US.UTF-8")
    //print("locale set and terminal gen")
    cbreak()
    noecho()                    // Don't echo user input
    nonl()                      // Disable newline mode
    intrflush(stdscr, true)     // Prevent flush
    keypad(stdscr, true)        // Enable function and arrow keys
    curs_set(0)                 // Set cursor to invisible
    //print("term set")
    start_color()
    nodelay(stdscr, true)
}

func screen_bottom(_ bottm: OpaquePointer? = nil) -> OpaquePointer? {
    autoreleasepool {
        let size = get_size()
        let lines = size[0]-1
        let cols = size[1]
        var bottom: OpaquePointer? = nil
        
        if bottm != nil {
            bottom = bottm!
        } else {
            bottom = newwin(1, cols, lines, 0)
        }
        init_pair(3, Int16(blue), Int16(blue))
        wattron(bottom, COLOR_PAIR(3))
        box(bottom, 0, 0)
        wattroff(bottom, COLOR_PAIR(3))
        let quit_msg = "Press 'q' to Quit."
        wmove(bottom, 0, cols/8-Int32(quit_msg.count/2))
        wattron(bottom, COLOR_PAIR(2))
        waddstr(bottom, quit_msg)
        wattroff(bottom, COLOR_PAIR(2))
        wrefresh(bottom)
        
        return bottom
    }
}

func screen_init(dark: Bool = true) -> tbox {
    autoreleasepool {
        let size = get_size()
        let lines = size[0]-1
        let cols = size[1]
        var screen = newwin(lines, cols, 0, 0)
        //werase(screen)
        init_pair(2, Int16(white), Int16(blue))
        init_pair(3, Int16(blue), Int16(blue))
        init_pair(4, Int16(red), Int16(black))
        if !dark {
            wattron(screen, COLOR_PAIR(1))
            wbkgd(screen, chtype(COLOR_PAIR(1)))
        }
        var _ = screen_bottom()
        refresh()
        wrefresh(screen)
        screen = nil
        
        return tbox(
            t: Tile(x: 0, y: 0, w: cols, h: lines, c: dark ? 0 : 7, win: screen, title: ""),
            items: []
        )
    }
}

func Stack(size: Int32, title: [String], border: Int, stack: split, tbx: inout tbox, offset: Int32? = nil, render: Bool, dark: Bool) {
    let hstack = 1-stack.mode
    let vstack = stack.mode
    let t = tbx.t
    var line = t.h
    var col = t.w
    var left = t.x
    var top = t.y
    var tiles: [tbox]? = []
    var colr = green
    
    if t.c != black && t.c != red && t.title != "" {
        line -= 2
        col -= 2
        left += 1
        top += 1
    } else if t.title != "" {
        line -= 1
        col -= 1
        left += 1
        top += 1
    }
    
    var hsize = col
    var vsize = line
    var hplus: Int32 = 0
    var vplus: Int32 = 0
    if hstack > 0 {
        hsize /= size
        hplus = hsize
    } else if vstack > 0 {
        vsize /= size
        vplus = vsize
    }
    
    autoreleasepool {
        for i in 0..<size {
            var y = top+vplus*i
            let x = left+hplus*i
            var spair: Int32 = 0
            if (offset != nil) {
                
                if i < size-1 {
                    spair += (offset ?? 0)
                } else {
                    y += (offset ?? 0)
                }
            }
            autoreleasepool {
                var win: OpaquePointer? = nil
                if tbx.items.count > 0 {
                    win = tbx.items[Int(i)].t.win
                    wresize(win, vsize+spair, hsize)
                    mvwin(win, y, x)
                } else {
                    win = newwin(vsize+spair, hsize, y, x)
                }
                wattron(win, COLOR_PAIR(1))
                wbkgd(win, chtype(COLOR_PAIR(1)))
                //werase(win)
                if border > 0 {
                    if border == 2 {
                        init_pair(5, Int16(yellow), Int16(black))
                        wattron(win, COLOR_PAIR(5))
                        colr = yellow
                    } else if border == 3 {
                        init_pair(6, Int16(red), Int16(black))
                        wattron(win, COLOR_PAIR(6))
                        colr = red
                    }
                    box(win, 0, 0)
                } else {
                    colr = dark ? black : white
                }
                var titl = ""
                if title.count > i {
                    titl = title[Int(i)]
                    if titl != "" {
                        var start = col/8
                        if border == 1{
                            start = col/10
                        }
                        start -= Int32(titl.count/2)
                        if start < 0 {
                            start = 0
                        }
                        wmove(win, 0, start)
                        wattron(win, COLOR_PAIR(1))
                        waddstr(win, " \(titl) ")
                    }
                }
                
                wattroff(win, COLOR_PAIR(1))
                if tbx.items.count > 0 {
                    tiles!.append(tbox(
                        t: Tile(x: x, y: y, w: hsize, h: vsize, c: colr, win: win, title: titl),
                        items: tbx.items[Int(i)].items
                    ))
                } else {
                    tiles!.append(tbox(
                        t: Tile(x: x, y: y, w: hsize, h: vsize, c: colr, win: win, title: titl),
                        items: []
                    ))
                }
                if render {
                    wrefresh(win)
                }
                win = nil
            }
        }
        
        tbx.items = tiles!
        tiles = nil
    }
}

func Gauge(value: Float? = nil, gauge: split, tbx: inout tbox, datapoint: [Float]? = nil, offset: Int32? = nil, render: Bool) {
    autoreleasepool {
        let hgauge = 1-gauge.mode
        let vgauge = gauge.mode
        let t = tbx.t
        let title = t.title
        var line = t.h + (offset ?? 0)
        let col = t.w - 1
        let win = t.win
        var peak: Int32 = 0
        //print(line)
        
        wattron(win, COLOR_PAIR(1))
        if hgauge != 0 {
            var val = (value ?? 0)
            
            if val > 100 {
                val = 100
            } else if val < 0 {
                val = 0
            }
            
            if title != "" {
                line -= 1
                peak += 1
            }
            //print(line)
            let wi = Float(col) * val / 100.0
            
            let idx = Int((wi - Float(Int(wi)))*7)
            var bar = ""
            if wi > 0 {
                bar = String(repeating: hbar_elements[hbar_elements.count-1], count: Int(wi-1))+hbar_elements[idx]
            } else {
                bar = String(repeating: hbar_elements[hbar_elements.count-1], count: Int(wi))+hbar_elements[idx]
            }
            
            var pad = Int(col)-bar.count
            if pad < 0 {
                pad = 0
            }
            bar += String(repeating: hbar_elements[0], count: pad)
            
            //print(peak)
            //print(line)
            if line < peak {
                line = peak
            }
            for i in peak...line {
                wmove(win, i, 1+(offset ?? 0))
                waddstr(win, bar)
            }
        } else if vgauge != 0 {
            if title != "" {
                line -= 1
            }
            for dx in 0..<line {
                var bar = ""
                for dy in 0..<col {
                    if datapoint!.count > 0 {
                        var dp_index = Int(dy - t.w+1)
                        if dp_index < 0 {
                            dp_index += datapoint!.count
                        }
                        if dp_index < datapoint!.count && dp_index >= 0 {
                            var dp = datapoint?[dp_index] ?? 0
                            if dp > 100 {
                                dp = 100
                            } else if dp < 0 {
                                dp = 0
                            }
                            let q = (1 - dp/100) * Float(line)
                            if dx == Int(q) {
                                var idx = Int((Float(Int(q)) - q)*8 - 1)
                                while idx < 0 {
                                    idx += vbar_elements.count
                                }
                                bar += vbar_elements[idx]
                            } else if dx < Int(q) {
                                bar += " "
                            } else {
                                bar += vbar_elements[vbar_elements.count - 1]
                            }
                        } else {
                            bar += " "
                        }
                    }
                }
                wmove(win, dx+1, 0)
                waddstr(win, bar)
            }
        }
        wattroff(win, COLOR_PAIR(1))
        if render {
            wrefresh(win)
        }
    }
}

func display(_ disp: dispInfo, _ gn: Bool = false, _ scrin: tbox? = nil, _ xy: [Int32], _ colr: UInt8 = 2, _ bottom: OpaquePointer? = nil) -> refreshInfo {
    let size = get_size()
    let lines = size[0]
    let cols = size[1]
    var btm: OpaquePointer? = nil
    var dark: Bool = true
    
    if colr == black {
        init_pair(1, Int16(colr), Int16(white))
        dark = false
    } else {
        init_pair(1, Int16(colr), Int16(black))
    }
    
    var scrn = scrin ?? screen_init(dark: dark)
    
    if lines < 34 || cols < 63 {
        endwin()
        print("Terminal size is too small!\nThis tool needs 63 cols and 34 lines at least!")
        exit(1)
    }

    if (cols != xy[0]) || (lines != xy[1]) {
        if !gn {
            var first_box = 1
            if sd.fan_exist {
                del_tbox(tbx: &scrn.items[0].items[2].items[0])
                first_box = 2
            }
            for i in (0...first_box).reversed() {
                del_tbox(tbx: &scrn.items[0].items[i])
            }
            for i in (0...1).reversed() {
                del_tbox(tbx: &scrn.items[1].items[i])
            }
            for i in 0...2 {
                del_tbox(tbx: &scrn.items[i])
            }
            del_tbox(tbx: &scrn)
        }
        scrn = screen_init(dark: dark)
    }
    
    var first_stack: Int32 = 2
    if sd.fan_exist {
        first_stack = 3
    }
    
    //print("rendering start")
    autoreleasepool {
        Stack(
            size: 3,
            title: [disp.proc_grp, disp.mem_grp, disp.pwr_grp],
            border: 1, stack: .vsplit, tbx: &scrn, render: !gn, dark: dark
        )
        //print("three box")
        Stack(
            size: first_stack,
            title: [], border: 0, stack: .vsplit,
            tbx: &scrn.items[0], render: !gn, dark: dark
        )
        //print("first box")
        Stack(
            size: 2, title: [disp.ram_usg.title, disp.bw_grp],
            border: 0, stack: .vsplit, tbx: &scrn.items[1], render: !gn, dark: dark
        )
        //print("second box")
        Stack(
            size: 2, title: [disp.cpu_pwr.title, disp.gpu_pwr.title],
            border: 0, stack: .hsplit, tbx: &scrn.items[2], render: !gn, dark: dark
        )
    }
    
    //print("third box")
    var first_box = [[""]]
    if sd.fan_exist {
        first_box = [
            [disp.ecpu_usg.title, disp.pcpu_usg.title],
            [disp.gpu_usg.title, disp.ane_usg.title],
            [disp.fan_usg.title, ""]
        ]
    } else {
        first_box = [
            [disp.ecpu_usg.title, disp.pcpu_usg.title],
            [disp.gpu_usg.title, disp.ane_usg.title]
        ]
    }
    
    for (idx, titl) in first_box.enumerated() {
        Stack(
            size: 2, title: titl, border: 0, stack: .hsplit,
            tbx: &scrn.items[0].items[idx], render: !gn, dark: dark
        )
    }
    //print("fan gauge start")
    autoreleasepool {
        if sd.fan_mode > 0 {
            Stack(
                size: Int32(sd.fan_mode), title: ["", ""], border: 0,
                stack: .vsplit, tbx: &scrn.items[0].items[2].items[0],
                render: !gn, dark: dark
            )
            for i in 0...sd.fan_mode-1 {
                Gauge(
                    value: disp.fan_usg.val[i],
                    gauge: .hgauge,
                    tbx: &scrn.items[0].items[2].items[0].items[i],
                    offset: -1,
                    render: !gn
                ) // FAN Speed
            }
        }
    }
    //print("fan gauge finish")
    
    let proc_gauge_info = [
        [disp.ecpu_usg.val, disp.pcpu_usg.val],
        [disp.gpu_usg.val, disp.ane_usg.val]
    ]
    for i in 0...1 {
        for j in 0...1 {
            //print("processor gauge start")
            Gauge(
                value: proc_gauge_info[i][j],
                gauge: .hgauge,
                tbx: &scrn.items[0].items[i].items[j],
                render: !gn
            )
        }
    } //processor utilization group
    //print("processor gauge finish")
    
    if sd.fan_exist {
        let fan_label = scrn.items[0].items[2].items[1].t
        var mid = Int32((fan_label.h-1)/2)
        wattron(fan_label.win, COLOR_PAIR(1))
        for i in disp.airflow_info {
            wmove(fan_label.win, mid, 0)
            waddstr(fan_label.win, i)
            mid += 1
        }
        wattroff(fan_label.win, COLOR_PAIR(1))
        if !gn {
            wrefresh(fan_label.win)
        }
    }
    
    Gauge(
        value: disp.ram_usg.val,
        gauge: .hgauge,
        tbx: &scrn.items[1].items[0],
        render: !gn
    ) // RAM Usage
    //print("ram gauge finish")
    autoreleasepool {
        Stack(
            size: 4,
            title: [
                disp.ecpu_bw.title, disp.pcpu_bw.title,
                disp.gpu_bw.title, disp.media_bw.title
            ],
            border: 0, stack: .hsplit,
            tbx: &scrn.items[1].items[1], render: !gn, dark: dark
        )
    }
    
    let bw_grp = [
        disp.ecpu_bw.val, disp.pcpu_bw.val,
        disp.gpu_bw.val, disp.media_bw.val
    ]
    for i in 0...3 {
        Gauge(
            value: bw_grp[i], gauge: .hgauge,
            tbx: &scrn.items[1].items[1].items[i],
            render: !gn
        )
    } // Bandwidth Group
    //print("bw gauge finish")
    Gauge(
        gauge: .vgauge, tbx: &scrn.items[2].items[0],
        datapoint: disp.cpu_pwr.val,
        render: !gn
    )
    //print("cpu_pwr gauge finish")
    Gauge(
        gauge: .vgauge, tbx: &scrn.items[2].items[1],
        datapoint: disp.gpu_pwr.val,
        render: !gn
    )
    //print("gpu_pwr gauge finish")
    btm = screen_bottom(bottom)
    return refreshInfo(tbx: scrn, bottom: btm, xy: [cols, lines])
}
