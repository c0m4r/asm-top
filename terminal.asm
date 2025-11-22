; terminal.asm - Terminal mode control (raw mode for immediate input)
; Intel syntax

section .data
    ; TCGETS/TCSETS ioctl request codes
    TCGETS equ 0x5401
    TCSETS equ 0x5402
    
    ; termios flags
    ICANON equ 0000002    ; Canonical mode
    ECHO equ 0000010      ; Echo input characters

section .bss
    ; termios structure (60 bytes on Linux)
    orig_termios: resb 60
    new_termios: resb 60

section .text
extern sys_ioctl

global terminal_raw_mode
global terminal_restore

; terminal_raw_mode - Set terminal to raw mode (non-canonical, no echo)
; No arguments
; Returns: rax = 0 on success, -1 on error
terminal_raw_mode:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    
    ; Get current terminal attributes
    xor rdi, rdi                ; stdin (fd 0)
    mov rsi, TCGETS
    mov rdx, orig_termios
    call sys_ioctl
    
    cmp rax, 0
    jl .error
    
    ; Copy original to new
    mov rcx, 60
    mov rsi, orig_termios
    mov rdi, new_termios
    rep movsb
    
    ; Modify flags: disable ICANON and ECHO
    ; c_lflag is at offset 12 in termios struct
    mov eax, [new_termios + 12]
    mov ebx, ICANON
    or ebx, ECHO
    not ebx
    and eax, ebx
    mov [new_termios + 12], eax
    
    ; Set minimum characters for read to 0
    ; c_cc[VMIN] at offset 17
    mov byte [new_termios + 17], 0
    
    ; Set timeout for read to 0
    ; c_cc[VTIME] at offset 18
    mov byte [new_termios + 18], 0
    
    ; Apply new terminal attributes
    xor rdi, rdi                ; stdin
    mov rsi, TCSETS
    mov rdx, new_termios
    call sys_ioctl
    
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

; terminal_restore - Restore original terminal attributes
; No arguments
; Returns: rax = 0 on success, -1 on error
terminal_restore:
    push rbp
    mov rbp, rsp
    
    ; Restore original terminal attributes
    xor rdi, rdi                ; stdin
    mov rsi, TCSETS
    mov rdx, orig_termios
    call sys_ioctl
    
    pop rbp
    ret
