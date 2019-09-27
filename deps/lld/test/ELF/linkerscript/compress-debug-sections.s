# REQUIRES: x86, zlib

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux \
# RUN:   %S/Inputs/compress-debug-sections.s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t2.o

## .debug_str section is mergeable. LLD would combine all of them into single
## mergeable synthetic section. We use -O0 here to disable merging, that
## allows to check that input sections has correctly assigned offsets.

# RUN: echo "SECTIONS { }" > %t.script
# RUN: ld.lld -O0 %t1.o %t2.o %t.script -o %t1 --compress-debug-sections=zlib
# RUN: llvm-dwarfdump -a %t1 | FileCheck %s
# RUN: llvm-readobj -S %t1 | FileCheck %s --check-prefix=ZLIBFLAGS

# RUN: echo "SECTIONS { .debug_str 0 : { *(.debug_str) } }" > %t2.script
# RUN: ld.lld -O0 %t1.o %t2.o %t2.script -o %t2 --compress-debug-sections=zlib
# RUN: llvm-dwarfdump -a %t2 | FileCheck %s
# RUN: llvm-readobj -S %t2 | FileCheck %s --check-prefix=ZLIBFLAGS

# CHECK:       .debug_str contents:
# CHECK-NEXT:    CCC
# CHECK-NEXT:    DDD
# CHECK-NEXT:    AAA
# CHECK-NEXT:    BBB

# ZLIBFLAGS:       Section {
# ZLIBFLAGS:         Index:
# ZLIBFLAGS:         Name: .debug_str
# ZLIBFLAGS-NEXT:    Type: SHT_PROGBITS
# ZLIBFLAGS-NEXT:    Flags [
# ZLIBFLAGS-NEXT:      SHF_COMPRESSED

.section .debug_str
  .asciz "AAA"
  .asciz "BBB"
