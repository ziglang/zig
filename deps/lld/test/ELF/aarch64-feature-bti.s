# REQUIRES: aarch64
# RUN: llvm-mc -filetype=obj -triple=aarch64-linux-gnu %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=aarch64-linux-gnu %p/Inputs/aarch64-bti1.s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=aarch64-linux-gnu %p/Inputs/aarch64-func3.s -o %t2.o
# RUN: llvm-mc -filetype=obj -triple=aarch64-linux-gnu %p/Inputs/aarch64-func3-bti.s -o %t3.o
# RUN: llvm-mc -filetype=obj -triple=aarch64-linux-gnu %p/Inputs/aarch64-func2.s -o %tno.o

## We do not add BTI support when the inputs don't have the .note.gnu.property
## field.

# RUN: ld.lld %tno.o %t3.o --shared -o %tno.so
# RUN: llvm-objdump -d -mattr=+bti --no-show-raw-insn %tno.so | FileCheck --check-prefix=NOBTI %s
# RUN: llvm-readelf -x .got.plt %tno.so | FileCheck --check-prefix SOGOTPLT %s
# RUN: llvm-readelf --dynamic-table %tno.so | FileCheck --check-prefix NOBTIDYN %s

# NOBTIDYN-NOT:   0x0000000070000001 (AARCH64_BTI_PLT)
# NOBTIDYN-NOT:   0x0000000070000003 (AARCH64_PAC_PLT)

# NOBTI: 0000000000010000 func2:
# NOBTI-NEXT:    10000: bl      #48 <func3@plt>
# NOBTI-NEXT:    10004: ret
# NOBTI: Disassembly of section .plt:
# NOBTI: 0000000000010010 .plt:
# NOBTI-NEXT:    10010: stp     x16, x30, [sp, #-16]!
# NOBTI-NEXT:    10014: adrp    x16, #131072
# NOBTI-NEXT:    10018: ldr     x17, [x16, #16]
# NOBTI-NEXT:    1001c: add     x16, x16, #16
# NOBTI-NEXT:    10020: br      x17
# NOBTI-NEXT:    10024: nop
# NOBTI-NEXT:    10028: nop
# NOBTI-NEXT:    1002c: nop
# NOBTI: 0000000000010030 func3@plt:
# NOBTI-NEXT:    10030: adrp    x16, #131072
# NOBTI-NEXT:    10034: ldr     x17, [x16, #24]
# NOBTI-NEXT:    10038: add     x16, x16, #24
# NOBTI-NEXT:    1003c: br      x17

## Expect a bti c at the start of plt[0], the plt entries do not need bti c as
## their address doesn't escape the shared object, so they can't be indirectly
## called. Expect no other difference.

# RUN: ld.lld %t1.o %t3.o --shared -o %t.so
# RUN: llvm-readelf -n %t.so | FileCheck --check-prefix BTIPROP %s
# RUN: llvm-objdump -d -mattr=+bti --no-show-raw-insn %t.so | FileCheck --check-prefix BTISO %s
# RUN: llvm-readelf -x .got.plt %t.so | FileCheck --check-prefix SOGOTPLT %s
# RUN: llvm-readelf --dynamic-table %t.so | FileCheck --check-prefix BTIDYN %s

# BTIPROP: Properties:    aarch64 feature: BTI

# BTIDYN:      0x0000000070000001 (AARCH64_BTI_PLT)
# BTIDYN-NOT:  0x0000000070000003 (AARCH64_PAC_PLT)

# BTISO: 0000000000010000 func2:
# BTISO-NEXT:    10000: bl      #48 <func3@plt>
# BTISO-NEXT:    10004: ret
# BTISO: Disassembly of section .plt:
# BTISO: 0000000000010010 .plt:
# BTISO-NEXT:    10010: bti     c
# BTISO-NEXT:    10014: stp     x16, x30, [sp, #-16]!
# BTISO-NEXT:    10018: adrp    x16, #131072
# BTISO-NEXT:    1001c: ldr     x17, [x16, #16]
# BTISO-NEXT:    10020: add     x16, x16, #16
# BTISO-NEXT:    10024: br      x17
# BTISO-NEXT:    10028: nop
# BTISO-NEXT:    1002c: nop
# BTISO: 0000000000010030 func3@plt:
# BTISO-NEXT:    10030: adrp    x16, #131072
# BTISO-NEXT:    10034: ldr     x17, [x16, #24]
# BTISO-NEXT:    10038: add     x16, x16, #24
# BTISO-NEXT:    1003c: br      x17

