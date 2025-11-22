; display.asm - Display formatting and output functions
; Intel syntax

section .data
    ; ANSI escape sequences
    clear_screen: db 27, "[2J", 27, "[H", 0    ; Clear screen and move cursor home
    hide_cursor: db 27, "[?25l", 0              ; Hide cursor
    show_cursor: db 27, "[?25h", 0              ; Show cursor
    
    ; Display strings
    header: db "=== ASM-TOP - ", 0
    header_at: db " @ ", 0
    header_end: db " ===", 10, 0
    cpu_label: db "CPU:  [", 0
    mem_label: db "RAM:  [", 0
    bar_end: db "] ", 0
    percent_sign: db "%", 10, 0
    exit_msg: db 10, "Press 'q' or Ctrl+C to exit", 10, 0
    newline: db 10, 0           ; Just a newline character
    
    bar_fill: db "#", 0
    bar_empty: db ".", 0

section .bss
    temp_buffer: resb 64        ; Temporary buffer for number conversion

section .text
extern sys_write
extern int_to_str
extern strlen
extern get_hostname
extern get_time_string

global display_init
global display_cleanup
global display_stats

; display_init - Initialize display (clear screen, hide cursor)
; No arguments
display_init:
    push rbp
    mov rbp, rsp
    
    ; Clear screen
    mov rdi, clear_screen
    call strlen
    mov rdx, rax
    
    mov rdi, 1                  ; stdout
    mov rsi, clear_screen
    call sys_write
    
    ; Hide cursor
    mov rdi, hide_cursor
    call strlen
    mov rdx, rax
    
    mov rdi, 1
    mov rsi, hide_cursor
    call sys_write
    
    pop rbp
    ret

; display_cleanup - Cleanup display (show cursor)
; No arguments
display_cleanup:
    push rbp
    mov rbp, rsp
    
    ; Print newline to move cursor down
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    call sys_write
    
    ; Show cursor
    mov rdi, show_cursor
    call strlen
    mov rdx, rax
    
    mov rdi, 1                  ; stdout
    mov rsi, show_cursor
    call sys_write
    
    pop rbp
    ret

; print_string - Print null-terminated string
; Arguments:
;   rdi = pointer to string
; No return value
print_string:
    push rbp
    mov rbp, rsp
    push rbx
    
    mov rbx, rdi                ; save string pointer
    call strlen
    mov rdx, rax                ; length
    
    mov rdi, 1                  ; stdout
    mov rsi, rbx                ; string
    call sys_write
    
    pop rbx
    pop rbp
    ret

; render_bar - Render a progress bar
; Arguments:
;   rdi = percentage (0-100)
; No return value
render_bar:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    
    mov r12, rdi                ; save percentage
    
    ; Calculate filled portion (percentage * 40 / 100)
    mov rax, rdi
    mov rcx, 40
    imul rax, rcx
    mov rcx, 100
    xor rdx, rdx
    div rcx                     ; rax = filled count
    mov rbx, rax                ; rbx = filled count
    
    ; Print filled portion
    mov rcx, rbx
.fill_loop:
    test rcx, rcx
    jz .empty_portion
    push rcx
    
    mov rdi, bar_fill
    call print_string
    
    pop rcx
    dec rcx
    jmp .fill_loop
    
.empty_portion:
    ; Calculate empty portion (40 - filled)
    mov rcx, 40
    sub rcx, rbx
    
.empty_loop:
    test rcx, rcx
    jz .done
    push rcx
    
    mov rdi, bar_empty
    call print_string
    
    pop rcx
    dec rcx
    jmp .empty_loop
    
.done:
    pop r12
    pop rbx
    pop rbp
    ret

; display_stats - Display CPU and RAM statistics
; Arguments:
;   rdi = CPU percentage
;   rsi = RAM percentage
; No return value
display_stats:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    
    mov r12, rdi                ; save CPU%
    mov r13, rsi                ; save RAM%
    
    ; Clear screen and move to home
    mov rdi, clear_screen
    call print_string
    
    ; Print header start
    mov rdi, header
    call print_string
    
    ; Print hostname
    call get_hostname
    mov rdi, rax
    call print_string
    
    ; Print " @ "
    mov rdi, header_at
    call print_string
    
    ; Print current time
    call get_time_string
    mov rdi, rax
    call print_string
    
    ; Print header end
    mov rdi, header_end
    call print_string
    
    ; Print CPU label
    mov rdi, cpu_label
    call print_string
    
    ; Render CPU bar
    mov rdi, r12
    call render_bar
    
    ; Print bar end
    mov rdi, bar_end
    call print_string
    
    ; Print CPU percentage
    mov rdi, r12
    mov rsi, temp_buffer
    call int_to_str
    
    mov rdi, 1                  ; stdout
    mov rsi, rax                ; string from int_to_str
    ; rdx already has length from int_to_str
    push rax
    push rdx
    call sys_write
    pop rdx
    pop rax
    
    ; Print percent sign and newline
    mov rdi, percent_sign
    call print_string
    
    ; Print RAM label
    mov rdi, mem_label
    call print_string
    
    ; Render RAM bar
    mov rdi, r13
    call render_bar
    
    ; Print bar end
    mov rdi, bar_end
    call print_string
    
    ; Print RAM percentage
    mov rdi, r13
    mov rsi, temp_buffer
    call int_to_str
    
    mov rdi, 1                  ; stdout
    mov rsi, rax
    push rax
    push rdx
    call sys_write
    pop rdx
    pop rax
    
    ; Print percent sign and newline
    mov rdi, percent_sign
    call print_string
    
    ; Print exit message
    mov rdi, exit_msg
    call print_string
    
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
