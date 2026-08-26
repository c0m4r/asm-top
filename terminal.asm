; terminal.asm - Terminal mode control (raw mode for immediate input)
; Intel syntax
default abs

section .data
    ; TCGETS/TCSETS ioctl request codes
    TCGETS equ 0x5401
    TCSETS equ 0x5402
    
    ; Linux x86-64 kernel termios layout and flags
    KERNEL_TERMIOS_SIZE equ 36
    C_LFLAG_OFFSET equ 12
    C_CC_OFFSET equ 17
    VTIME equ 5
    VMIN equ 6
    ICANON equ 0000002          ; Canonical mode
    ECHO equ 0000010            ; Echo input characters

section .bss
    ; Kernel termios structures used directly by TCGETS/TCSETS
    orig_termios: resb KERNEL_TERMIOS_SIZE
    new_termios: resb KERNEL_TERMIOS_SIZE
    terminal_active: resb 1

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

    mov byte [terminal_active], 0
    
    ; Get current terminal attributes
    xor rdi, rdi                ; stdin (fd 0)
    mov rsi, TCGETS
    mov rdx, orig_termios
    call sys_ioctl
    
    cmp rax, 0
    jl .error
    
    ; Copy original to new
    mov rcx, KERNEL_TERMIOS_SIZE
    mov rsi, orig_termios
    mov rdi, new_termios
    rep movsb
    
    ; Modify flags: disable ICANON and ECHO
    ; c_lflag is at offset 12 in the kernel termios structure
    mov eax, [new_termios + C_LFLAG_OFFSET]
    mov ebx, ICANON
    or ebx, ECHO
    not ebx
    and eax, ebx
    mov [new_termios + C_LFLAG_OFFSET], eax
    
    ; Set minimum characters for read to 0
    ; c_cc starts at offset 17; VMIN is c_cc[6]
    mov byte [new_termios + C_CC_OFFSET + VMIN], 0
    
    ; Set timeout for read to 0
    ; VTIME is c_cc[5]
    mov byte [new_termios + C_CC_OFFSET + VTIME], 0
    
    ; Apply new terminal attributes
    xor rdi, rdi                ; stdin
    mov rsi, TCSETS
    mov rdx, new_termios
    call sys_ioctl

    cmp rax, 0
    jl .error

    mov byte [terminal_active], 1
    xor rax, rax
    
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

    cmp byte [terminal_active], 0
    je .not_active
    
    ; Restore original terminal attributes
    xor rdi, rdi                ; stdin
    mov rsi, TCSETS
    mov rdx, orig_termios
    call sys_ioctl

    cmp rax, 0
    jl .done
    mov byte [terminal_active], 0

.done:
    pop rbp
    ret

.not_active:
    xor rax, rax
    
    pop rbp
    ret
