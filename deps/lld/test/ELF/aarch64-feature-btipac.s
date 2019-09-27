# REQUIRES: aarch64
# RUN: llvm-mc -filetype=obj -triple=aarch64-linux-gnu %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=aarch64-linux-gnu %p/Inputs/aarch64-btipac1.s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=aarch64-linux-gnu %p/Inputs/aarch64-func3.s -o %t3.o
# RUN: llvm-mc -filetype=obj -triple=aarch64-linux-gnu %p/Inputs/aarch64-func3-btipac.s -o %t3btipac.o

## Build shared library with all inputs having BTI and PAC, expect PLT
## entries supporting both PAC and BTI. For a shared library this means:
## PLT[0] has bti c at start
## PLT[n] has autia1716 before br x17

# RUN: ld.lld %t1.o %t3btipac.o --shared -o %t.so
# RUN: llvm-readelf -n %t.so | FileCheck --check-prefix BTIPACPROP %s
# RUN: llvm-objdump -d -mattr=+v8.5a --no-show-raw-insn %t.so | FileCheck --check-prefix BTIPACSO %s
# RUN: llvm-readelf --dynamic-table %t.so | FileCheck --check-prefix BTIPACDYN %s

# BTIPACSO: Disassembly of section .text:
# BTIPACSO: 0000000000010000 func2:
# BTIPACSO-NEXT:    10000: bl      #48 <func3@plt>
# BTIPACSO-NEXT:    10004: ret
# BTIPACSO: 0000000000010008 func3:
# BTIPACSO-NEXT:    10008: ret
# BTIPACSO: Disassembly of section .plt:
# BTIPACSO: 0000000000010010 .plt:
# BTIPACSO-NEXT:    10010: bti     c
# BTIPACSO-NEXT:    10014: stp     x16, x30, [sp, #-16]!
# BTIPACSO-NEXT:    10018: adrp    x16, #131072
# BTIPACSO-NEXT:    1001c: ldr     x17, [x16, #16]
# BTIPACSO-NEXT:    10020: add     x16, x16, #16
# BTIPACSO-NEXT:    10024: br      x17
# BTIPACSO-NEXT:    10028: nop
# BTIPACSO-NEXT:    1002c: nop
# BTIPACSO: 0000000000010030 func3@plt:
# BTIPACSO-NEXT:    10030: adrp    x16, #131072
# BTIPACSO-NEXT:    10034: ldr     x17, [x16, #24]
# BTIPACSO-NEXT:    10038: add     x16, x16, #24
# BTIPACSO-NEXT:    1003c: autia1716
# BTIPACSO-NEXT:    10040: br      x17
# BTIPACSO-NEXT:    10044: nop

# BTIPACPROP:    Properties:    aarch64 feature: BTI, PAC

# BTIPACDYN:   0x0000000070000001 (AARCH64_BTI_PLT)
# BTIPACDYN:   0x0000000070000003 (AARCH64_PAC_PLT)

## Make an executable with both BTI and PAC properties. Expect:
## PLT[0] bti c as first instruction
## PLT[n] bti n as first instruction, autia1716 before br x17

# RUN: ld.lld %t.o %t3btipac.o %t.so -o %t.exe
# RUN: llvm-readelf -n %t.exe | FileCheck --check-prefix=BTIPACPROP %s
# RUN: llvm-objdump -d -mattr=+v8.5a --no-show-raw-insn %t.exe | FileCheck --check-prefix BTIPACEX %s
# RUN: llvm-readelf --dynamic-table %t.exe | FileCheck --check-prefix BTIPACDYN %s

