; cpu.asm - CPU monitoring functions
; Intel syntax

section .data
    proc_stat_path: db "/proc/stat", 0

section .bss
    cpu_buffer: resb 4096       ; Buffer for /proc/stat content
    prev_total: resq 1          ; Previous total CPU time
    prev_idle: resq 1           ; Previous idle CPU time
    curr_total: resq 1          ; Current total CPU time
    curr_idle: resq 1           ; Current idle CPU time

section .text
extern sys_open
extern sys_read
extern sys_close
extern str_to_int
extern skip_whitespace

global read_cpu_stat
global calculate_cpu_percent
global init_cpu

; init_cpu - Initialize CPU monitoring (first reading)
; No arguments
; Returns: nothing
init_cpu:
    push rbp
    mov rbp, rsp
    
    call read_cpu_stat          ; Read initial values
    
    ; Store as previous values
    mov rax, [curr_total]
    mov [prev_total], rax
    mov rax, [curr_idle]
    mov [prev_idle], rax
    
    pop rbp
    ret

; read_cpu_stat - Read and parse /proc/stat
; No arguments
; Returns: rax = 0 on success, -1 on error
read_cpu_stat:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    
    ; Open /proc/stat
    mov rdi, proc_stat_path
    xor rsi, rsi                ; O_RDONLY = 0
    xor rdx, rdx
    call sys_open
    
    cmp rax, 0
    jl .error                   ; if fd < 0, error
    mov rbx, rax                ; save fd
    
    ; Read file
    mov rdi, rbx
    mov rsi, cpu_buffer
    mov rdx, 4096
    call sys_read
    
    mov r12, rax                ; save bytes read
    
    ; Close file
    mov rdi, rbx
    call sys_close
    
    ; Check if we read anything
    cmp r12, 0
    jle .error
    
    ; Parse the first line (starts with "cpu ")
    ; Format: cpu <user> <nice> <system> <idle> <iowait> <irq> <softirq> ...
    mov rdi, cpu_buffer
    add rdi, 4                  ; skip "cpu "
    
    ; Read user time
    call skip_whitespace
    mov rdi, rax
    call str_to_int
    mov r8, rax                 ; r8 = user
    
    ; Read nice time
    call skip_whitespace
    mov rdi, rax
    call str_to_int
    add r8, rax                 ; r8 += nice
    
    ; Read system time
    call skip_whitespace
    mov rdi, rax
    call str_to_int
    add r8, rax                 ; r8 += system
    
    ; Read idle time
    call skip_whitespace
    mov rdi, rax
    call str_to_int
    mov r9, rax                 ; r9 = idle
    
    ; Read iowait time
    call skip_whitespace
    mov rdi, rax
    call str_to_int
    add r9, rax                 ; r9 += iowait (idle + iowait = total idle)
    
    ; Read irq time
    call skip_whitespace
    mov rdi, rax
    call str_to_int
    add r8, rax                 ; r8 += irq
    
    ; Read softirq time
    call skip_whitespace
    mov rdi, rax
    call str_to_int
    add r8, rax                 ; r8 += softirq
    
    ; Calculate total = user + nice + system + idle + iowait + irq + softirq
    mov rax, r8
    add rax, r9                 ; total = non_idle + idle
    
    ; Store values
    mov [curr_total], rax
    mov [curr_idle], r9
    
    xor rax, rax                ; success
    pop r12
    pop rbx
    pop rbp
    ret
    
.error:
    mov rax, -1
    pop r12
    pop rbx
    pop rbp
    ret

; calculate_cpu_percent - Calculate CPU usage percentage
; No arguments
; Returns: rax = CPU usage percentage (0-100)
calculate_cpu_percent:
    push rbp
    mov rbp, rsp
    
    ; total_diff = curr_total - prev_total
    mov rax, [curr_total]
    sub rax, [prev_total]
    mov rcx, rax                ; rcx = total_diff
    
    ; Check for divide by zero
    test rcx, rcx
    jz .zero_usage
    
    ; idle_diff = curr_idle - prev_idle
    mov rax, [curr_idle]
    sub rax, [prev_idle]        ; rax = idle_diff
    
    ; non_idle_diff = total_diff - idle_diff
    mov rdx, rcx
    sub rdx, rax                ; rdx = non_idle_diff
    
    ; cpu_percent = (non_idle_diff * 100) / total_diff
    mov rax, rdx
    mov rdx, 100
    imul rax, rdx               ; rax = non_idle_diff * 100
    xor rdx, rdx                ; clear rdx for division
    div rcx                     ; rax = (non_idle_diff * 100) / total_diff
    
    ; Update previous values for next iteration
    mov rcx, [curr_total]
    mov [prev_total], rcx
    mov rcx, [curr_idle]
    mov [prev_idle], rcx
    
    pop rbp
    ret
    
.zero_usage:
    xor rax, rax
    pop rbp
    ret
