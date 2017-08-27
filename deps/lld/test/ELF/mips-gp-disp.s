# Check that even if _gp_disp symbol is defined in the shared library
# we use our own value.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o
# RUN: ld.lld -shared -o %t.so %t.o %S/Inputs/mips-gp-disp.so
# RUN: llvm-readobj -symbols %t.so | FileCheck -check-prefix=INT-SO %s
# RUN: llvm-readobj -symbols %S/Inputs/mips-gp-disp.so \
# RUN:   | FileCheck -check-prefix=EXT-SO %s
# RUN: llvm-objdump -d -t %t.so | FileCheck -check-prefix=DIS %s
# RUN: llvm-readobj -relocations %t.so | FileCheck -check-prefix=REL %s

# REQUIRES: mips

# INT-SO:      Name: _gp_disp
# INT-SO-NEXT: Value:
# INT-SO-NEXT: Size:
# INT-SO-NEXT: Binding: Local

# EXT-SO:      Name: _gp_disp
# EXT-SO-NEXT: Value: 0x20000

# DIS:      Disassembly of section .text:
# DIS-NEXT: __start:
# DIS-NEXT:    10000:  3c 08 00 01  lui   $8, 1
# DIS-NEXT:    10004:  21 08 7f f0  addi  $8, $8, 32752
#                                                 ^-- 0x37ff0 & 0xffff
# DIS: 00027ff0  *ABS*  00000000 .hidden _gp

# REL:      Relocations [
# REL-NEXT: ]

  .text
  .globl  __start
__start:
  lui    $t0,%hi(_gp_disp)
  addi   $t0,$t0,%lo(_gp_disp)
  lw     $v0,%call16(_foo)($gp)
