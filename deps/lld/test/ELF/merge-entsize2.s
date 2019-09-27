# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64 %s -o %t.o

# RUN: ld.lld %t.o -o %t
# RUN: llvm-readelf -S %t | FileCheck --check-prefix=SEC %s
# RUN: llvm-readelf -x .cst %t | FileCheck --check-prefix=HEX %s

# RUN: ld.lld -O0 -r %t.o -o %t1.o
# RUN: llvm-readelf -S %t1.o | FileCheck --check-prefix=SEC-R %s
# RUN: llvm-readelf -x .cst %t1.o | FileCheck --check-prefix=HEX-R %s

## Check that SHF_MERGE sections with the same name, sh_flags and sh_entsize
## are grouped together and can be merged within the group.

## .cst 0 and .cst 1 are merged (sh_entsize=4). The result and .cst 2 and
## combined (sh_entsize=8). The output sh_entsize is 0.
# SEC:   Name  Type     {{.*}} Size   ES Flg Lk Inf Al
# SEC:   .cst  PROGBITS {{.*}} 000020 00  AM  0   0  8

## .cst 0 and .cst 1 are merged, but emitted as a separate output section.
# SEC-R: .cst  PROGBITS {{.*}} 00000c 04  AM  0   0  4
# SEC-R: .cst  PROGBITS {{.*}} 000010 08  AM  0   0  8

# HEX:      Hex dump of section '.cst':
# HEX-NEXT: 0x{{[0-9a-f]+}} 01000000 00000000 02000000 00000000
# HEX-NEXT: 0x{{[0-9a-f]+}} 01000000 00000000 03000000 00000000

# HEX-R:      Hex dump of section '.cst':
# HEX-R-NEXT: 0x00000000 01000000 00000000 02000000
# HEX-R-EMPTY:
# HEX-R-NEXT: Hex dump of section '.cst':
# HEX-R-NEXT: 0x00000000 01000000 00000000 03000000 00000000

.section .cst,"aM",@progbits,4,unique,0
.align 2
.long 1
.long 0
.long 2

.section .cst,"aM",@progbits,4,unique,1
.align 4
.long 1
.long 0
.long 2

.section .cst,"aM",@progbits,8,unique,2
.align 8
.quad 1
.quad 3
