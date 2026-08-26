# ASM-TOP Security and Code Quality Review

- **Review date:** 2026-08-27
- **Reviewed revision:** `1acd111` (`0.3.2 checksum`)
- **Platform tested:** Linux 6.18.45, x86-64; NASM 3.02; GNU ld 2.47

## Executive summary

ASM-TOP has a deliberately small attack surface: it is a single-threaded,
statically linked monitor, needs no elevated privileges, reads a fixed set of
`/proc` files, accepts only terminal keystrokes, and does not allocate dynamic
memory or use third-party runtime code. The v0.3.2 signal and output changes are
material improvements. In testing, normal quit, SIGINT, SIGTERM, SIGTSTP/
SIGCONT, and SIGPIPE paths all restored the terminal successfully.

No Critical or High severity vulnerability was found. The review identified
three Medium findings: one fixed-size output buffer can be crossed by malformed
`/proc/loadavg` data, CPU delta arithmetic does not handle counter regressions,
and several `sysinfo.asm` call sites violate the x86-64 System V stack-alignment
rule. The first two are principally robustness/correctness issues under the
normal Linux `/proc` trust model; the malformed-input issue becomes security
relevant if ASM-TOP is ever run against an attacker-controlled proc-like tree or
inside a partially trusted chroot/container.

### Finding count

| Severity | Count |
|---|---:|
| Critical | 0 |
| High | 0 |
| Medium | 3 |
| Low | 5 |
| Informational | 2 |

**Overall security risk:** Low for the intended use as an unprivileged monitor
on a normal Linux host.

**Overall code quality:** Good core structure, with important hardening and
testability work still warranted for hand-written assembly.

## Scope and method

The review covered all eleven assembly modules, the syscall and ABI boundaries,
terminal/signal lifecycle, parsers and formatters, build/install scripts,
binary hardening, and user documentation. Existing files in `reviews/` were
treated only as historical context; every finding below was checked against
the v0.3.2 source.

The assumed deployment is an ordinary, non-setuid executable on Linux x86-64.
`/proc` is normally kernel-generated and trustworthy in that deployment. The
review also considers malformed fixtures, chroots, mount namespaces, and UTS
namespaces because those are useful robustness boundaries and can occur in
containerized use.

## Findings

### M-01: `/proc/loadavg` can cross the 64-byte destination buffer

**Severity:** Medium (memory safety and robustness); Low exploitability in the
normal kernel-backed `/proc` threat model.

