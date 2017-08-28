# Check handling multiple MIPS N64 ABI relocations packed
# into the single relocation record.

# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t.exe
# RUN: llvm-objdump -d -s -t %t.exe | FileCheck %s
# RUN: llvm-readobj -r %t.exe | FileCheck -check-prefix=REL %s

# REQUIRES: mips

# CHECK:      __start:
# CHECK-NEXT:    20000:   3c 1c 00 01   lui     $gp, 1
#                                                    ^-- 0x20000 - 0x37ff0
#                                                    ^-- 0 - 0xfffffffffffe8010
#                                                    ^-- %hi(0x17ff0)
# CHECK:      loc:
# CHECK-NEXT:    20004:   67 9c 7f f0   daddiu  $gp, $gp, 32752
#                                                    ^-- 0x20000 - 0x37ff0
#                                                    ^-- 0 - 0xfffffffffffe8010
#                                                    ^-- %lo(0x17ff0)

# CHECK:      Contents of section .rodata:
# CHECK-NEXT:  10158 ffffffff fffe8014
#                    ^-- 0x20004 - 0x37ff0 = 0xfffffffffffe8014

# CHECK: 0000000000020004   .text   00000000 loc
# CHECK: 0000000000037ff0   *ABS*   00000000 .hidden _gp
# CHECK: 0000000000020000   .text   00000000 __start

# REL:      Relocations [
# REL-NEXT: ]

  .text
  .global  __start
__start:
  lui     $gp,%hi(%neg(%gp_rel(__start)))     # R_MIPS_GPREL16
                                              # R_MIPS_SUB
                                              # R_MIPS_HI16
loc:
  daddiu  $gp,$gp,%lo(%neg(%gp_rel(__start))) # R_MIPS_GPREL16
                                              # R_MIPS_SUB
                                              # R_MIPS_LO16

  .section  .rodata,"a",@progbits
  .gpdword(loc)                               # R_MIPS_GPREL32
                                              # R_MIPS_64
