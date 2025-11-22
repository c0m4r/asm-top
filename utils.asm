; utils.asm - Utility functions for string/number conversion and parsing
; Intel syntax

section .text
global str_to_int
global int_to_str
global find_char
global skip_whitespace
global strlen

; str_to_int - Convert ASCII string to integer
; Arguments:
;   rdi = pointer to string
; Returns:
;   rax = integer value
;   rdi = pointer to first non-digit character
str_to_int:
    xor rax, rax            ; result = 0
    xor rcx, rcx            ; temp for digit
.loop:
    movzx rcx, byte [rdi]   ; load character
    cmp rcx, '0'
    jb .done                ; if < '0', done
    cmp rcx, '9'
    ja .done                ; if > '9', done
    sub rcx, '0'            ; convert ASCII to digit
    imul rax, 10            ; result *= 10
    add rax, rcx            ; result += digit
    inc rdi                 ; next character
    jmp .loop
.done:
    ret

; int_to_str - Convert integer to ASCII string
; Arguments:
;   rdi = integer value
;   rsi = pointer to buffer (must be at least 21 bytes)
; Returns:
;   rax = pointer to start of string (may be offset in buffer)
;   rdx = length of string
int_to_str:
    mov rax, rdi            ; value to convert
    mov rdi, rsi            ; buffer pointer
    add rdi, 20             ; start from end of buffer
    mov byte [rdi], 0       ; null terminator
    dec rdi
    
    mov rcx, 10             ; divisor
    xor rdx, rdx            ; length counter
    
    ; Handle zero special case
    test rax, rax
    jnz .convert
    mov byte [rdi], '0'
    mov rax, rdi
    mov rdx, 1
    ret
    
.convert:
    test rax, rax
    jz .done
    xor rdx, rdx            ; clear for division
    div rcx                 ; rax = quotient, rdx = remainder
    add dl, '0'             ; convert digit to ASCII
    mov [rdi], dl
    dec rdi
    jmp .convert
    
.done:
    inc rdi                 ; point to first digit
    mov rax, rdi            ; return pointer
    mov rdx, rsi
    add rdx, 20
    sub rdx, rdi            ; calculate length
    ret

; find_char - Find character in string
; Arguments:
;   rdi = pointer to string
;   sil = character to find
;   rdx = max length to search
; Returns:
;   rax = pointer to character (or 0 if not found)
find_char:
    mov rcx, rdx            ; counter
    mov rax, rdi            ; current position
.loop:
    test rcx, rcx
    jz .not_found
    cmp byte [rax], sil
    je .found
    inc rax
    dec rcx
    jmp .loop
.found:
    ret
.not_found:
    xor rax, rax
    ret

; skip_whitespace - Skip whitespace characters
; Arguments:
;   rdi = pointer to string
; Returns:
;   rax = pointer to first non-whitespace character
skip_whitespace:
    mov rax, rdi
.loop:
    movzx rcx, byte [rax]
    cmp rcx, ' '
    je .skip
    cmp rcx, '\t'
    je .skip
    cmp rcx, '\n'
    je .skip
    cmp rcx, '\r'
    je .skip
    ret                     ; found non-whitespace
.skip:
    inc rax
    jmp .loop

; strlen - Calculate string length
; Arguments:
;   rdi = pointer to null-terminated string
; Returns:
;   rax = length of string (excluding null terminator)
strlen:
    xor rax, rax
.loop:
    cmp byte [rdi + rax], 0
    je .done
    inc rax
    jmp .loop
.done:
    ret
