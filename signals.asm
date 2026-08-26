; signals.asm - Graceful termination signal handling for Linux x86-64
; Intel syntax
default abs

%define SIGHUP  1
%define SIGINT  2
%define SIGQUIT 3
%define SIGPIPE 13
%define SIGTERM 15
%define SIGTSTP 20

%define SA_RESTORER 0x04000000
%define SYS_RT_SIGRETURN 15
%define KERNEL_SIGSET_SIZE 8

section .data
    termination_action:
        dq termination_handler
        dq SA_RESTORER
        dq signal_restorer
        dq 0                    ; empty signal mask

    suspend_action:
        dq suspend_handler
        dq SA_RESTORER
        dq signal_restorer
        dq 0                    ; empty signal mask

    default_action:
        dq 0                    ; SIG_DFL
        dq 0
        dq 0
        dq 0                    ; empty signal mask

section .bss
    exit_signal: resd 1
    suspend_signal: resd 1

section .text
extern sys_rt_sigaction
extern sys_getpid
extern sys_kill

global setup_signal_handlers
global signal_exit_requested
global signal_suspend_requested
global suspend_until_continued

; setup_signal_handlers - Arrange for common termination signals to request exit
; Returns: rax = 0 on success, -1 on error
setup_signal_handlers:
    push rbp
    mov rbp, rsp

    mov dword [exit_signal], 0
    mov dword [suspend_signal], 0

    mov rdi, SIGHUP
    mov rsi, termination_action
    call install_action
    test rax, rax
    js setup_error

    mov rdi, SIGINT
    mov rsi, termination_action
    call install_action
    test rax, rax
    js setup_error

    mov rdi, SIGQUIT
    mov rsi, termination_action
    call install_action
    test rax, rax
    js setup_error

    mov rdi, SIGPIPE
    mov rsi, termination_action
    call install_action
    test rax, rax
    js setup_error

    mov rdi, SIGTERM
    mov rsi, termination_action
    call install_action
    test rax, rax
    js setup_error

    mov rdi, SIGTSTP
    mov rsi, suspend_action
    call install_action
    test rax, rax
    js setup_error

    xor rax, rax
    pop rbp
    ret

setup_error:
    mov rax, -1
    pop rbp
    ret

install_action:
    push rbp
    mov rbp, rsp

    xor rdx, rdx                ; old action not needed
    mov r10, KERNEL_SIGSET_SIZE
    call sys_rt_sigaction

    pop rbp
    ret

; signal_exit_requested - Return the signal number requesting termination
signal_exit_requested:
    mov eax, [exit_signal]
    ret

; signal_suspend_requested - Return nonzero when SIGTSTP requested suspension
signal_suspend_requested:
    mov eax, [suspend_signal]
    ret

; suspend_until_continued - Stop with SIGTSTP after the caller has restored
; the terminal. Execution resumes here after SIGCONT, and the custom SIGTSTP
; handler is reinstalled before returning.
; Returns: rax = 0 on resume, -1 on error
suspend_until_continued:
    push rbp
    mov rbp, rsp

    ; Restore SIGTSTP's default stop action while the terminal is clean.
    mov rdi, SIGTSTP
    mov rsi, default_action
    call install_action
    test rax, rax
    js .error

    mov dword [suspend_signal], 0

    call sys_getpid
    test rax, rax
    js .restore_handler_error

    mov rdi, rax
    mov rsi, SIGTSTP
    call sys_kill                 ; returns after a later SIGCONT
    test rax, rax
    js .restore_handler_error

    mov rdi, SIGTSTP
    mov rsi, suspend_action
    call install_action
    test rax, rax
    js .error

    mov dword [suspend_signal], 0
    xor rax, rax
    pop rbp
    ret

.restore_handler_error:
    mov rdi, SIGTSTP
    mov rsi, suspend_action
    call install_action

.error:
    mov rax, -1
    pop rbp
    ret

; The handler only performs an atomic flag store. Normal control flow restores
; the terminal and display before exiting.
termination_handler:
    mov [exit_signal], edi
    ret

; Defer suspend cleanup to normal control flow.
suspend_handler:
    mov [suspend_signal], edi
    ret

; x86-64 direct rt_sigaction users must provide a restorer trampoline.
signal_restorer:
    mov rax, SYS_RT_SIGRETURN
    syscall
    ud2
