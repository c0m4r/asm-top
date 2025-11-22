; main.asm - Main program entry point
; Intel syntax

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

global _start

_start:
    ; Set terminal to raw mode for immediate input
    call terminal_raw_mode
    
    ; Initialize display
    call display_init
    
    ; Initialize CPU monitoring (first reading)
    call init_cpu
    
main_loop:
    ; Check for keyboard input (non-blocking)
    call check_input
    cmp rax, -1                 ; -1 means quit ('q' pressed)
    je exit_program
    
    ; Read CPU stats
    call read_cpu_stat
    cmp rax, 0
    jl exit_program             ; error, exit
    
    ; Calculate CPU percentage
    call calculate_cpu_percent
    push rax                    ; save CPU%
    
    ; Read memory stats
    call read_mem_info
    cmp rax, 0
    jl exit_program_pop         ; error, exit (but pop first)
    
    ; Calculate memory percentage
    call calculate_mem_percent
    mov rsi, rax                ; rsi = RAM%
    pop rdi                     ; rdi = CPU%
    
    ; Display statistics
    call display_stats
    
    ; Sleep for 1 second total, but check for input every 100ms
    mov r12, 10                 ; 10 iterations * 100ms = 1 second
sleep_loop:
    ; Check for 'q' key during sleep
    call check_input
    cmp rax, -1
    je exit_program
    
    ; Sleep for 100ms
    mov rdi, sleep_time
    xor rsi, rsi                ; remaining time = NULL
    call sys_nanosleep
    
    dec r12
    jnz sleep_loop
    
    ; Loop
    jmp main_loop

exit_program_pop:
    pop rax                     ; balance stack
    
exit_program:
    ; Restore terminal mode
    call terminal_restore
    
    ; Cleanup display
    call display_cleanup
    
    ; Exit
    xor rdi, rdi                ; exit code 0
    call sys_exit
