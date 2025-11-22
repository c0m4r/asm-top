# ASM-TOP

A lightweight system monitoring tool written in pure x86-64 assembly for Linux. Displays real-time CPU and RAM usage statistics similar to the `top` command.

## Features

- **CPU Monitoring**: Real-time CPU usage percentage
- **Memory Monitoring**: Real-time RAM usage percentage
- **Visual Progress Bars**: Text-based bars showing resource utilization
- **System Info Display**: Shows hostname and current time (HH:MM:SS)
- **Interactive Controls**: Press 'q' to quit
- **Minimal Dependencies**: Pure assembly, no external libraries
- **Lightweight**: Extremely small binary size (13KB) and minimal resource usage

## Quick install (x86_64 GNU/Linux)

```bash
wget https://github.com/c0m4r/asm-top/releases/download/0.1.0/asm-top
echo "5bfb9e210486d5be35bff6e2601356dabfc55eee9cdbe63192a6133b998580fa  asm-top" | sha256sum -c || rm -f asm-top
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
make
```

This will create the `asm-top` executable.

### Clean Build

```bash
make clean
make
```

## Usage

Simply run the executable:

```bash
./asm-top
```

The display will update every second showing:
- Hostname and current time in the header
- CPU usage percentage with a visual progress bar
- RAM usage percentage with a visual progress bar

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
- **Memory**: `/proc/meminfo` - Extracts MemTotal and MemAvailable  
- **Hostname**: `/proc/sys/kernel/hostname` - System hostname
- **Time**: `time()` syscall - Current Unix timestamp converted to HH:MM:SS

### CPU Calculation
```
Total = user + nice + system + idle + iowait + irq + softirq
Idle = idle + iowait
NonIdle = Total - Idle

CPU% = ((NonIdle_now - NonIdle_prev) / (Total_now - Total_prev)) × 100
```

### Memory Calculation
```
Used = MemTotal - MemAvailable
Memory% = (Used / MemTotal) × 100
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
