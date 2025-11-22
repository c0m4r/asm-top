; sysinfo.asm - System information (hostname, time)
; Intel syntax

section .data
    ; Month names (3 chars each)
    months: db "JanFebMarAprMayJunJulAugSepOctNovDec"
    hostname_path: db "/proc/sys/kernel/hostname", 0
    
section .bss
    hostname_buf: resb 256      ; Hostname buffer
    time_value: resq 1          ; Unix timestamp
    time_str_buf: resb 64       ; Buffer for formatted time string

section .text
extern sys_gethostname
extern sys_open
extern sys_read
extern sys_close
extern sys_time
extern int_to_str

global get_hostname
global get_time_string

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
