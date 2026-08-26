# ASM-TOP

A lightweight system monitoring tool written in pure x86-64 assembly for Linux. Displays real-time CPU and RAM usage statistics similar to the `top` command.

```
=== ASM-TOP - localhost @ 09:56:14 UTC ===
uptime: 21h 59m  load: 0.96 1.23 1.37 
Tasks: 1662 total, 2 running
CPU:  [######..................................] 16%
RAM:  [############################............] 71% (5 GB/7 GB)
SWAP: [###.....................................] 8% (1 GB/16 GB)

Press 'q' or Ctrl-C to exit
```

## Features

- **CPU Monitoring**: Real-time CPU usage percentage
- **Memory Monitoring**: Real-time RAM and Swap usage percentage with detailed stats
- **System Stats**: Uptime, Load Average, and Task breakdown
- **Visual Progress Bars**: Text-based bars showing resource utilization
- **System Info Display**: Shows hostname and current UTC time (HH:MM:SS)
- **Interactive Controls**: Press 'q' or Ctrl-C to quit; Ctrl-Z safely suspends and resumes
- **Minimal Dependencies**: Pure assembly, no external libraries
- **Lightweight**: Extremely small binary size (~21KB) and minimal resource usage

<img width="679" height="71" alt="image" src="https://github.com/user-attachments/assets/580725b0-0f97-4ee6-a43b-09af0103afe0" />

## Quick install (x86_64 GNU/Linux)

```bash
wget https://github.com/c0m4r/asm-top/releases/download/0.3.2/asm-top
echo "9947e22ddef2edc105f7e156375b8d8e090912046a38d66bb13a2d7325a738c7  asm-top" | sha256sum -c || rm -f asm-top
sudo mv asm-top /usr/local/bin/
sudo chmod +x /usr/local/bin/asm-top
asm-top
```

## Building

### Prerequisites

- NASM (`nasm`)
- GNU Linker (`ld`) - part of binutils
- Linux kernel with `/proc` filesystem

### Compile

```bash
./configure
make
```

This will create the `asm-top` executable.

### Clean Build

```bash
make clean
```

### Install

```bash
make install
```

## Usage

Simply run the executable:

```bash
./asm-top
```

The display will update every second showing:
- Hostname and current UTC time in the header
- System Uptime, Load Average, and Task counts
- CPU usage percentage with a visual progress bar
- RAM usage percentage with a visual progress bar and size details
- Swap usage percentage with a visual progress bar and size details

Press `q` or Ctrl-C to quit gracefully. Ctrl-Z restores the terminal before
suspending and reinitializes the display after `fg`/SIGCONT.

## Technical Details

### Architecture
- **Platform**: x86-64 (64-bit)
- **Syntax**: Intel syntax
- **OS**: Linux (requires `/proc` filesystem)

### System Calls Used
- `open(2)`: Open `/proc/stat`, `/proc/meminfo`, and `/proc/sys/kernel/hostname`
- `read(0)`: Read file contents
- `write(1)`: Output to stdout
- `close(3)`: Close file descriptors
- `nanosleep(35)`: Sleep between updates
- `poll(7)`: Non-blocking keyboard input detection
- `rt_sigaction(13)`: Graceful termination signal handling
- `getpid(39)`, `kill(62)`: Safe suspend/resume lifecycle
- `time(201)`: Get current time
- `exit(60)`: Program termination

### Data Sources
- **CPU**: `/proc/stat` - Parses total CPU time including user, nice, system, idle, iowait, irq, softirq, and steal
- **Memory/Swap**: `/proc/meminfo` - Extracts MemTotal, MemAvailable, SwapTotal, and SwapFree
- **Load/Tasks**: `/proc/loadavg` - Load averages and running/total tasks
- **Uptime**: `/proc/uptime` - System uptime
- **Hostname**: `/proc/sys/kernel/hostname` - System hostname
- **Time**: `time()` syscall - Current Unix timestamp converted to HH:MM:SS UTC

### CPU Calculation
```
Total = user + nice + system + idle + iowait + irq + softirq + steal
Idle = idle + iowait
NonIdle = Total - Idle

CPU% = ((NonIdle_now - NonIdle_prev) / (Total_now - Total_prev)) × 100
```

### Memory and Swap Calculation
```
MemUsed = MemTotal - MemAvailable
Memory% = (MemUsed / MemTotal) × 100

SwapUsed = SwapTotal - SwapFree
Swap% = (SwapUsed / SwapTotal) × 100
```

## Project Structure

```
asm-top/
├── main.asm       - Program entry point and main loop
├── cpu.asm        - CPU monitoring functions
├── memory.asm     - Memory monitoring functions
├── syscalls.asm   - System call wrappers
├── utils.asm      - Utility functions (string/number conversion)
├── display.asm    - Display formatting and output
├── input.asm      - Non-blocking keyboard input
├── signals.asm    - Graceful termination signal handling
├── sysinfo.asm    - Hostname and time retrieval
├── Makefile       - Build configuration
├── .gitignore     - Git ignore file
└── README.md      - This file
```

## License

Public domain - use freely for any purpose.

## Author

Created with pure assembly by Gemini 3 Pro (High) for maximum performance and minimal overhead.
