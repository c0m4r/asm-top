; display.asm - Display formatting and output functions
; Intel syntax
default abs

section .data
    ; ANSI escape sequences
    clear_screen: db 27, "[2J", 27, "[H", 0    ; Clear screen and move cursor home
    hide_cursor: db 27, "[?25l", 0              ; Hide cursor
    show_cursor: db 27, "[?25h", 0              ; Show cursor
    alt_buffer_on: db 27, "[?1049h", 0          ; Enable alternate buffer
    alt_buffer_off: db 27, "[?1049l", 0         ; Disable alternate buffer
    
    ; Display strings
    header: db "=== ASM-TOP - ", 0
    header_at: db " @ ", 0
    header_end: db " UTC ===", 10, 0
    uptime_label: db "uptime: ", 0
    load_label: db "  load: ", 0
    cpu_label: db "CPU:  [", 0
    mem_label: db "RAM:  [", 0
    swap_label: db "SWAP: [", 0
    bar_end: db "] ", 0
    percent_sign: db "%", 0
    exit_msg: db 10, "Press 'q' or Ctrl-C to exit", 10, 0
    newline: db 10, 0           ; Just a newline character
    
    bar_fill: db "#", 0
    bar_empty: db ".", 0
    space_paren: db " (", 0
    slash: db "/", 0
    paren_end: db ")", 0

section .bss
    temp_buffer: resb 64        ; Temporary buffer for number conversion
    display_error: resq 1       ; Sticky output failure for the current session

section .text
extern sys_write
extern int_to_str
extern strlen
extern get_hostname
extern get_time_string
extern get_uptime_string
extern get_load_average_string
extern get_tasks_string
extern calculate_swap_percent
extern get_mem_total_kb
extern get_mem_used_kb
extern get_swap_total_kb
extern get_swap_used_kb
extern format_size_kb

global display_init
global display_cleanup
global display_stats

; display_init - Initialize display (clear screen, hide cursor)
; No arguments
; Returns: rax = 0 on success, -1 on output error
display_init:
    push rbp
    mov rbp, rsp

    mov qword [display_error], 0
    
    ; Enable alternate buffer before clearing so the primary screen is preserved
    mov rdi, alt_buffer_on
    call print_string
    
    ; Clear the alternate screen
    mov rdi, clear_screen
    call print_string
    
    ; Hide cursor
    mov rdi, hide_cursor
    call print_string

    mov rax, [display_error]
    
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
    
    ; Disable alternate buffer (restores original screen)
    mov rdi, alt_buffer_off
    call strlen
    mov rdx, rax
    
    mov rdi, 1
    mov rsi, alt_buffer_off
    call sys_write
    
    ; Show cursor
    mov rdi, show_cursor
    call strlen
    mov rdx, rax
    
    mov rdi, 1                  ; stdout
    mov rsi, show_cursor
    call sys_write

    xor rax, rax
    
    pop rbp
    ret

; write_stdout - Write an entire buffer and remember any output failure
; Arguments:
;   rsi = buffer
;   rdx = length
; Returns: rax = 0 on success, -1 on error
write_stdout:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    cmp qword [display_error], 0
    jne .failed

    mov rbx, rsi
    mov r12, rdx

.write_loop:
    test r12, r12
    jz .success

    mov rdi, 1                  ; stdout
    mov rsi, rbx
    mov rdx, r12
    call sys_write

    test rax, rax
    jg .write_progress
    cmp rax, -4                 ; EINTR: retry after the signal handler returns
    je .write_loop
    jmp .record_error

.write_progress:
    add rbx, rax
    sub r12, rax
    jmp .write_loop

.record_error:
    mov qword [display_error], -1

.failed:
    mov rax, -1
    jmp .done

.success:
    xor rax, rax

.done:
    pop r12
    pop rbx
    pop rbp
    ret

; print_string - Print null-terminated string
; Arguments:
;   rdi = pointer to string
; Returns: rax = 0 on success, -1 on error
print_string:
    push rbx
    
    mov rbx, rdi                ; save string pointer
    call strlen
    mov rdx, rax                ; length
    
    mov rsi, rbx                ; string
    call write_stdout
    
    pop rbx
    ret

