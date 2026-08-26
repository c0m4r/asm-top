; syscalls.asm - Low-level system call wrappers for Linux x86-64
; Intel syntax
default abs

section .text
global sys_open
global sys_read
global sys_write
global sys_close
global sys_nanosleep
global sys_exit
global sys_poll
global sys_ioctl
global sys_rt_sigaction
global sys_getpid
global sys_kill
global sys_time

; sys_open - Open a file
; Arguments:
;   rdi = filename (null-terminated string)
;   rsi = flags (O_RDONLY = 0)
;   rdx = mode (not used for reading)
; Returns: file descriptor in rax (-1 on error)
sys_open:
    mov rax, 2              ; syscall number for open
    syscall
    ret

; sys_read - Read from file descriptor
; Arguments:
;   rdi = file descriptor
;   rsi = buffer address
;   rdx = count (number of bytes to read)
; Returns: number of bytes read in rax (-1 on error)
sys_read:
    mov rax, 0              ; syscall number for read
    syscall
    ret

; sys_write - Write to file descriptor
; Arguments:
;   rdi = file descriptor (1 for stdout)
;   rsi = buffer address
;   rdx = count (number of bytes to write)
; Returns: number of bytes written in rax (-1 on error)
sys_write:
    mov rax, 1              ; syscall number for write
    syscall
    ret

; sys_close - Close file descriptor
; Arguments:
;   rdi = file descriptor
; Returns: 0 on success, -1 on error
sys_close:
    mov rax, 3              ; syscall number for close
    syscall
    ret

; sys_nanosleep - Sleep for specified time
; Arguments:
;   rdi = pointer to timespec struct {tv_sec, tv_nsec}
;   rsi = pointer to remaining time (can be NULL/0)
; Returns: 0 on success, -1 on error
sys_nanosleep:
    mov rax, 35             ; syscall number for nanosleep
    syscall
    ret

; sys_exit - Exit the program
; Arguments:
;   rdi = exit code
; Does not return
sys_exit:
    mov rax, 60             ; syscall number for exit
    syscall
    ret                     ; should never reach here

; sys_poll - Poll file descriptors for events
; Arguments:
;   rdi = pointer to pollfd struct array
;   rsi = number of fds
;   rdx = timeout in milliseconds
; Returns: number of fds with events, 0 on timeout, -1 on error
sys_poll:
    mov rax, 7              ; syscall number for poll
    syscall
    ret

; sys_ioctl - I/O control operations
; Arguments:
;   rdi = file descriptor
;   rsi = request code
;   rdx = argument (pointer)
; Returns: 0 on success, -1 on error
sys_ioctl:
    mov rax, 16             ; syscall number for ioctl
    syscall
    ret

; sys_rt_sigaction - Install or query a signal action
; Arguments:
;   rdi = signal number
;   rsi = pointer to new action (or NULL)
;   rdx = pointer to old action (or NULL)
;   r10 = kernel signal-set size (8 on x86-64)
; Returns: 0 on success, negative errno on error
sys_rt_sigaction:
    mov rax, 13             ; syscall number for rt_sigaction
    syscall
    ret

; sys_getpid - Get the current process ID
; Returns: process ID in rax
sys_getpid:
    mov rax, 39             ; syscall number for getpid
    syscall
    ret

; sys_kill - Send a signal to a process
; Arguments:
;   rdi = process ID
;   rsi = signal number
; Returns: 0 on success, negative errno on error
sys_kill:
    mov rax, 62             ; syscall number for kill
    syscall
    ret

; sys_time - Get current time
; Arguments:
;   rdi = pointer to time_t (can be NULL/0)
; Returns: current time in seconds since epoch
sys_time:
    mov rax, 201            ; syscall number for time
    syscall
    ret