## The .got.plt should be identical between the BTI and no BTI DSO PLT.
# SOGOTPLT: Hex dump of section '.got.plt'
# SOGOTPLT-NEXT:  0x00030000 00000000 00000000 00000000 00000000
# SOGOTPLT-NEXT:  0x00030010 00000000 00000000 10000100 00000000

## Build an executable with all relocatable inputs having the BTI
## .note.gnu.property. We expect a bti c in front of all PLT entries as the
## address of a PLT entry can escape an executable.

# RUN: ld.lld %t2.o --shared -o %t2.so

# RUN: ld.lld %t.o %t.so %t2.so -o %t.exe
# RUN: llvm-readelf --dynamic-table -n %t.exe | FileCheck --check-prefix=BTIPROP %s
# RUN: llvm-objdump -d -mattr=+bti --no-show-raw-insn %t.exe | FileCheck --check-prefix=EXECBTI %s

# EXECBTI: Disassembly of section .text:
# EXECBTI: 0000000000210000 func1:
# EXECBTI-NEXT:   210000: bl      #48 <func2@plt>
# EXECBTI-NEXT:   210004: ret
# EXECBTI: Disassembly of section .plt:
# EXECBTI: 0000000000210010 .plt:
# EXECBTI-NEXT:   210010: bti     c
# EXECBTI-NEXT:   210014: stp     x16, x30, [sp, #-16]!
# EXECBTI-NEXT:   210018: adrp    x16, #131072
# EXECBTI-NEXT:   21001c: ldr     x17, [x16, #16]
# EXECBTI-NEXT:   210020: add     x16, x16, #16
# EXECBTI-NEXT:   210024: br      x17
# EXECBTI-NEXT:   210028: nop
# EXECBTI-NEXT:   21002c: nop
# EXECBTI: 0000000000210030 func2@plt:
# EXECBTI-NEXT:   210030: bti     c
# EXECBTI-NEXT:   210034: adrp    x16, #131072
# EXECBTI-NEXT:   210038: ldr     x17, [x16, #24]
# EXECBTI-NEXT:   21003c: add     x16, x16, #24
# EXECBTI-NEXT:   210040: br      x17
# EXECBTI-NEXT:   210044: nop

## We expect the same for PIE, as the address of an ifunc can escape
# RUN: ld.lld --pie %t.o %t.so %t2.so -o %tpie.exe
# RUN: llvm-readelf -n %tpie.exe | FileCheck --check-prefix=BTIPROP %s
# RUN: llvm-readelf --dynamic-table -n %tpie.exe | FileCheck --check-prefix=BTIPROP %s
# RUN: llvm-objdump -d -mattr=+bti --no-show-raw-insn %tpie.exe | FileCheck --check-prefix=PIE %s

# PIE: Disassembly of section .text:
# PIE: 0000000000010000 func1:
# PIE-NEXT:    10000: bl      #48 <func2@plt>
# PIE-NEXT:    10004: ret
# PIE: Disassembly of section .plt:
# PIE: 0000000000010010 .plt:
# PIE-NEXT:    10010: bti     c
# PIE-NEXT:    10014: stp     x16, x30, [sp, #-16]!
# PIE-NEXT:    10018: adrp    x16, #131072
# PIE-NEXT:    1001c: ldr     x17, [x16, #16]
# PIE-NEXT:    10020: add     x16, x16, #16
# PIE-NEXT:    10024: br      x17
# PIE-NEXT:    10028: nop
# PIE-NEXT:    1002c: nop
# PIE: 0000000000010030 func2@plt:
# PIE-NEXT:    10030: bti     c
# PIE-NEXT:    10034: adrp    x16, #131072
# PIE-NEXT:    10038: ldr     x17, [x16, #24]
# PIE-NEXT:    1003c: add     x16, x16, #24
# PIE-NEXT:    10040: br      x17
# PIE-NEXT:    10044: nop

