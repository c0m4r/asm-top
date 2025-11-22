# Assembly Language Guide for ASM-TOP

A comprehensive guide to understanding the x86-64 assembly language used in this project.

## Table of Contents

1. [Introduction](#introduction)
2. [Registers](#registers)
3. [Data Movement](#data-movement)
4. [Arithmetic Operations](#arithmetic-operations)
5. [Logical Operations](#logical-operations)
6. [Comparison and Branching](#comparison-and-branching)
7. [Function Calls](#function-calls)
8. [Memory Access](#memory-access)
9. [System Calls](#system-calls)
10. [Code Examples from ASM-TOP](#code-examples-from-asm-top)

---

## Introduction

Assembly language is a low-level programming language where each instruction corresponds directly to a machine code operation. In x86-64 assembly, we work with:

- **Registers**: Fast, small storage locations in the CPU
- **Memory**: Larger, slower storage accessed via addresses
- **Instructions**: Operations like move, add, compare, jump

This project uses **Intel syntax** (as opposed to AT&T syntax), where the destination comes first:
```asm
mov rax, 5      ; Intel: destination, source
```

---

## Registers

Registers are small, fast storage locations built into the CPU. x86-64 has 16 general-purpose 64-bit registers.

### General Purpose Registers

| Register | Purpose | Common Use |
|----------|---------|------------|
| `rax` | Accumulator | Return values, arithmetic |
| `rbx` | Base | General purpose, base pointer |
| `rcx` | Counter | Loop counters, function arg 4 |
| `rdx` | Data | Arithmetic, function arg 3 |
| `rsi` | Source Index | Source pointer, function arg 2 |
| `rdi` | Destination Index | Destination pointer, function arg 1 |
| `rbp` | Base Pointer | Stack frame base |
| `rsp` | Stack Pointer | Top of stack |
| `r8-r15` | Extended | General purpose (r8=arg 5, r9=arg 6) |

### Register Naming Conventions

Registers have different names based on size:

```asm
rax     ; 64-bit (full register)
eax     ; 32-bit (lower 32 bits)
ax      ; 16-bit (lower 16 bits)
al/ah   ; 8-bit (lower/higher 8 bits)
```

**Example from `cpu.asm`:**
```asm
mov r8, rax       ; r8 = user time (64-bit)
add r8, rax       ; r8 += nice time
```

---

## Data Movement

### `mov` - Move Data

**Syntax:** `mov destination, source`

Copies data from source to destination. The source remains unchanged.

```asm
mov rax, 5              ; rax = 5 (immediate value)
mov rbx, rax            ; rbx = rax (register to register)
mov [mem_total], rax    ; Store rax to memory location mem_total
mov rax, [mem_total]    ; Load from memory into rax
```

**Example from `memory.asm`:**
```asm
mov rax, [mem_total]
sub rax, [mem_available]    ; Calculate used memory
```

### `movzx` - Move with Zero Extension

Copies a smaller value to a larger register, filling upper bits with zeros.

```asm
movzx rax, byte [rdi]   ; Load byte, zero-extend to 64-bit
movzx rcx, word [rsi]   ; Load 16-bit word, zero-extend
```

**Example from `utils.asm`:**
```asm
movzx rcx, byte [rdi]   ; Load single character
cmp rcx, '0'            ; Compare with '0'
```

### `lea` - Load Effective Address

Calculates an address without accessing memory.

```asm
lea rax, [rbx + rcx*8 + 16]   ; rax = rbx + (rcx * 8) + 16
```

### `xor` - Used for Zeroing

While `xor` is a logical operation, it's commonly used to zero a register:

```asm
xor rax, rax    ; rax = 0 (faster than mov rax, 0)
xor rdx, rdx    ; Clear rdx before division
```

**Example from `cpu.asm`:**
```asm
xor rax, rax    ; Return 0 for success
```

---

## Arithmetic Operations

### `add` - Addition

**Syntax:** `add destination, source`

Adds source to destination and stores result in destination.

```asm
add rax, 5      ; rax = rax + 5
add rbx, rcx    ; rbx = rbx + rcx
```

**Example from `cpu.asm`:**
```asm
add r8, rax     ; r8 += nice time
add r9, rax     ; r9 += iowait
```

### `sub` - Subtraction

**Syntax:** `sub destination, source`

Subtracts source from destination.

```asm
sub rax, 10     ; rax = rax - 10
sub rcx, rbx    ; rcx = rcx - rbx
```

**Example from `memory.asm`:**
```asm
mov rax, [mem_total]
sub rax, [mem_available]    ; used = total - available
```

### `inc` / `dec` - Increment/Decrement

Adds or subtracts 1 from the operand.

```asm
inc rax     ; rax = rax + 1
dec rcx     ; rcx = rcx - 1
```

**Example from `main.asm`:**
```asm
dec r12         ; Decrement loop counter
jnz sleep_loop  ; Jump if not zero
```

### `imul` - Signed Multiplication

**Syntax:** `imul destination, source`

Multiplies destination by source.

```asm
imul rax, 10    ; rax = rax * 10
```

**Example from `cpu.asm`:**
```asm
mov rdx, 100
imul rax, rdx   ; rax = non_idle_diff * 100
```

### `div` - Unsigned Division

Divides `rdx:rax` (128-bit) by source. Quotient goes to `rax`, remainder to `rdx`.

```asm
xor rdx, rdx    ; Clear upper 64 bits (important!)
div rcx         ; rax = (rdx:rax) / rcx, rdx = remainder
```

**Example from `cpu.asm`:**
```asm
xor rdx, rdx                ; Clear for division
div rcx                     ; CPU% = (non_idle * 100) / total_diff
```

---

## Logical Operations

### `and` - Bitwise AND

Performs bitwise AND operation.

```asm
and rax, 0xFF   ; Keep only lower 8 bits
```

**Example from `terminal.asm`:**
```asm
not ebx         ; Flip all bits
and eax, ebx    ; Clear ICANON and ECHO flags
```

### `or` - Bitwise OR

Performs bitwise OR operation.

```asm
or rax, rbx     ; Set bits that are 1 in either
```

### `not` - Bitwise NOT

Inverts all bits.

```asm
not rax         ; Flip all bits in rax
```

### `test` - Logical Test

Performs AND without storing the result, only sets flags.

```asm
test rax, rax   ; Check if rax is zero
jz .zero        ; Jump if zero
```

**Example from `input.asm`:**
```asm
test rax, POLLIN    ; Check if POLLIN flag is set
jz .no_input        ; Jump if not set
```

---

## Comparison and Branching

### `cmp` - Compare

**Syntax:** `cmp operand1, operand2`

Subtracts operand2 from operand1 without storing the result. Sets flags for conditional jumps.

```asm
cmp rax, 5      ; Compare rax with 5
je .equal       ; Jump if equal
jl .less        ; Jump if less
```

**Example from `utils.asm`:**
```asm
cmp rcx, '0'
jb .done        ; Jump if below '0' (not a digit)
cmp rcx, '9'
ja .done        ; Jump if above '9' (not a digit)
```

### Conditional Jumps

Jump instructions transfer control based on flags set by `cmp` or `test`.

| Instruction | Meaning | Condition |
|-------------|---------|-----------|
| `je` / `jz` | Jump if Equal / Zero | ZF = 1 |
| `jne` / `jnz` | Jump if Not Equal / Not Zero | ZF = 0 |
| `jl` / `jb` | Jump if Less / Below | SF ≠ OF / CF = 1 |
| `jle` / `jbe` | Jump if Less or Equal / Below or Equal | ZF = 1 or SF ≠ OF |
| `jg` / `ja` | Jump if Greater / Above | ZF = 0 and SF = OF |
| `jge` / `jae` | Jump if Greater or Equal / Above or Equal | SF = OF |

**Example from `main.asm`:**
```asm
call check_input
cmp rax, -1             ; Check if quit signal
je exit_program         ; Jump to exit if -1
```

### Unconditional Jump

`jmp` always transfers control to the target.

```asm
jmp main_loop           ; Always jump to main_loop
```

---

## Function Calls

### `call` - Call Function

Pushes the return address onto the stack and jumps to the function.

```asm
call my_function    ; Save return address, jump to my_function
```

**Example from `main.asm`:**
```asm
call check_input        ; Call check_input function
cmp rax, -1             ; Check return value
```

### `ret` - Return from Function

Pops the return address from the stack and jumps to it.

```asm
ret     ; Return to caller
```

### Function Prologue/Epilogue

Standard pattern for preserving stack frame:

```asm
; Prologue - set up stack frame
push rbp            ; Save old base pointer
mov rbp, rsp        ; Set new base pointer

; Function body here...

; Epilogue - restore stack frame
pop rbp             ; Restore old base pointer
ret                 ; Return to caller
```

**Example from `cpu.asm`:**
```asm
init_cpu:
    push rbp
    mov rbp, rsp
    
    call read_cpu_stat      ; Do work
    
    pop rbp
    ret
```

### `push` / `pop` - Stack Operations

**`push`**: Decrements `rsp` and stores value on stack
**`pop`**: Loads value from stack and increments `rsp`

```asm
push rax        ; Save rax on stack
push rbx        ; Save rbx on stack
; ... do work ...
pop rbx         ; Restore rbx (LIFO order)
pop rax         ; Restore rax
```

**Example from `display.asm`:**
```asm
display_stats:
    push rbp
    push rbx
    push r12
    push r13        ; Save registers
    ; ... function code ...
    pop r13
    pop r12
    pop rbx
    pop rbp         ; Restore in reverse order
    ret
```

---

## Memory Access

### Direct Memory Access

```asm
mov rax, [address]      ; Load from memory
mov [address], rax      ; Store to memory
```

**Example from `cpu.asm`:**
```asm
mov [curr_total], rax   ; Store current total
mov rax, [prev_total]   ; Load previous total
```

### Indexed Memory Access

```asm
mov al, [rdi + rax]     ; Load byte at rdi + rax
mov [rbx + rcx*8], rax  ; Store with scale factor
```

**Example from `sysinfo.asm`:**
```asm
cmp byte [hostname_buf + rax], 10   ; Check for newline
mov byte [hostname_buf + rax], 0    ; Replace with null
```

### String Operations

```asm
rep movsb       ; Repeat move byte (used in terminal.asm)
```

**Example from `terminal.asm`:**
```asm
mov rcx, 60             ; Count
mov rsi, orig_termios   ; Source
mov rdi, new_termios    ; Destination
rep movsb               ; Copy 60 bytes
```

---

## System Calls

### `syscall` - Invoke Kernel

Makes a system call to the Linux kernel.

**Calling Convention:**
- Syscall number in `rax`
- Arguments in `rdi`, `rsi`, `rdx`, `r10`, `r8`, `r9`
- Return value in `rax`

**Example from `syscalls.asm`:**
```asm
sys_write:
    mov rax, 1      ; syscall number for write
    syscall         ; invoke kernel
    ret             ; return value in rax
```

**Common System Calls:**

| Number | Name | rdi | rsi | rdx |
|--------|------|-----|-----|-----|
| 0 | read | fd | buffer | count |
| 1 | write | fd | buffer | count |
| 2 | open | filename | flags | mode |
| 3 | close | fd | - | - |
| 7 | poll | fds | nfds | timeout |
| 35 | nanosleep | req | rem | - |
| 60 | exit | code | - | - |

---

## Code Examples from ASM-TOP

### Example 1: Reading /proc/stat (cpu.asm)

```asm
; Open /proc/stat
mov rdi, proc_stat_path     ; filename
xor rsi, rsi                ; O_RDONLY = 0
xor rdx, rdx                ; mode (unused)
call sys_open               ; Open file

cmp rax, 0                  ; Check if fd < 0
jl .error                   ; Jump if error
mov rbx, rax                ; Save file descriptor

; Read file contents
mov rdi, rbx                ; fd
mov rsi, cpu_buffer         ; buffer address
mov rdx, 4096               ; count
call sys_read               ; Read into buffer

; Close file
mov rdi, rbx                ; fd
call sys_close              ; Close file
```

**What it does:**
1. Opens `/proc/stat` for reading
2. Checks if open succeeded (fd >= 0)
3. Reads up to 4096 bytes into buffer
4. Closes the file descriptor

### Example 2: String to Integer Conversion (utils.asm)

```asm
str_to_int:
    xor rax, rax            ; result = 0
    xor rcx, rcx            ; temp = 0
.loop:
    movzx rcx, byte [rdi]   ; Load character
    cmp rcx, '0'
    jb .done                ; if < '0', not a digit
    cmp rcx, '9'
    ja .done                ; if > '9', not a digit
    sub rcx, '0'            ; Convert ASCII to number
    imul rax, 10            ; result *= 10
    add rax, rcx            ; result += digit
    inc rdi                 ; Next character
    jmp .loop
.done:
    ret
```

**What it does:**
1. Starts with result = 0
2. Loops through each character
3. Checks if it's a digit ('0'-'9')
4. Converts ASCII to numeric value (subtract '0')
5. Builds number: result = result * 10 + digit
6. Returns when non-digit found

**Example:** "123" → 1*10² + 2*10¹ + 3*10⁰ = 123

### Example 3: CPU Percentage Calculation (cpu.asm)

```asm
calculate_cpu_percent:
    ; total_diff = curr_total - prev_total
    mov rax, [curr_total]
    sub rax, [prev_total]
    mov rcx, rax            ; rcx = total_diff
    
    ; Check for divide by zero
    test rcx, rcx
    jz .zero_usage
    
    ; idle_diff = curr_idle - prev_idle
    mov rax, [curr_idle]
    sub rax, [prev_idle]
    
    ; non_idle_diff = total_diff - idle_diff
    mov rdx, rcx
    sub rdx, rax            ; rdx = non_idle_diff
    
    ; cpu_percent = (non_idle_diff * 100) / total_diff
    mov rax, rdx
    mov rdx, 100
    imul rax, rdx           ; rax = non_idle * 100
    xor rdx, rdx            ; Clear for division
    div rcx                 ; rax = result
    
    ret
```

**What it does:**
1. Calculates difference in total CPU time
2. Checks for division by zero
3. Calculates difference in idle time
4. Computes active time: total_diff - idle_diff
5. Converts to percentage: (active * 100) / total
6. Returns percentage in `rax`

### Example 4: Main Loop with Input Check (main.asm)

```asm
main_loop:
    ; Check for 'q' key
    call check_input
    cmp rax, -1
    je exit_program         ; Exit if 'q' pressed
    
    ; Read and calculate CPU
    call read_cpu_stat
    call calculate_cpu_percent
    push rax                ; Save CPU%
    
    ; Read and calculate RAM
    call read_mem_info
    call calculate_mem_percent
    mov rsi, rax            ; rsi = RAM%
    pop rdi                 ; rdi = CPU%
    
    ; Display
    call display_stats
    
    ; Sleep 1 second (10 x 100ms)
    mov r12, 10
sleep_loop:
    call check_input        ; Check every 100ms
    cmp rax, -1
    je exit_program
    
    mov rdi, sleep_time
    xor rsi, rsi
    call sys_nanosleep
    
    dec r12
    jnz sleep_loop          ; Loop while r12 != 0
    
    jmp main_loop           ; Repeat forever
```

**What it does:**
1. Checks if user pressed 'q'
2. Reads CPU and memory stats
3. Calculates percentages
4. Displays results
5. Sleeps for 1 second, checking for input every 100ms
6. Loops forever until 'q' pressed

---

## Tips for Reading Assembly Code

1. **Follow the Data Flow**: Track how values move through registers
2. **Understand Call Conventions**: Function args in rdi, rsi, rdx, rcx, r8, r9
3. **Watch the Stack**: push/pop must be balanced
4. **Pay Attention to Flags**: cmp/test set flags; jumps use them
5. **Comments are Gold**: Read the comments to understand intent
6. **Start from Entry Point**: Begin at `_start` in main.asm
7. **Follow Function Calls**: Use ctrl+click in modern editors

---

## Common Patterns

### Loop Pattern
```asm
mov rcx, 10         ; Counter
.loop:
    ; ... do work ...
    dec rcx
    jnz .loop       ; Continue if rcx != 0
```

### Conditional Pattern
```asm
cmp rax, 0
jl .error           ; if (rax < 0) goto error
; success path
ret
.error:
; error handling
```

### Function Call Pattern
```asm
mov rdi, arg1       ; First argument
mov rsi, arg2       ; Second argument
call function       ; Call
; Result in rax
```

---

## Resources

- **Intel Manual**: Official x86-64 architecture documentation
- **[Felix Cloutier's x86 Reference](https://www.felixcloutier.com/x86/)**: Excellent instruction reference
- **[Linux System Call Table](https://filippo.io/linux-syscall-table/)**: All syscall numbers
- **GDB**: Use debugger to step through code and inspect registers

---

## Conclusion

Assembly requires thinking about low-level details, but it offers:
- **Complete Control**: Direct hardware access
- **Maximum Performance**: No abstraction overhead
- **Deep Understanding**: See exactly what the CPU does

By studying the ASM-TOP codebase with this guide, you'll gain practical experience with real-world assembly programming!
