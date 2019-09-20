# REQUIRES: aarch64
# RUN: llvm-mc -filetype=obj -triple=aarch64-linux-gnu %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=aarch64-linux-gnu %p/Inputs/aarch64-pac1.s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=aarch64-linux-gnu %p/Inputs/aarch64-func3.s -o %t2.o
# RUN: llvm-mc -filetype=obj -triple=aarch64-linux-gnu %p/Inputs/aarch64-func3-pac.s -o %t3.o
# RUN: llvm-mc -filetype=obj -triple=aarch64-linux-gnu %p/Inputs/aarch64-func2.s -o %tno.o

## We do not add PAC support when the inputs don't have the .note.gnu.property
## field.

# RUN: ld.lld %tno.o %t3.o --shared -o %tno.so
# RUN: llvm-objdump -d -mattr=+v8.3a --no-show-raw-insn %tno.so | FileCheck --check-prefix=NOPAC %s
# RUN: llvm-readelf -x .got.plt %tno.so | FileCheck --check-prefix SOGOTPLT %s
# RUN: llvm-readelf --dynamic-table %tno.so | FileCheck --check-prefix NOPACDYN %s

# NOPAC: 0000000000010000 func2:
# NOPAC-NEXT:    10000: bl      #48 <func3@plt>
# NOPAC-NEXT:    10004: ret
# NOPAC: Disassembly of section .plt:
# NOPAC: 0000000000010010 .plt:
# NOPAC-NEXT:    10010: stp     x16, x30, [sp, #-16]!
# NOPAC-NEXT:    10014: adrp    x16, #131072
# NOPAC-NEXT:    10018: ldr     x17, [x16, #16]
# NOPAC-NEXT:    1001c: add     x16, x16, #16
# NOPAC-NEXT:    10020: br      x17
# NOPAC-NEXT:    10024: nop
# NOPAC-NEXT:    10028: nop
# NOPAC-NEXT:    1002c: nop
# NOPAC: 0000000000010030 func3@plt:
# NOPAC-NEXT:    10030: adrp    x16, #131072
# NOPAC-NEXT:    10034: ldr     x17, [x16, #24]
# NOPAC-NEXT:    10038: add     x16, x16, #24
# NOPAC-NEXT:    1003c: br      x17

# NOPACDYN-NOT:   0x0000000070000001 (AARCH64_BTI_PLT)
# NOPACDYN-NOT:   0x0000000070000003 (AARCH64_PAC_PLT)

# RUN: ld.lld %t1.o %t3.o --shared -o %t.so
# RUN: llvm-readelf -n %t.so | FileCheck --check-prefix PACPROP %s
# RUN: llvm-objdump -d -mattr=+v8.3a --no-show-raw-insn %t.so | FileCheck --check-prefix PACSO %s
# RUN: llvm-readelf -x .got.plt %t.so | FileCheck --check-prefix SOGOTPLT %s
# RUN: llvm-readelf --dynamic-table %t.so |  FileCheck --check-prefix PACDYN %s

## PAC has no effect on PLT[0], for PLT[N] autia1716 is used to authenticate
## the address in x17 (context in x16) before branching to it. The dynamic
## loader is responsible for calling pacia1716 on the entry.
# PACSO: 0000000000010000 func2:
# PACSO-NEXT:    10000: bl      #48 <func3@plt>
# PACSO-NEXT:    10004: ret
# PACSO: Disassembly of section .plt:
# PACSO: 0000000000010010 .plt:
# PACSO-NEXT:    10010: stp     x16, x30, [sp, #-16]!
# PACSO-NEXT:    10014: adrp    x16, #131072
# PACSO-NEXT:    10018: ldr     x17, [x16, #16]
# PACSO-NEXT:    1001c: add     x16, x16, #16
# PACSO-NEXT:    10020: br      x17
# PACSO-NEXT:    10024: nop
# PACSO-NEXT:    10028: nop
# PACSO-NEXT:    1002c: nop
# PACSO: 0000000000010030 func3@plt:
# PACSO-NEXT:    10030: adrp    x16, #131072
# PACSO-NEXT:    10034: ldr     x17, [x16, #24]
# PACSO-NEXT:    10038: add     x16, x16, #24
# PACSO-NEXT:    1003c: autia1716
# PACSO-NEXT:    10040: br      x17
# PACSO-NEXT:    10044: nop

# The .got.plt should be identical between the PAC and no PAC DSO PLT.
# SOGOTPLT: Hex dump of section '.got.plt':
# SOGOTPLT-NEXT: 0x00030000 00000000 00000000 00000000 00000000
# SOGOTPLT-NEXT: 0x00030010 00000000 00000000 10000100 00000000

# PACPROP: Properties:    aarch64 feature: PAC

# PACDYN-NOT:      0x0000000070000001 (AARCH64_BTI_PLT)
# PACDYN:          0x0000000070000003 (AARCH64_PAC_PLT)

## Turn on PAC entries with the --pac-plt command line option. There are no
## warnings in this case as the choice to use PAC in PLT entries is orthogonal
## to the choice of using PAC in relocatable objects. The presence of the PAC
## .note.gnu.property is an indication of preference by the relocatable object.

# RUN: ld.lld %t.o %t2.o --pac-plt %t.so -o %tpacplt.exe
# RUN: llvm-readelf -n %tpacplt.exe | FileCheck --check-prefix=PACPROP %s
# RUN: llvm-readelf --dynamic-table %tpacplt.exe | FileCheck --check-prefix PACDYN %s
# RUN: llvm-objdump -d -mattr=+v8.3a --no-show-raw-insn %tpacplt.exe | FileCheck --check-prefix PACPLT %s

# PACPLT: Disassembly of section .text:
# PACPLT: 0000000000210000 func1:
# PACPLT-NEXT:   210000: bl      #48 <func2@plt>
# PACPLT-NEXT:   210004: ret
# PACPLT: 0000000000210008 func3:
# PACPLT-NEXT:   210008: ret
# PACPLT: Disassembly of section .plt:
# PACPLT: 0000000000210010 .plt:
# PACPLT-NEXT:   210010: stp     x16, x30, [sp, #-16]!
# PACPLT-NEXT:   210014: adrp    x16, #131072
# PACPLT-NEXT:   210018: ldr     x17, [x16, #16]
# PACPLT-NEXT:   21001c: add     x16, x16, #16
# PACPLT-NEXT:   210020: br      x17
# PACPLT-NEXT:   210024: nop
# PACPLT-NEXT:   210028: nop
# PACPLT-NEXT:   21002c: nop
# PACPLT: 0000000000210030 func2@plt:
# PACPLT-NEXT:   210030: adrp    x16, #131072
# PACPLT-NEXT:   210034: ldr     x17, [x16, #24]
# PACPLT-NEXT:   210038: add     x16, x16, #24
# PACPLT-NEXT:   21003c: autia1716
# PACPLT-NEXT:   210040: br      x17
# PACPLT-NEXT:   210044: nop


.section ".note.gnu.property", "a"
.long 4
.long 0x10
.long 0x5
.asciz "GNU"

.long 0xc0000000 // GNU_PROPERTY_AARCH64_FEATURE_1_AND
.long 4
.long 2          // GNU_PROPERTY_AARCH64_FEATURE_1_PAC
.long 0

.text
.globl _start
.type func1,%function
func1:
  bl func2
  ret