; render_bar - Render a progress bar
; Arguments:
;   rdi = percentage (0-100)
; Returns: rax = 0 on success, -1 on error
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
    cmp rax, 40
    jbe .filled_in_range
    mov rax, 40                 ; defensively clamp unexpected percentages
.filled_in_range:
    mov rbx, rax                ; rbx = filled count
    
    ; Print filled portion
    mov r12, rbx
.fill_loop:
    test r12, r12
    jz .empty_portion
    
    mov rdi, bar_fill
    call print_string
    test rax, rax
    js .error
    
    dec r12
    jmp .fill_loop
    
.empty_portion:
    ; Calculate empty portion (40 - filled)
    mov r12, 40
    sub r12, rbx
    
.empty_loop:
    test r12, r12
    jz .done
    
    mov rdi, bar_empty
    call print_string
    test rax, rax
    js .error
    
    dec r12
    jmp .empty_loop
    
.done:
    xor rax, rax
    jmp .return

.error:
    mov rax, -1

.return:
    pop r12
    pop rbx
    pop rbp
    ret

; display_stats - Display CPU and RAM statistics
; Arguments:
;   rdi = CPU percentage
;   rsi = RAM percentage
; Returns: rax = 0 on success, -1 on output error
display_stats:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
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
    
    ; Print uptime line
    mov rdi, uptime_label
    call print_string
    
    call get_uptime_string
    mov rdi, rax
    call print_string
    
    mov rdi, load_label
    call print_string
    
    call get_load_average_string
    mov rdi, rax
    call print_string
    
    ; Print newline
    mov rdi, newline
    call print_string
    
    ; Print tasks line
    call get_tasks_string
    mov rdi, rax
    call print_string
    
    ; Print newline
    mov rdi, newline
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
    
    mov rsi, rax                ; string from int_to_str
    ; rdx already has length from int_to_str
    call write_stdout
    
    ; Print percent sign
    mov rdi, percent_sign
    call print_string
    
    ; Print newline
    mov rdi, newline
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
    
    mov rsi, rax
    call write_stdout
    
    ; Print percent sign
    mov rdi, percent_sign
    call print_string
    
    ; Print RAM size details " (Used/Total)"
    mov rdi, space_paren
    call print_string
    
    call get_mem_used_kb
    mov rdi, rax                ; move result to argument
    call format_size_kb
    mov rdi, rax
    call print_string
    
    mov rdi, slash
    call print_string
    
    call get_mem_total_kb
    mov rdi, rax                ; move result to argument
    call format_size_kb
    mov rdi, rax
    call print_string
    
    mov rdi, paren_end
    call print_string
    
    ; Print newline
    mov rdi, newline
    call print_string
    
    ; Print SWAP label
    mov rdi, swap_label
    call print_string
    
    ; Calculate SWAP percentage
    call calculate_swap_percent
    mov r14, rax                ; save SWAP%
    
    ; Render SWAP bar
    mov rdi, r14
    call render_bar
    
    ; Print bar end
    mov rdi, bar_end
    call print_string
    
    ; Print SWAP percentage
    mov rdi, r14
    mov rsi, temp_buffer
    call int_to_str
    
    mov rsi, rax
    call write_stdout
    
    ; Print percent sign
    mov rdi, percent_sign
    call print_string
    
    ; Print SWAP size details " (Used/Total)"
    mov rdi, space_paren
    call print_string
    
    call get_swap_used_kb
    mov rdi, rax                ; move result to argument
    call format_size_kb
    mov rdi, rax
    call print_string
    
    mov rdi, slash
    call print_string
    
    call get_swap_total_kb
    mov rdi, rax                ; move result to argument
    call format_size_kb
    mov rdi, rax
    call print_string
    
    mov rdi, paren_end
    call print_string
    
    ; Print newline
    mov rdi, newline
    call print_string
    
    ; Print exit message
    mov rdi, exit_msg
    call print_string

    mov rax, [display_error]

    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
