# ASM-TOP

A lightweight system monitoring tool written in pure x86-64 assembly for Linux. Displays real-time CPU and RAM usage statistics similar to the `top` command.

```
=== ASM-TOP - localhost @ 09:56:14 ===
uptime: 21h 59m  load: 0.96 1.23 1.37 
Tasks: 1662 total, 2 running
CPU:  [######..................................] 16%
RAM:  [############################............] 71% (5 GB/7 GB)
SWAP: [###.....................................] 8% (1 GB/16 GB)

Press 'q' to exit
```

## Features

- **CPU Monitoring**: Real-time CPU usage percentage
- **Memory Monitoring**: Real-time RAM and Swap usage percentage with detailed stats
- **System Stats**: Uptime, Load Average, and Task breakdown
- **Visual Progress Bars**: Text-based bars showing resource utilization
- **System Info Display**: Shows hostname and current time (HH:MM:SS)
- **Interactive Controls**: Press 'q' to quit
- **Minimal Dependencies**: Pure assembly, no external libraries
- **Lightweight**: Extremely small binary size (13KB) and minimal resource usage

## Quick install (x86_64 GNU/Linux)

```bash
wget https://github.com/c0m4r/asm-top/releases/download/0.3.1/asm-top
echo "67d659d6748fe1528c6559e9c31a5f622ca7184485bcddd4cf9b9fe9304026bf  asm-top" | sha256sum -c || rm -f asm-top
sudo mv asm-top /usr/local/bin/
sudo chmod +x /usr/local/bin/asm-top
asm-top
```

## Building

### Prerequisites

- GNU Assembler (`as`) - part of binutils
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
- Hostname and current time in the header
- System Uptime, Load Average, and Task counts
- CPU usage percentage with a visual progress bar
- RAM usage percentage with a visual progress bar and size details
- Swap usage percentage with a visual progress bar and size details

Press `q` to quit gracefully.

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
- `time(201)`: Get current time
- `exit(60)`: Program termination

### Data Sources
- **CPU**: `/proc/stat` - Parses total CPU time including user, nice, system, idle, iowait, irq, and softirq
- **Memory/Swap**: `/proc/meminfo` - Extracts MemTotal, MemAvailable, SwapTotal, and SwapFree
- **Load/Tasks**: `/proc/loadavg` - Load averages and running/total tasks
- **Uptime**: `/proc/uptime` - System uptime
- **Hostname**: `/proc/sys/kernel/hostname` - System hostname
- **Time**: `time()` syscall - Current Unix timestamp converted to HH:MM:SS

### CPU Calculation
```
Total = user + nice + system + idle + iowait + irq + softirq
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
├── sysinfo.asm    - Hostname and time retrieval
├── Makefile       - Build configuration
├── .gitignore     - Git ignore file
└── README.md      - This file
```

## License

Public domain - use freely for any purpose.

## Author

Created with pure assembly by Gemini 3 Pro (High) for maximum performance and minimal overhead.
