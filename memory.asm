; memory.asm - Memory monitoring functions
; Intel syntax

section .data
    proc_meminfo_path: db "/proc/meminfo", 0
    memtotal_str: db "MemTotal:", 0
    memavail_str: db "MemAvailable:", 0
    swaptotal_str: db "SwapTotal:", 0
    swapfree_str: db "SwapFree:", 0

section .bss
    mem_buffer: resb 4096       ; Buffer for /proc/meminfo content
    mem_total: resq 1           ; Total memory in kB
    mem_available: resq 1       ; Available memory in kB
    mem_used: resq 1            ; Used memory in kB
    swap_total: resq 1          ; Total swap in kB
    swap_free: resq 1           ; Free swap in kB
    swap_used: resq 1           ; Used swap in kB

section .text
extern sys_open
extern sys_read
extern sys_close
extern str_to_int
extern find_char

global read_mem_info
global calculate_mem_percent
global calculate_swap_percent
global get_mem_total_kb
global get_mem_used_kb
global get_swap_total_kb
global get_swap_used_kb

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
    
    ; Calculate used memory
    mov rax, [mem_total]
    sub rax, [mem_available]
    mov [mem_used], rax
    
    ; Find SwapTotal line
    mov rdi, mem_buffer
    mov rsi, r12
    mov rdx, swaptotal_str
    call find_line
    
    test rax, rax
    jz .no_swap             ; No swap configured
    
    ; Parse SwapTotal
    mov rdi, rax
.skip_ws_swaptotal:
    movzx rcx, byte [rdi]
    cmp rcx, ' '
    je .skip_ws_swaptotal_inc
    cmp rcx, '\t'
    je .skip_ws_swaptotal_inc
    jmp .parse_swaptotal
.skip_ws_swaptotal_inc:
    inc rdi
    jmp .skip_ws_swaptotal
    
.parse_swaptotal:
    call str_to_int
    mov [swap_total], rax
    
    ; Find SwapFree line
    mov rdi, mem_buffer
    mov rsi, r12
    mov rdx, swapfree_str
    call find_line
    
    test rax, rax
    jz .no_swap
    
    ; Parse SwapFree
    mov rdi, rax
.skip_ws_swapfree:
    movzx rcx, byte [rdi]
    cmp rcx, ' '
    je .skip_ws_swapfree_inc
    cmp rcx, '\t'
    je .skip_ws_swapfree_inc
    jmp .parse_swapfree
.skip_ws_swapfree_inc:
    inc rdi
    jmp .skip_ws_swapfree
    
.parse_swapfree:
    call str_to_int
    mov [swap_free], rax
    
    ; Calculate used swap
    mov rax, [swap_total]
    sub rax, [swap_free]
    mov [swap_used], rax
    jmp .success
    
.no_swap:
    ; No swap configured
    mov qword [swap_total], 0
    mov qword [swap_free], 0
    mov qword [swap_used], 0
    
.success:
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

; calculate_swap_percent - Calculate swap usage percentage
; No arguments
; Returns: rax = swap usage percentage (0-100)
calculate_swap_percent:
    push rbp
    mov rbp, rsp
    
    mov rax, [swap_total]
    test rax, rax
    jz .zero_usage
    
    mov rax, [swap_used]
    mov rdx, 100
    imul rax, rdx
    xor rdx, rdx
    mov rcx, [swap_total]
    div rcx
    
    pop rbp
    ret
    
.zero_usage:
    xor rax, rax
    pop rbp
    ret

; get_mem_total_kb
get_mem_total_kb:
    mov rax, [mem_total]
    ret

; get_mem_used_kb
get_mem_used_kb:
    mov rax, [mem_used]
    ret

; get_swap_total_kb
get_swap_total_kb:
    mov rax, [swap_total]
    ret

; get_swap_used_kb
get_swap_used_kb:
    mov rax, [swap_used]
    ret