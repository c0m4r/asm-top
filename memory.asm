; memory.asm - Memory monitoring functions
; Intel syntax

section .data
    proc_meminfo_path: db "/proc/meminfo", 0
    memtotal_str: db "MemTotal:", 0
    memavail_str: db "MemAvailable:", 0

section .bss
    mem_buffer: resb 4096       ; Buffer for /proc/meminfo content
    mem_total: resq 1           ; Total memory in kB
    mem_available: resq 1       ; Available memory in kB

section .text
extern sys_open
extern sys_read
extern sys_close
extern str_to_int
extern find_char

global read_mem_info
global calculate_mem_percent

; find_line - Find line starting with given prefix
; Arguments:
;   rdi = buffer start
;   rsi = buffer size
;   rdx = prefix string
; Returns:
;   rax = pointer to line (or 0 if not found)
find_line:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
    mov r12, rdi                ; buffer start
    mov r13, rsi                ; buffer size
    mov r14, rdx                ; prefix
    
.next_line:
    ; Check if we're past the buffer
    mov rax, r12
    sub rax, rdi
    cmp rax, r13
    jge .not_found
    
    ; Compare prefix
    mov rbx, r12                ; current line
    mov rcx, r14                ; prefix
    
.compare_loop:
    movzx eax, byte [rcx]
    test al, al
    jz .found                   ; end of prefix, match!
    
    movzx edx, byte [rbx]
    cmp al, dl
    jne .skip_line              ; no match, try next line
    
    inc rbx
    inc rcx
    jmp .compare_loop
    
.found:
    mov rax, rbx                ; return pointer after prefix
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
    
.skip_line:
    ; Find next newline
    mov rdi, r12
    mov sil, 10                 ; '\n'
    mov rdx, r13
    call find_char
    
    test rax, rax
    jz .not_found
    
    inc rax                     ; skip the newline
    mov r12, rax
    jmp .next_line
    
.not_found:
    xor rax, rax
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; read_mem_info - Read and parse /proc/meminfo
; No arguments
; Returns: rax = 0 on success, -1 on error
read_mem_info:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    
    ; Open /proc/meminfo
    mov rdi, proc_meminfo_path
    xor rsi, rsi                ; O_RDONLY = 0
    xor rdx, rdx
    call sys_open
    
    cmp rax, 0
    jl .error                   ; if fd < 0, error
    mov rbx, rax                ; save fd
    
    ; Read file
    mov rdi, rbx
    mov rsi, mem_buffer
    mov rdx, 4096
    call sys_read
    
    mov r12, rax                ; save bytes read
    
    ; Close file
    mov rdi, rbx
    call sys_close
    
    ; Check if we read anything
    cmp r12, 0
    jle .error
    
    ; Find MemTotal line
    mov rdi, mem_buffer
    mov rsi, r12
    mov rdx, memtotal_str
    call find_line
    
    test rax, rax
    jz .error
    
    ; Skip whitespace and parse number
    mov rdi, rax
.skip_ws_total:
    movzx rcx, byte [rdi]
    cmp rcx, ' '
    je .skip_ws_total_inc
    cmp rcx, '\t'
    je .skip_ws_total_inc
    jmp .parse_total
.skip_ws_total_inc:
    inc rdi
    jmp .skip_ws_total
    
.parse_total:
    call str_to_int
    mov [mem_total], rax
    
    ; Find MemAvailable line
    mov rdi, mem_buffer
    mov rsi, r12
    mov rdx, memavail_str
    call find_line
    
    test rax, rax
    jz .error
    
    ; Skip whitespace and parse number
    mov rdi, rax
.skip_ws_avail:
    movzx rcx, byte [rdi]
    cmp rcx, ' '
    je .skip_ws_avail_inc
    cmp rcx, '\t'
    je .skip_ws_avail_inc
    jmp .parse_avail
.skip_ws_avail_inc:
    inc rdi
    jmp .skip_ws_avail
    
.parse_avail:
    call str_to_int
    mov [mem_available], rax
    
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

; calculate_mem_percent - Calculate memory usage percentage
; No arguments
; Returns: rax = memory usage percentage (0-100)
calculate_mem_percent:
    push rbp
    mov rbp, rsp
    
    ; used = total - available
    mov rax, [mem_total]
    sub rax, [mem_available]    ; rax = used
    
    ; percent = (used * 100) / total
    mov rdx, 100
    imul rax, rdx               ; rax = used * 100
    
    xor rdx, rdx                ; clear for division
    mov rcx, [mem_total]
    
    ; Check for divide by zero
    test rcx, rcx
    jz .zero_usage
    
    div rcx                     ; rax = (used * 100) / total
    
    pop rbp
    ret
    
.zero_usage:
    xor rax, rax
    pop rbp
    ret
