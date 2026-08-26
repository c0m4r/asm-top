; input.asm - Keyboard input handling with non-blocking poll
; Intel syntax
default abs

section .bss
    pollfd_struct:
        poll_fd: resd 1         ; fd
        poll_events: resw 1     ; events
        poll_revents: resw 1    ; returned events
    input_char: resb 1          ; buffer for single character

section .text
extern sys_poll
extern sys_read
extern signal_exit_requested
extern signal_suspend_requested

global check_input

; Constants for poll
%define POLLIN 0x0001           ; Data available to read
%define MAX_INPUT_BYTES 64      ; Bound work per main-loop iteration

; check_input - Check for keyboard input without blocking
; No arguments
; Returns: rax = 0 to continue, -1 to quit, -2 to suspend
check_input:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    
    xor rbx, rbx                ; rbx = 0 (default return value)
    mov r12, MAX_INPUT_BYTES

.loop:
    ; Signals only set a flag; perform cleanup from the normal control flow
    call signal_exit_requested
    test rax, rax
    jnz .set_quit

    call signal_suspend_requested
    test rax, rax
    jnz .set_suspend

    ; Set up pollfd structure
    mov dword [poll_fd], 0      ; stdin (fd 0)
    mov word [poll_events], POLLIN
    mov word [poll_revents], 0
    
    ; Poll with 0 timeout (non-blocking)
    mov rdi, pollfd_struct
    mov rsi, 1                  ; 1 fd
    xor rdx, rdx                ; 0 ms timeout
    call sys_poll
    
    ; Check if poll returned any events
    cmp rax, 0
    jle .done                   ; no more input
    
    ; Check if POLLIN is set
    movzx rax, word [poll_revents]
    test rax, POLLIN
    jz .done
    
    ; Read one character
    xor rdi, rdi                ; stdin
    mov rsi, input_char
    mov rdx, 1                  ; read 1 byte
    call sys_read
    
    cmp rax, 0
    jle .done
    
    ; Check if it's 'q' or 'Q'
    movzx rax, byte [input_char]
    cmp al, 'q'
    je .set_quit
    cmp al, 'Q'
    je .set_quit
    
    dec r12
    jnz .loop                   ; Drain a bounded amount of queued input
    jmp .done

.set_quit:
    mov rbx, -1                 ; signal to quit
    jmp .done

.set_suspend:
    mov rbx, -2                 ; suspend after restoring terminal state

.done:
    mov rax, rbx
    pop r12
    pop rbx
    pop rbp
    ret
