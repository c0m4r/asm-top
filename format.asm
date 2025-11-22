; format.asm - Formatting utilities for sizes
; Intel syntax

section .data
    kb_str: db " KB", 0
    mb_str: db " MB", 0
    gb_str: db " GB", 0
    slash_str: db "/", 0

section .bss
    size_buffer: resb 32        ; Buffer for formatted size

section .text
extern int_to_str

global format_size_kb

; format_size_kb - Format KB value as MB or GB if appropriate
; Arguments:
;   rdi = size in KB
; Returns:
;   rax = pointer to formatted string (e.g., "1234 MB" or "2 GB")
format_size_kb:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    
    mov r12, rdi                ; save original size
    
    ; Check if >= 1GB (1048576 KB)
    cmp rdi, 1048576
    jge .format_gb
    
    ; Check if >= 1MB (1024 KB)
    cmp rdi, 1024
    jge .format_mb
    
    ; Format as KB
    mov rsi, size_buffer
    call int_to_str
    mov r13, rax                ; save string pointer
    
    ; Append " KB"
    mov rsi, rax
    add rsi, rdx
    mov rdi, kb_str
    call append_string
    
    mov rax, r13                ; return string pointer
    pop r12
    pop rbx
    pop rbp
    ret
    
.format_mb:
    ; Convert to MB (divide by 1024)
    mov rax, r12
    xor rdx, rdx
    mov rcx, 1024
    div rcx                     ; rax = MB
    
    mov rdi, rax
    mov rsi, size_buffer
    call int_to_str
    mov r13, rax                ; save string pointer
    
    ; Append " MB"
    mov rsi, rax
    add rsi, rdx
    mov rdi, mb_str
    call append_string
    
    mov rax, r13                ; return string pointer
    pop r12
    pop rbx
    pop rbp
    ret
    
.format_gb:
    ; Convert to GB (divide by 1048576)
    mov rax, r12
    xor rdx, rdx
    mov rcx, 1048576
    div rcx                     ; rax = GB
    
    mov rdi, rax
    mov rsi, size_buffer
    call int_to_str
    mov r13, rax                ; save string pointer
    
    ; Append " GB"
    mov rsi, rax
    add rsi, rdx
    mov rdi, gb_str
    call append_string
    
    mov rax, r13                ; return string pointer
    pop r12
    pop rbx
    pop rbp
    ret

; append_string - Helper to append string
; Arguments:
;   rsi = destination (where to append)
;   rdi = source string to append
append_string:
    push rbp
    mov rbp, rsp
    
.loop:
    movzx rax, byte [rdi]
    test al, al
    jz .done
    mov [rsi], al
    inc rsi
    inc rdi
    jmp .loop
    
.done:
    mov byte [rsi], 0
    pop rbp
    ret
