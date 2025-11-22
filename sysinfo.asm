; sysinfo.asm - System information (hostname, time)
; Intel syntax

section .data
    ; Month names (3 chars each)
    months: db "JanFebMarAprMayJunJulAugSepOctNovDec"
    hostname_path: db "/proc/sys/kernel/hostname", 0
    uptime_path: db "/proc/uptime", 0
    loadavg_path: db "/proc/loadavg", 0
    
section .bss
    hostname_buf: resb 256      ; Hostname buffer
    time_value: resq 1          ; Unix timestamp
    time_str_buf: resb 64       ; Buffer for formatted time string
    uptime_buf: resb 128        ; Buffer for uptime file
    loadavg_buf: resb 128       ; Buffer for loadavg file
    uptime_seconds: resq 1      ; Uptime in seconds
    uptime_str_buf: resb 64     ; Formatted uptime string
    load_str_buf: resb 64       ; Formatted load average string
    temp_buffer: resb 32        ; Temporary buffer for int_to_str

section .text
extern sys_gethostname
extern sys_open
extern sys_read
extern sys_close
extern sys_time
extern int_to_str
extern str_to_int

global get_hostname
global get_time_string
global get_uptime_string
global get_load_average_string

; get_hostname - Get system hostname
; No arguments
; Returns: rax = pointer to hostname string (null-terminated)
get_hostname:
    push rbp
    mov rbp, rsp
    push rbx
    
    ; Open /proc/sys/kernel/hostname
    mov rdi, hostname_path
    xor rsi, rsi                ; O_RDONLY
    xor rdx, rdx
    call sys_open
    
    cmp rax, 0
    jl .error
    mov rbx, rax                ; save fd
    
    ; Read hostname
    mov rdi, rbx
    mov rsi, hostname_buf
    mov rdx, 255
    call sys_read
    
    ; Close file
    push rax                    ; save bytes read
    mov rdi, rbx
    call sys_close
    pop rax
    
    cmp rax, 0
    jle .error
    
    ; Remove trailing newline if present
    dec rax                     ; point to last character read
    cmp byte [hostname_buf + rax], 10  ; check for newline
    jne .no_newline
    mov byte [hostname_buf + rax], 0   ; replace with null
    jmp .done
    
.no_newline:
    inc rax
    mov byte [hostname_buf + rax], 0   ; null terminate
    
.done:
    mov rax, hostname_buf
    pop rbx
    pop rbp
    ret
    
.error:
    ; Return empty string on error
    mov byte [hostname_buf], 0
    mov rax, hostname_buf
    pop rbx
    pop rbp
    ret

; get_time_string - Get formatted time string
; No arguments
; Returns: rax = pointer to time string "HH:MM:SS"
get_time_string:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    ; Get current time
    xor rdi, rdi
    call sys_time
    mov [time_value], rax
    
    ; Extract hours, minutes, seconds
    mov rax, [time_value]
    
    ; Calculate seconds in current day: timestamp % 86400
    mov rcx, 86400
    xor rdx, rdx
    div rcx                     ; rax = days, rdx = seconds today
    
    mov r12, rdx                ; r12 = seconds today
    
    ; Calculate hours: seconds_today / 3600
    mov rax, r12
    mov rcx, 3600
    xor rdx, rdx
    div rcx                     ; rax = hours, rdx = remaining seconds
    mov r13, rax                ; r13 = hours
    mov r12, rdx                ; r12 = remaining seconds
    
    ; Calculate minutes: remaining_seconds / 60
    mov rax, r12
    mov rcx, 60
    xor rdx, rdx
    div rcx                     ; rax = minutes, rdx = seconds
    mov r14, rax                ; r14 = minutes
    mov r15, rdx                ; r15 = seconds
    
    ; Format time string manually: "HH:MM:SS"
    mov rdi, time_str_buf
    
    ; Hours (2 digits with zero padding)
    mov rax, r13
    xor rdx, rdx
    mov rcx, 10
    div rcx                     ; rax = tens, rdx = ones
    add al, '0'
    mov [rdi], al
    inc rdi
    add dl, '0'
    mov [rdi], dl
    inc rdi
    
    ; Colon
    mov byte [rdi], ':'
    inc rdi
    
    ; Minutes (2 digits with zero padding)
    mov rax, r14
    xor rdx, rdx
    mov rcx, 10
    div rcx                     ; rax = tens, rdx = ones
    add al, '0'
    mov [rdi], al
    inc rdi
    add dl, '0'
    mov [rdi], dl
    inc rdi
    
    ; Colon
    mov byte [rdi], ':'
    inc rdi
    
    ; Seconds (2 digits with zero padding)
    mov rax, r15
    xor rdx, rdx
    mov rcx, 10
    div rcx                     ; rax = tens, rdx = ones
    add al, '0'
    mov [rdi], al
    inc rdi
    add dl, '0'
    mov [rdi], dl
    inc rdi
    
    ; Null terminate
    mov byte [rdi], 0
    
    ; Return pointer to string
    mov rax, time_str_buf
    
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; get_uptime_string - Get formatted uptime string
; No arguments
; Returns: rax = pointer to uptime string "Xd Xh Xm" or "Xh Xm" or "Xm"
get_uptime_string:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
    ; Open /proc/uptime
    mov rdi, uptime_path
    xor rsi, rsi
    xor rdx, rdx
    call sys_open
    
    cmp rax, 0
    jl .error
    mov rbx, rax
    
    ; Read uptime
    mov rdi, rbx
    mov rsi, uptime_buf
    mov rdx, 127
    call sys_read
    
    push rax
    mov rdi, rbx
    call sys_close
    pop rax
    
    cmp rax, 0
    jle .error
    
    ; Parse first number (uptime in seconds)
    mov rdi, uptime_buf
    call str_to_int
    mov [uptime_seconds], rax
    
    ; Format uptime as days, hours, minutes
    mov rax, [uptime_seconds]
    
    ; Calculate days
    mov rcx, 86400
    xor rdx, rdx
    div rcx             ; rax = days, rdx = remaining
    mov r12, rax        ; r12 = days
    mov rax, rdx        ; rax = remaining seconds
    
    ; Calculate hours
    mov rcx, 3600
    xor rdx, rdx
    div rcx             ; rax = hours, rdx = remaining
    mov r13, rax        ; r13 = hours
    mov rax, rdx
    
    ; Calculate minutes
    mov rcx, 60
    xor rdx, rdx
    div rcx             ; rax = minutes
    mov r14, rax        ; r14 = minutes
    
    ; Format string
    mov rdi, uptime_str_buf
    
    ; If days > 0, show days
    test r12, r12
    jz .no_days
    
    ; Days
    mov r8, rdi                 ; save buffer position
    mov rsi, temp_buffer        ; use temporary buffer
    mov rdi, r12
    call int_to_str             ; rax = string, rdx = length
    
    ; Copy result to output
    mov rsi, rax
    mov rdi, r8
    mov rcx, rdx