[`sysinfo.asm`](../sysinfo.asm#L12) reserves a 128-byte input buffer followed by
separate 64-byte load and task strings. `get_load_average_string` reads at most
127 bytes and adds a terminator, which correctly protects the input buffer
([`sysinfo.asm`](../sysinfo.asm#L388-L403)). Its copy loop, however, has no
destination counter. It stops only at newline, NUL, or after a third space
([`sysinfo.asm`](../sysinfo.asm#L405-L437)).

A 127-byte line with fewer than three spaces therefore writes 127 bytes plus a
terminator starting at `load_str_buf`, crossing its 64-byte boundary and
overwriting all of the adjacent `tasks_str_buf`. The current Linux kernel emits
a short, well-formed line, so this is not reachable from a conventional `/proc`
mount. It is nevertheless a concrete out-of-bounds write for malformed input,
and the hard-coded path does not guarantee a real procfs when the executable is
used in a chroot or unusual mount namespace.

The related `find_char` helper is length-limited but does not stop at NUL
([`utils.asm`](../utils.asm#L78-L100)); `get_tasks_string` can consequently read
past the current loadavg record into stale bytes when the record is malformed
([`sysinfo.asm`](../sysinfo.asm#L518-L529)). Numeric conversion also wraps on
overflow and has no end pointer ([`utils.asm`](../utils.asm#L12-L33)).

**Recommendation:** Make every parser accept `[begin, end)` bounds. Give every
formatter an explicit destination capacity, reserve one byte for NUL, reject
truncated records, stop character searches at either NUL or `end`, and have
`str_to_int` report `no digits` and `overflow` separately. Add malformed and
maximum-length fixtures before changing these routines.

### M-02: CPU delta math assumes counters never regress

**Severity:** Medium (display correctness and arithmetic robustness).

`calculate_cpu_percent` subtracts the previous total and idle counters with
unsigned wraparound, checks only for a zero total delta, multiplies the derived
busy delta by 100, and divides ([`cpu.asm`](../cpu.asm#L192-L227)). It does not
handle any of these cases:

- `curr_total < prev_total` after a reset or anomalous source;
- `curr_idle < prev_idle`;
- `idle_diff > total_diff`; or
- overflow of `non_idle_diff * 100`.

This is not purely hypothetical: Linux's `proc_stat(5)` documentation explicitly
states that the `iowait` field may decrease in some conditions, and ASM-TOP adds
`iowait` to its idle counter ([`cpu.asm`](../cpu.asm#L125-L141)). A regressing
idle aggregate can wrap to a huge unsigned delta and produce a percentage over
100. `render_bar` clamps only the graphical fill
([`display.asm`](../display.asm#L200-L211)); the raw number is still printed
([`display.asm`](../display.asm#L339-L346)).

**Recommendation:** Treat a total regression as a baseline reset. Treat an idle
regression conservatively, ensure `idle_diff <= total_diff`, use checked or
128-bit multiplication, clamp the final value to 0..100, and update/reset the
baseline on every path. Unit-test zero deltas, regressions, resets, near-`UINT64`
values, and ordinary samples.

### M-03: Several calls violate the x86-64 System V stack-alignment rule

**Severity:** Medium (ABI correctness and future maintainability); no failure
was observed with the current leaf callees.

The System V AMD64 ABI requires `%rsp` to be 16-byte aligned immediately before
a `call`. Several `sysinfo.asm` prologues leave it eight bytes off:

- `get_hostname` calls `sys_open` and `sys_read` after an even number of pushes
  ([`sysinfo.asm`](../sysinfo.asm#L48-L67));
- `get_time_string` calls `sys_time` after six pushes
  ([`sysinfo.asm`](../sysinfo.asm#L103-L118));
- the temporary `push rax` misaligns the `sys_close` calls in the uptime and
  load-average functions ([`sysinfo.asm`](../sysinfo.asm#L228-L237),
  [`sysinfo.asm`](../sysinfo.asm#L388-L397)); and
- `get_tasks_string` performs most calls from a misaligned frame
  ([`sysinfo.asm`](../sysinfo.asm#L456-L529)).

The current targets are small assembly helpers and syscall wrappers that do not
use alignment-sensitive SIMD instructions, which explains why runtime testing
passes. The violation can become a crash or instrumentation failure after a
seemingly harmless refactor, compiler-generated helper, or sanitizer hook.

**Recommendation:** Standardize prologue/epilogue macros and add an 8-byte pad
where required. Avoid using `push` merely to preserve syscall results; reserve
an aligned local slot or use a callee-saved register. Document both register
ownership and the alignment invariant at every callable interface.

### L-01: The hostname is emitted as unsanitized terminal control data

**Severity:** Low.

`get_hostname` copies bytes from `/proc/sys/kernel/hostname` without filtering
([`sysinfo.asm`](../sysinfo.asm#L45-L90)), and `display_stats` passes them directly
to the terminal ([`display.asm`](../display.asm#L281-L284)). Linux limits hostname
length but `sethostname(2)` accepts a byte sequence rather than enforcing a safe
display alphabet. A hostname containing ESC or other control bytes can inject
ANSI/OSC sequences, alter presentation, or trigger terminal-specific actions.

Changing the UTS hostname normally requires `CAP_SYS_ADMIN` in the relevant
namespace, so this does not create a useful privilege escalation on a standard
host. It matters more when a user enters a container or namespace whose
hostname was selected by another party.

**Recommendation:** Render only a conservative printable hostname alphabet or
escape all control/non-ASCII bytes. At minimum reject bytes below `0x20`, DEL,
and ESC before calling the display layer.

### L-02: Important syscall failures are ignored or converted into plausible data

**Severity:** Low.

- The main loop ignores every `nanosleep` result
  ([`main.asm`](../main.asm#L93-L99)). A persistent error such as a seccomp denial
  turns the refresh loop into a busy loop.
- `get_time_string` does not check the raw `time` syscall before unsigned
  division ([`sysinfo.asm`](../sysinfo.asm#L115-L126)); a negative errno becomes
  a plausible but incorrect UTC time.
- `check_input` treats a poll error like no input
  ([`input.asm`](../input.asm#L51-L64)).
- Close and cleanup failures are generally discarded, and fatal startup/runtime
  failures exit with status 1 but no stderr diagnostic. Running without a TTY,
  for example, fails silently.

The output path is stronger: `write_stdout` correctly retries EINTR, completes
short writes, and records other failures ([`display.asm`](../display.asm#L118-L169)).

**Recommendation:** Define one raw-syscall error convention (`-errno`, not just
`-1`), retry only the appropriate EINTR cases, propagate fatal failures, and
write a short diagnostic to stderr after restoring the terminal. For sleep,
either continue with the returned remainder or fail rather than spin.

### L-03: The ELF lacks two inexpensive hardening properties

**Severity:** Low (defense in depth).

The reviewed binary is a fixed-address `ET_EXEC` with entry point `0x401000`, so
its code and global data are not ASLR-randomized. It also has no `PT_GNU_STACK`
program header because the objects do not declare `.note.GNU-stack` and the
linker is not passed `-z noexecstack` ([`Makefile`](../Makefile#L1-L26)). On the
tested Linux 6.18 kernel the actual stack mapping was `rw-p`, and the load
segments are cleanly split R, RX, and RW; this report does **not** claim that the
tested stack was executable. The missing marker still leaves policy implicit
and is reported poorly by hardening scanners or older toolchains.

There is no dynamic section, so dynamic-linker RELRO and dependency-hardening
concerns mostly do not apply. PIE is also defense in depth because no direct
control-flow corruption was found.

**Recommendation:** Add `-z noexecstack` now. Consider converting absolute data
references to RIP-relative form (`default rel`) and producing a static PIE if
the size/complexity tradeoff is acceptable. Strip the release symbol table if
the debugging symbols are not intentionally shipped.

### L-04: Configuration and installation paths are brittle and unsafe to trust

**Severity:** Low.

The configured directories are copied verbatim into Make syntax
([`configure`](../configure#L78-L87)), then expanded unquoted in install and
uninstall recipes ([`Makefile`](../Makefile#L34-L44)). A legitimate path with a
space is split into multiple arguments; `make -n BINDIR='/tmp/asm top/bin'
install` demonstrates this. Dollar signs, `#`, newlines, Make functions, shell
metacharacters, and leading dashes can also change parsing. Configuration values
must therefore be treated as code if `make install` is run with elevated
privileges.

The standalone installer has no `set -e`, uses `mv` rather than `install`, and
then always attempts `chmod` ([`install.sh`](../install.sh#L1-L4)). If the source
binary is missing but an older destination exists, `mv` fails, `chmod` succeeds,
and the script returns success without installing the new version. It also
removes the local build artifact.

The README's quick-install checksum command removes a failed download but does
not gate the following `sudo mv`, `chmod`, and execution lines
([`README.md`](../README.md#L29-L37)). In an ordinary interactive shell those
later commands still run; if an older destination exists, the sequence can end
up invoking that older binary after a failed update.

**Recommendation:** Validate or correctly escape generated Make values; quote
recipe paths and use `--` where supported. Replace `install.sh` with `set -eu`
and one `install -D -m 0755 -- ./asm-top /usr/local/bin/asm-top` operation.
Use a temporary download and an `&&`-gated checksum/install sequence. Prefer
building unprivileged and elevating only the final, explicit install command.

### L-05: There is no automated regression suite or CI

**Severity:** Low (assurance and change risk).

The repository has no test target, test fixtures, or CI configuration. This is
especially costly for assembly because ABI mistakes, parser boundary errors,
and signal/TTY races are difficult for ordinary source linters to detect. The
large v0.3.2 hardening change currently depends on manual verification.

**Recommendation:** Add:

1. fixture-driven tests for each `/proc` parser, including truncation, missing
   fields, maximum integers, overflow, and counter regressions;
2. direct tests for `str_to_int`, `int_to_str`, and size formatting;
3. PTY integration tests for `q`, SIGINT, SIGTERM, SIGHUP, SIGTSTP/SIGCONT,
   SIGPIPE, EOF, and terminal restoration;
4. an ELF-policy check for W^X, `PT_GNU_STACK`, and the intended PIE policy; and
5. build jobs using multiple supported NASM/binutils versions.

### I-01: Documentation and interface comments have drifted

**Severity:** Informational.

- The assembly guide still says the termios copy is 60 bytes, while the fixed
  implementation uses the 36-byte x86-64 kernel layout
  ([`ASSEMBLY_GUIDE.md`](../ASSEMBLY_GUIDE.md#L427-L439),
  [`terminal.asm`](../terminal.asm#L10-L23)).
- Its `/proc/stat` example reads 4096 bytes, while the implementation correctly
  reads 4095 and reserves a terminator
  ([`ASSEMBLY_GUIDE.md`](../ASSEMBLY_GUIDE.md#L478-L506),
  [`cpu.asm`](../cpu.asm#L68-L84)).
- The README's project tree omits `terminal.asm`, `format.asm`, `configure`, and
  other shipped files ([`README.md`](../README.md#L131-L147)).
- Most syscall-wrapper comments promise exactly `-1`, but raw Linux syscalls
  return `-errno` ([`syscalls.asm`](../syscalls.asm#L19-L108)).
- The README says approximately 21 KB; the verified release/rebuilt artifact is
  23,088 bytes ([`README.md`](../README.md#L25)).

These mismatches are not vulnerabilities, but low-level documentation is part
of the safety model: future changes will copy its examples.

### I-02: Minor maintainability and efficiency debt

**Severity:** Informational.

- `TARGET` is assigned twice and `MANDIR` is configured but never used
  ([`Makefile`](../Makefile#L6-L16)).
- `get_hostname`, `get_time_string`, and `get_uptime_string` are each exported
  three times ([`sysinfo.asm`](../sysinfo.asm#L33-L43)).
- `months` and `slash_str` are unused
  ([`sysinfo.asm`](../sysinfo.asm#L5-L10),
  [`format.asm`](../format.asm#L5-L12)).
- Several qword objects are only four-byte aligned. This is legal on x86-64 but
  avoidable and less clear than adding `align 8` before qword state.
- Each frame opens `/proc/loadavg` twice and renders each bar with forty
  one-byte writes. At one frame per second this is not a performance problem,
  but one read and one assembled output buffer would simplify error handling
  and produce a consistent snapshot.
- Internal routines keep live values in caller-saved registers across calls
  because the current leaf helpers happen not to clobber them. Examples include
  `r8`/`r9` in the CPU parser and `r8` in sysinfo formatters. This works today
  but should be made an explicit private convention or replaced with
  callee-saved/local storage.

## Positive security and quality properties

- Fixed, read-only data sources and no elevated privilege requirement keep the
  primary attack surface small.
- CPU and memory reads reserve room for a NUL terminator, and `find_line` carries
  an explicit input end pointer ([`cpu.asm`](../cpu.asm#L68-L90),
  [`memory.asm`](../memory.asm#L35-L111)).
- Memory parsing rejects zero `MemTotal`, `MemAvailable > MemTotal`, and
  `SwapFree > SwapTotal`, preventing divide-by-zero and underflow in the normal
  calculation path ([`memory.asm`](../memory.asm#L150-L215),
  [`memory.asm`](../memory.asm#L246-L280)).
- Output handles short writes and EINTR, and the progress-bar fill is
  defensively clamped.
- Signal handlers perform only aligned flag stores and defer all terminal and
  display work to normal control flow ([`signals.asm`](../signals.asm#L172-L186)).
- The SIGTSTP path restores the terminal and alternate screen before stopping,
  reinstalls the handler after continuation, and resets the CPU baseline.
- Input draining is bounded to 64 bytes per check, avoiding starvation under a
  continuous input stream ([`input.asm`](../input.asm#L20-L84)).
- The executable is statically linked with no dynamic dependencies, and its
  loadable segments maintain W^X separation.
- The published v0.3.2 SHA-256 value matches a local rebuild exactly.

## Verification performed

| Check | Result |
|---|---|
| `make -B` | Passed with NASM 3.02 and GNU ld 2.47 |
| Rebuilt SHA-256 | `9947e22ddef2edc105f7e156375b8d8e090912046a38d66bb13a2d7325a738c7`; matches README |
| `shellcheck -s sh configure install.sh` | Passed |
| Normal interactive run and `q` | Exit 0; alternate screen, cursor, and termios restored |
| Program-directed SIGINT and SIGTERM | Exit 0; display and terminal restored |
| SIGTSTP followed by SIGCONT | Screen/terminal cleaned before stop; display reinitialized after resume; later exit restored state |
| Broken stdout / SIGPIPE | Exit 1; terminal restored |
| Non-TTY stdin | Immediate silent exit 1 |
| ELF inspection | Static `ET_EXEC`; R/RX/RW load segments; no dynamic section; no `PT_GNU_STACK` header |
| Runtime stack inspection | `rw-p` on the tested Linux 6.18 kernel |
| Strict NASM warning experiment | `-Wall -Werror` fails on numerous absolute/section-crossing relocation warnings; the normal build does not enable warnings |

`strace` could not be used because ptrace is denied in the review sandbox.
Valgrind was unavailable, and conventional compiler sanitizers do not directly
instrument this standalone NASM program. Malformed procfs fuzzing was not run
because data paths are hard-coded and there is currently no injectable parser
harness. Those constraints reinforce the testability recommendation rather
than changing the static findings.

## Recommended remediation order

1. Bound the load-average copy and convert all parsers to explicit begin/end and
   destination-capacity contracts.
2. Make CPU delta arithmetic regression-safe and guarantee a 0..100 result.
3. Correct stack alignment throughout `sysinfo.asm` and codify the ABI in macros.
4. Add parser/unit fixtures and PTY-based lifecycle tests before further feature
   work.
5. Sanitize hostname output and make syscall failures diagnosable.
6. Add `-z noexecstack`, decide and document a PIE policy, and make configuration
   and installation paths robust.
7. Refresh the assembly guide and remove duplicate/dead declarations.

After items 1 through 4, the project would have a strong assurance baseline for
its intentionally narrow role. None of the findings requires a redesign of the
current architecture.
