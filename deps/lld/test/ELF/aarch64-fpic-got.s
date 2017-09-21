# REQUIRES: aarch64

# RUN: llvm-mc -filetype=obj -triple=aarch64-none-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=aarch64-none-linux %p/Inputs/shared.s -o %t-lib.o
# RUN: ld.lld -shared %t-lib.o -o %t-lib.so
# RUN: ld.lld %t-lib.so %t.o -o %t.exe
# RUN: llvm-readobj -dyn-relocations %t.exe | FileCheck %s

## Checks if got access to dynamic objects is done through a got relative
## dynamic relocation and not using plt relative (R_AARCH64_JUMP_SLOT).
# CHECK:       Dynamic Relocations {
# CHECK-NEXT:    0x{{[0-9A-F]+}}  R_AARCH64_GLOB_DAT bar 0x0
# CHECK-NEXT:  }

.globl _start
_start:
  adrp x0, :got:bar
  ldr  x0, [x0, :got_lo12:bar]