.copy_days:
    test rcx, rcx
    jz .days_done
    movsb
    dec rcx
    jmp .copy_days
.days_done:
    mov byte [rdi], 'd'
    inc rdi
    mov byte [rdi], ' '
    inc rdi
    
.no_days:
    ; Hours (show if > 0 or if we showed days)
    test r13, r13
    jnz .show_hours
    test r12, r12
    jz .no_hours
    
.show_hours:
    mov r8, rdi                 ; save buffer position
    mov rsi, temp_buffer
    mov rdi, r13
    call int_to_str
    
    ; Copy result
    mov rsi, rax
    mov rdi, r8
    mov rcx, rdx
.copy_hours:
    test rcx, rcx
    jz .hours_done
    movsb
    dec rcx
    jmp .copy_hours
.hours_done:
    mov byte [rdi], 'h'
    inc rdi
    mov byte [rdi], ' '
    inc rdi
    
.no_hours:
    ; Minutes
    mov r8, rdi                 ; save buffer position
    mov rsi, temp_buffer
    mov rdi, r14
    call int_to_str
    
    ; Copy result
    mov rsi, rax
    mov rdi, r8
    mov rcx, rdx
.copy_mins:
    test rcx, rcx
    jz .mins_done
    movsb
    dec rcx
    jmp .copy_mins
.mins_done:
    mov byte [rdi], 'm'
    inc rdi
    mov byte [rdi], 0
    
    mov rax, uptime_str_buf
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
    
.error:
    mov byte [uptime_str_buf], '?'
    mov byte [uptime_str_buf + 1], 0
    mov rax, uptime_str_buf
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; get_load_average_string - Get formatted load average string
; No arguments  
; Returns: rax = pointer to load string "X.XX X.XX X.XX"
get_load_average_string:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    
    ; Open /proc/loadavg
    mov rdi, loadavg_path
    xor rsi, rsi
    xor rdx, rdx
    call sys_open
    
    cmp rax, 0
    jl .error
    mov rbx, rax
    
    ; Read loadavg
    mov rdi, rbx
    mov rsi, loadavg_buf
    mov rdx, 127
    call sys_read
    
    push rax
    mov rdi, rbx
    call sys_close
    pop rax
    
    cmp rax, 0
    jle .error
    
    ; Null terminate
    mov byte [loadavg_buf + rax], 0
    
    ; The file contains: "1.68 1.54 1.65 2/1696 546110"
    ; We need to copy first 3 numbers only
    mov rsi, loadavg_buf
    mov rdi, load_str_buf
    xor r12, r12                ; space counter
    
.copy_loop:
    movzx rax, byte [rsi]
    
    ; Stop at newline or null
    cmp al, 10
    je .done_copy
    test al, al
    jz .done_copy
    
    ; Copy the character
    mov [rdi], al
    inc rsi
    inc rdi
    
    ; Count spaces
    cmp al, ' '
    jne .copy_loop
    inc r12
    
    ; Stop after we've seen 2 spaces (which means 3 numbers copied)
    cmp r12, 2
    jge .done_copy
    jmp .copy_loop
    
.done_copy:
    ; Terminate string
    mov byte [rdi], 0
    mov rax, load_str_buf
    pop r12
    pop rbx
    pop rbp
    ret
    
.error:
    mov byte [load_str_buf], '?'
    mov byte [load_str_buf + 1], 0
    mov rax, load_str_buf
    pop r12
    pop rbx
    pop rbp
    ret