## Build and executable with not all relocatable inputs having the BTI
## .note.property, expect no bti c and no .note.gnu.property entry

# RUN: ld.lld %t.o %t2.o %t.so -o %tnobti.exe
# RUN: llvm-readelf --dynamic-table %tnobti.exe | FileCheck --check-prefix NOBTIDYN %s
# RUN: llvm-objdump -d -mattr=+bti --no-show-raw-insn %tnobti.exe | FileCheck --check-prefix=NOEX %s

# NOEX: Disassembly of section .text:
# NOEX: 0000000000210000 func1:
# NOEX-NEXT:   210000: bl      #48 <func2@plt>
# NOEX-NEXT:   210004: ret
# NOEX: 0000000000210008 func3:
# NOEX-NEXT:   210008: ret
# NOEX: Disassembly of section .plt:
# NOEX: 0000000000210010 .plt:
# NOEX-NEXT:   210010: stp     x16, x30, [sp, #-16]!
# NOEX-NEXT:   210014: adrp    x16, #131072
# NOEX-NEXT:   210018: ldr     x17, [x16, #16]
# NOEX-NEXT:   21001c: add     x16, x16, #16
# NOEX-NEXT:   210020: br      x17
# NOEX-NEXT:   210024: nop
# NOEX-NEXT:   210028: nop
# NOEX-NEXT:   21002c: nop
# NOEX: 0000000000210030 func2@plt:
# NOEX-NEXT:   210030: adrp    x16, #131072
# NOEX-NEXT:   210034: ldr     x17, [x16, #24]
# NOEX-NEXT:   210038: add     x16, x16, #24
# NOEX-NEXT:   21003c: br      x17

## Force BTI entries with the --force-bti command line option. Expect a warning
## from the file without the .note.gnu.property.

# RUN: ld.lld %t.o %t2.o --force-bti %t.so -o %tforcebti.exe 2>&1 | FileCheck --check-prefix=FORCE-WARN %s

# FORCE-WARN: aarch64-feature-bti.s.tmp2.o: --force-bti: file does not have BTI property


# RUN: llvm-readelf -n %tforcebti.exe | FileCheck --check-prefix=BTIPROP %s
# RUN: llvm-readelf --dynamic-table %tforcebti.exe | FileCheck --check-prefix BTIDYN %s
# RUN: llvm-objdump -d -mattr=+bti --no-show-raw-insn %tforcebti.exe | FileCheck --check-prefix=FORCE %s

# FORCE: Disassembly of section .text:
# FORCE: 0000000000210000 func1:
# FORCE-NEXT:   210000: bl      #48 <func2@plt>
# FORCE-NEXT:   210004: ret
# FORCE: 0000000000210008 func3:
# FORCE-NEXT:   210008: ret
# FORCE: Disassembly of section .plt:
# FORCE: 0000000000210010 .plt:
# FORCE-NEXT:   210010: bti     c
# FORCE-NEXT:   210014: stp     x16, x30, [sp, #-16]!
# FORCE-NEXT:   210018: adrp    x16, #131072
# FORCE-NEXT:   21001c: ldr     x17, [x16, #16]
# FORCE-NEXT:   210020: add     x16, x16, #16
# FORCE-NEXT:   210024: br      x17
# FORCE-NEXT:   210028: nop
# FORCE-NEXT:   21002c: nop
# FORCE: 0000000000210030 func2@plt:
# FORCE-NEXT:   210030: bti     c
# FORCE-NEXT:   210034: adrp    x16, #131072
# FORCE-NEXT:   210038: ldr     x17, [x16, #24]
# FORCE-NEXT:   21003c: add     x16, x16, #24
# FORCE-NEXT:   210040: br      x17
# FORCE-NEXT:   210044: nop

.section ".note.gnu.property", "a"
.long 4
.long 0x10
.long 0x5
.asciz "GNU"

.long 0xc0000000 // GNU_PROPERTY_AARCH64_FEATURE_1_AND
.long 4
.long 1          // GNU_PROPERTY_AARCH64_FEATURE_1_BTI
.long 0

.text
.globl _start
.type func1,%function
func1:
  bl func2
  ret
