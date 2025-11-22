; input.asm - Keyboard input handling with non-blocking poll
; Intel syntax

section .bss
    pollfd_struct:
        poll_fd: resd 1         ; fd
        poll_events: resw 1     ; events
        poll_revents: resw 1    ; returned events
    input_char: resb 1          ; buffer for single character

section .text
extern sys_poll
extern sys_read

global check_input

; Constants for poll
%define POLLIN 0x0001           ; Data available to read

; check_input - Check for keyboard input without blocking
; No arguments
; Returns: rax = character code (or 0 if no input, -1 to quit)
check_input:
    push rbp
    mov rbp, rsp
    push rbx
    
    xor rbx, rbx                ; rbx = 0 (default return value)

.loop:
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
    
    jmp .loop                   ; Check for more input

.set_quit:
    mov rbx, -1                 ; signal to quit
    jmp .loop                   ; Continue draining buffer

.done:
    mov rax, rbx
    pop rbx
    pop rbp
    ret
