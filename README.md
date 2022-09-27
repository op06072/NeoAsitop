# neoasitop

Sudoless performance monitoring CLI tool for Apple Silicon

![](image/neoasitop.png)

## What is `neoasitop`

A Swift-based `asitop`-inspired command line tool for Apple Silicon (aka M1) Macs.

* Utilization info:
  * CPU (E-cluster and P-cluster), GPU
  * Frequency and utilization, temperature
  * ANE utilization (measured by power)
  * Fan speed (if fan exists)
* Memory info:
  * RAM and swap, size and usage
  * Memory bandwidth (CPU/GPU/total)
  * Media engine bandwidth usage
* Power info:
  * System power, CPU power, GPU power, DRAM power
  * Chart for CPU/GPU power
  * Peak power, rolling average display

`neoasitop` uses the custom [`socpowerbuddy`](https://github.com/BitesPotatoBacks/SocPowerBuddy)-inspired logic, which allows access to a variety of hardware performance counters without sudo permission. `neoasitop` is lightweight and has minimal performance impact.

**`neoasitop` only tested on Apple Silicon Macs on macOS Monterey!**

## Installation and Usage

1. Download the .zip file from [latest release](https://github.com/op06072/NeoAsitop/releases).
2. Unzip the downloaded file (via Finder or Terminal)
3. Resolve the binary limitation from external source with `xattr -cr neoasitop`
4. Move the binary from the unzipped folder into your desired location (such as `/usr/bin`)
5. You may now run the tool using the `neoasitop` binary

```shell
# advanced options
neoasitop [--interval <interval>] [--color <color>] [--avg <avg>]

OPTIONS:
  -i, --interval <interval>
                          Display interval and sampling interval for info gathering (seconds) (default: 1)
  -c, --color <color>     Choose display color (0~8) (default: 2)
  --avg <avg>             Interval for averaged values (seconds) (default: 30)
  -h, --help              Show help information.
```

## How it works

[`socpowerbuddy`](https://github.com/BitesPotatoBacks/SocPowerBuddy)-inspired custom logic is used to measure the following:

* CPU/GPU utilization via active residency
* CPU/GPU frequency
* CPU/GPU/ANE/DRAM energy consumption
* CPU/GPU/Media Total memory bandwidth via the DCS (DRAM Command Scheduler)
* CPU/GPU core count

[`stats`](https://github.com/exelban/stats)-inspired custom logic is used to measure the following:

* CPU/GPU/Airflow temperature
* Fan speed
* System energy consumption

[`sysctl`](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/sysctl.3.html) is used to measure the following:

* CPU name
* CPU core counts
* Fan existence
* memory and swap usage

Some information is guesstimate and hardcoded as there doesn't seem to be a official source for it on the system:

* CPU/GPU TDP
* CPU/GPU maximum memory bandwidth
* ANE max power
* Media engine max bandwidth

## Why

Because I didn't find something like this online. Also, just curious about stuff.

## Disclaimers

I just get this from `asitop` don't blame me if it fried your new MacBook or something.