# BTIPACEX: Disassembly of section .text:
# BTIPACEX: 0000000000210000 func1:
# BTIPACEX-NEXT:   210000: bl      #48 <func2@plt>
# BTIPACEX-NEXT:   210004: ret
# BTIPACEX-NEXT:   210008: ret
# BTIPACEX: 000000000021000c func3:
# BTIPACEX-NEXT:   21000c: ret
# BTIPACEX: Disassembly of section .plt:
# BTIPACEX: 0000000000210010 .plt:
# BTIPACEX-NEXT:   210010: bti     c
# BTIPACEX-NEXT:   210014: stp     x16, x30, [sp, #-16]!
# BTIPACEX-NEXT:   210018: adrp    x16, #131072
# BTIPACEX-NEXT:   21001c: ldr     x17, [x16, #16]
# BTIPACEX-NEXT:   210020: add     x16, x16, #16
# BTIPACEX-NEXT:   210024: br      x17
# BTIPACEX-NEXT:   210028: nop
# BTIPACEX-NEXT:   21002c: nop
# BTIPACEX: 0000000000210030 func2@plt:
# BTIPACEX-NEXT:   210030: bti     c
# BTIPACEX-NEXT:   210034: adrp    x16, #131072
# BTIPACEX-NEXT:   210038: ldr     x17, [x16, #24]
# BTIPACEX-NEXT:   21003c: add     x16, x16, #24
# BTIPACEX-NEXT:   210040: autia1716
# BTIPACEX-NEXT:   210044: br      x17

## Check that combinations of BTI+PAC with 0 properties results in standard PLT

# RUN: ld.lld %t.o %t3.o %t.so -o %t.exe
# RUN: llvm-objdump -d -mattr=+v8.5a --no-show-raw-insn %t.exe | FileCheck --check-prefix EX %s
# RUN: llvm-readelf --dynamic-table %t.exe | FileCheck --check-prefix=NODYN %s

# EX: Disassembly of section .text:
# EX: 0000000000210000 func1:
# EX-NEXT:   210000: bl      #48 <func2@plt>
# EX-NEXT:   210004: ret
# EX-NEXT:   210008: ret
# EX: 000000000021000c func3:
# EX-NEXT:   21000c: ret
# EX: Disassembly of section .plt:
# EX: 0000000000210010 .plt:
# EX-NEXT:   210010: stp     x16, x30, [sp, #-16]!
# EX-NEXT:   210014: adrp    x16, #131072
# EX-NEXT:   210018: ldr     x17, [x16, #16]
# EX-NEXT:   21001c: add     x16, x16, #16
# EX-NEXT:   210020: br      x17
# EX-NEXT:   210024: nop
# EX-NEXT:   210028: nop
# EX-NEXT:   21002c: nop
# EX: 0000000000210030 func2@plt:
# EX:        210030: adrp    x16, #131072
# EX-NEXT:   210034: ldr     x17, [x16, #24]
# EX-NEXT:   210038: add     x16, x16, #24
# EX-NEXT:   21003c: br      x17

# NODYN-NOT:   0x0000000070000001 (AARCH64_BTI_PLT)
# NODYN-NOT:   0x0000000070000003 (AARCH64_PAC_PLT)

## Check that combination of --pac-plt and --force-bti warns for the file that
## doesn't contain the BTI property, but generates PAC and BTI PLT sequences.
## The --pac-plt doesn't warn as it is not required for correctness.

# RUN: ld.lld %t.o %t3.o %t.so --pac-plt --force-bti -o %t.exe 2>&1 | FileCheck --check-prefix=FORCE-WARN %s

# FORCE-WARN: aarch64-feature-btipac.s.tmp3.o: --force-bti: file does not have BTI property

# RUN: llvm-readelf -n %t.exe | FileCheck --check-prefix=BTIPACPROP %s
# RUN: llvm-objdump -d -mattr=+v8.5a --no-show-raw-insn %t.exe | FileCheck --check-prefix BTIPACEX %s
# RUN: llvm-readelf --dynamic-table %t.exe | FileCheck --check-prefix BTIPACDYN %s
.section ".note.gnu.property", "a"
.long 4
.long 0x10
.long 0x5
.asciz "GNU"

.long 0xc0000000 // GNU_PROPERTY_AARCH64_FEATURE_1_AND
.long 4
.long 3          // GNU_PROPERTY_AARCH64_FEATURE_1_BTI and PAC
.long 0

.text
.globl _start
.type func1,%function
func1:
  bl func2
  ret
.globl func3
.type func3,%function
  ret
