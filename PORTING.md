# Porting ASM-TOP to RISC-V and ARM64

## Summary

Porting this x86-64 assembly program to RISC-V or ARM64 would require **moderate to significant changes**, not small ones. While the overall program structure and logic can remain the same, nearly every line of assembly code would need to be rewritten due to fundamental architectural differences.

## Complexity Assessment: Moderate (6-7/10)

**What stays the same:**
- Overall program structure and modular design
- Algorithm logic (CPU/memory calculations, parsing strategies)
- Data structures and buffer layouts
- System call concepts (though numbers differ)

**What changes significantly:**
- Every instruction must be rewritten for the target ISA
- Register names and conventions
- Syscall numbers and calling conventions
- Assembly syntax (depending on assembler)
- Build tools and flags

---

## Detailed Change Analysis

### 1. Instruction Set Differences

#### **x86-64** (CISC - Complex Instruction Set)
- Variable-length instructions (1-15 bytes)
- Complex addressing modes: `mov rax, [rbx + rcx*8 + 16]`
- String operations: `rep movsb`
- Condition flags set implicitly by most instructions

#### **ARM64** (RISC - Reduced Instruction Set)
- Fixed 32-bit instruction width
- Load/store architecture (only `ldr`/`str` access memory)
- Simple addressing: must load address first, then access
- Explicit condition flag updates

#### **RISC-V** (RISC - Reduced Instruction Set)
- Fixed 32-bit instruction width (base ISA)
- Load/store architecture similar to ARM64
- No hardware multiply/divide in base ISA (needs M extension)
- Very clean, minimal instruction set

### Example Comparison

**x86-64 code:**
```asm
mov rax, [mem_total]
sub rax, [mem_available]
imul rax, 100
xor rdx, rdx
div rcx
```

**ARM64 equivalent:**
```asm
adrp x9, mem_total
ldr x0, [x9, :lo12:mem_total]
adrp x9, mem_available
ldr x1, [x9, :lo12:mem_available]
sub x0, x0, x1
mov x1, #100
mul x0, x0, x1
udiv x0, x0, x2
```

**RISC-V equivalent:**
```asm
la t0, mem_total
ld a0, 0(t0)
la t0, mem_available
ld t1, 0(t0)
sub a0, a0, t1
li t1, 100
mul a0, a0, t1
divu a0, a0, a2
```

---

## 2. Register Differences

### x86-64 Registers
- General purpose: `rax`, `rbx`, `rcx`, `rdx`, `rsi`, `rdi`, `r8`-`r15`
- Stack pointer: `rsp`
- Base pointer: `rbp`

### ARM64 Registers
- General purpose: `x0`-`x30` (64-bit), `w0`-`w30` (32-bit lower half)
- Stack pointer: `sp`
- Frame pointer: `x29` (fp)
- Link register: `x30` (lr) - stores return address

### RISC-V Registers
- General purpose: `x0`-`x31` (also called `zero`, `ra`, `sp`, `gp`, `tp`, `t0`-`t6`, `s0`-`s11`, `a0`-`a7`)
- `x0` is hardwired to zero
- Stack pointer: `sp` (x2)
- Return address: `ra` (x1)

---

## 3. System Call Differences

### Calling Convention

**x86-64:**
- Syscall number in `rax`
- Args: `rdi`, `rsi`, `rdx`, `r10`, `r8`, `r9`
- Instruction: `syscall`
- Return in `rax`

**ARM64:**
- Syscall number in `x8`
- Args: `x0`-`x5`
- Instruction: `svc #0`
- Return in `x0`

**RISC-V:**
- Syscall number in `a7` (x17)
- Args: `a0`-`a5` (x10-x15)
- Instruction: `ecall`
- Return in `a0` (x10)

### Syscall Numbers (Linux)

| Operation | x86-64 | ARM64 | RISC-V |
|-----------|--------|-------|--------|
| read      | 0      | 63    | 63     |
| write     | 1      | 64    | 64     |
| open      | 2      | -1    | 1024   |
| openat    | 257    | 56    | 56     |
| close     | 3      | 57    | 57     |
| nanosleep | 35     | 101   | 101    |
| poll      | 7      | 73    | 73     |
| time      | 201    | -     | -      |
| clock_gettime | 228 | 113   | 113    |
| exit      | 60     | 93    | 93     |

