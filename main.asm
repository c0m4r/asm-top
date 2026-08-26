; main.asm - Main program entry point
; Intel syntax
default abs

section .data
    sleep_time:
        dq 0                    ; 0 seconds
        dq 100000000            ; 100 milliseconds (100,000,000 nanoseconds)

section .text
extern sys_nanosleep
extern sys_exit
extern display_init
extern display_cleanup
extern display_stats
extern init_cpu
extern read_cpu_stat
extern calculate_cpu_percent
extern read_mem_info
extern calculate_mem_percent
extern check_input
extern terminal_raw_mode
extern terminal_restore
extern setup_signal_handlers
extern signal_exit_requested
extern suspend_until_continued

global _start

_start:
    ; Arrange for termination signals to request a clean exit
    call setup_signal_handlers
    test rax, rax
    js exit_program_init_error

    ; Set terminal to raw mode for immediate input
    call terminal_raw_mode
    test rax, rax
    js exit_program_init_error
    
    ; Initialize display
    call display_init
    test rax, rax
    js exit_program_error
    
    ; Initialize CPU monitoring (first reading)
    call init_cpu
    test rax, rax
    js exit_program_error
    
main_loop:
    ; Check for keyboard input (non-blocking)
    call check_input
    cmp rax, -1                 ; -1 means quit ('q' pressed)
    je exit_program
    cmp rax, -2                 ; -2 means suspend requested
    je suspend_program
    
    ; Read CPU stats
    call read_cpu_stat
    cmp rax, 0
    jl exit_program_error       ; error, exit
    
    ; Calculate CPU percentage
    call calculate_cpu_percent
    mov r13, rax                ; save CPU%
    
    ; Read memory stats
    call read_mem_info
    cmp rax, 0
    jl exit_program_error
    
    ; Calculate memory percentage
    call calculate_mem_percent
    mov rsi, rax                ; rsi = RAM%
    mov rdi, r13                ; rdi = CPU%
    
    ; Display statistics
    call display_stats
    test rax, rax
    js exit_program_error
    
    ; Sleep for 1 second total, but check for input every 100ms
    mov r12, 10                 ; 10 iterations * 100ms = 1 second
sleep_loop:
    ; Check for 'q' key during sleep
    call check_input
    cmp rax, -1
    je exit_program
    cmp rax, -2
    je suspend_program
    
    ; Sleep for 100ms
    mov rdi, sleep_time
    xor rsi, rsi                ; remaining time = NULL
    call sys_nanosleep
    
    dec r12
    jnz sleep_loop
    
    ; Loop
    jmp main_loop

suspend_program:
    ; Leave the user's terminal and screen usable while the process is stopped.
    call terminal_restore
    call display_cleanup

    ; A termination request wins over a concurrent suspend request.
    call signal_exit_requested
    test rax, rax
    jnz exit_program

    call suspend_until_continued
    test rax, rax
    js exit_program_error

    ; A termination signal may have arrived while the process was stopped.
    call signal_exit_requested
    test rax, rax
    jnz exit_program

    ; Re-enter interactive mode after SIGCONT.
    call terminal_raw_mode
    test rax, rax
    js exit_program_init_error

    call display_init
    test rax, rax
    js exit_program_error

    ; Discard CPU time elapsed while suspended and establish a fresh baseline.
    call init_cpu
    test rax, rax
    js exit_program_error
    jmp main_loop

exit_program:
    xor r15d, r15d              ; successful interactive/signal exit
    jmp exit_program_cleanup

exit_program_error:
    mov r15d, 1                 ; runtime failure

exit_program_cleanup:
    ; Restore terminal mode
    call terminal_restore
    
    ; Cleanup display
    call display_cleanup
    
    ; Exit
    mov rdi, r15
    call sys_exit

exit_program_init_error:
    mov rdi, 1                  ; initialization failed
    call sys_exit
