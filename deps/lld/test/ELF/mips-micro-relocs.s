# REQUIRES: mips
# Check handling of microMIPS relocations.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         -mattr=micromips %S/Inputs/mips-micro.s -o %t1eb.o
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         -mattr=micromips %s -o %t2eb.o
# RUN: ld.lld -o %teb.exe %t1eb.o %t2eb.o
# RUN: llvm-objdump -d -t -mattr=micromips %teb.exe \
# RUN:   | FileCheck --check-prefixes=EB,SYM %s

# RUN: llvm-mc -filetype=obj -triple=mipsel-unknown-linux \
# RUN:         -mattr=micromips %S/Inputs/mips-micro.s -o %t1el.o
# RUN: llvm-mc -filetype=obj -triple=mipsel-unknown-linux \
# RUN:         -mattr=micromips %s -o %t2el.o
# RUN: ld.lld -o %tel.exe %t1el.o %t2el.o
# RUN: llvm-objdump -d -t -mattr=micromips %tel.exe \
# RUN:   | FileCheck --check-prefixes=EL,SYM %s

# EB:      __start:
# EB-NEXT:      20010:       41 a3 00 01     lui     $3, 1
# EB-NEXT:      20014:       30 63 7f df     addiu   $3, $3, 32735
# EB-NEXT:      20018:       fc 7c 80 18     lw      $3, -32744($gp)
# EB-NEXT:      2001c:       fc 63 80 18     lw      $3, -32744($3)
# EB-NEXT:      20020:       8f 70           beqz16  $6, -32
# EB-NEXT:      20022:       00 7e 00 00     sll     $3, $fp, 0
# EB-NEXT:      20026:       cf ec           b16     -40
# EB-NEXT:      20028:       00 00 00 00     nop
# EB-NEXT:      2002c:       94 00 ff e8     b       -44

# EL:      __start:
# EL-NEXT:      20010:       a3 41 01 00     lui     $3, 1
# EL-NEXT:      20014:       63 30 df 7f     addiu   $3, $3, 32735
# EL-NEXT:      20018:       7c fc 18 80     lw      $3, -32744($gp)
# EL-NEXT:      2001c:       63 fc 18 80     lw      $3, -32744($3)
# EL-NEXT:      20020:       70 8f           beqz16  $6, -32
# EL-NEXT:      20022:       7e 00 00 00     sll     $3, $fp, 0
# EL-NEXT:      20026:       ec cf           b16     -40
# EL-NEXT:      20028:       00 00 00 00     nop
# EL-NEXT:      2002c:       00 94 e8 ff     b       -44

# SYM: 00037ff0         .got            00000000 .hidden _gp
# SYM: 00020000 g F     .text           00000000 foo
# SYM: 00020010         .text           00000000 __start

  .text
  .set micromips
  .global __start
__start:
  lui     $3, %hi(_gp_disp)       # R_MICROMIPS_HI16
  addiu   $3, $3, %lo(_gp_disp)   # R_MICROMIPS_LO16

  lw      $3, %call16(foo)($gp)   # R_MICROMIPS_CALL16
  lw      $3, %got(foo)($3)       # R_MICROMIPS_GOT16

  beqz16  $6, foo                 # R_MICROMIPS_PC7_S1
  b16     foo                     # R_MICROMIPS_PC10_S1
  b       foo                     # R_MICROMIPS_PC16_S1