**Note:** ARM64 and RISC-V don't have `open()` or `time()` - must use `openat()` and `clock_gettime()` instead!

---

## 4. File-by-File Changes Required

### syscalls.asm
- **Effort:** High
- Rewrite every syscall wrapper with new registers
- Change syscall numbers
- Replace `syscall` with `svc #0` (ARM64) or `ecall` (RISC-V)
- Some syscalls need complete replacement (open→openat, time→clock_gettime)

### utils.asm  
- **Effort:** Moderate-High
- Rewrite division loops (some RISC-V cores lack hardware divide)
- Change all register names
- Memory access patterns must change for ARM64/RISC-V (load/store)

### cpu.asm
- **Effort:** Moderate
- Same parsing logic, different instructions
- All pointer arithmetic must be explicit loads/stores
- Register renaming throughout

### memory.asm
- **Effort:** Moderate
- Similar to cpu.asm
- Rewrite string search and parsing with RISC conventions

### display.asm
- **Effort:** Moderate
- Rewrite all output code with new syscall conventions
- String operations must be explicit loops (no `rep` instruction)

### input.asm
- **Effort:** Low-Moderate
- Poll syscall number changes
- New registers, same logic

### sysinfo.asm
- **Effort:** High
- Must replace `time()` with `clock_gettime()` on ARM64/RISC-V
- Different struct layout for timespec
- Time calculations stay the same

### main.asm
- **Effort:** Low
- Just register renaming and calling convention changes
- Logic unchanged

---

## 5. Build System Changes

### x86-64 (current)
```makefile
AS = nasm
ASFLAGS = -f elf64
```

### ARM64
```makefile
AS = aarch64-linux-gnu-as
ASFLAGS = 
# OR
AS = clang
ASFLAGS = --target=aarch64-linux-gnu
```

### RISC-V
```makefile
AS = riscv64-linux-gnu-as
ASFLAGS = -march=rv64gc
# OR  
AS = clang
ASFLAGS = --target=riscv64-linux-gnu
```

---

## 6. Estimated Effort

| Component | Lines Changed | Effort Level |
|-----------|---------------|--------------|
| syscalls.asm | ~95% | High |
| utils.asm | ~90% | High |
| cpu.asm | ~85% | Moderate-High |
| memory.asm | ~85% | Moderate-High |
| display.asm | ~80% | Moderate |
| input.asm | ~75% | Moderate |
| sysinfo.asm | ~90% | High |
| main.asm | ~60% | Low-Moderate |
| Makefile | 100% | Low |

**Overall:** ~85% of assembly code needs modification

---

## 7. Development Strategy

### Recommended Approach

1. **Start with syscalls.asm** - Get the foundation working
2. **Port utils.asm** - Critical for everything else
3. **Test basic I/O** - Write simple test programs
4. **Port cpu.asm and memory.asm** - Core functionality
5. **Port display.asm** - See output
6. **Port input.asm and sysinfo.asm** - Polish features
7. **Integrate main.asm** - Tie it all together

### Testing Strategy
- Cross-compile and test on QEMU
- Test on real hardware (Raspberry Pi for ARM64, RISC-V boards)
- Validate syscall numbers with `strace`

---

## Conclusion

**Porting difficulty: Moderate (6-7/10)**

While the logical flow and algorithms remain identical, porting ASM-TOP to RISC-V or ARM64 requires:
- Rewriting **~85% of all assembly instructions**
- Understanding new ISA architectures  
- Changing syscall numbers and conventions
- Testing on emulators or real hardware

The good news:
- ✅ Modular structure makes porting manageable
- ✅ Logic and algorithms are architecture-independent
- ✅ `/proc` filesystem is the same on all Linux systems
- ✅ Each module can be ported and tested independently

The challenge is **not conceptual complexity** - it's the **manual translation work** of converting every instruction to the target ISA. An experienced assembly programmer could port this in 1-2 days per architecture.
