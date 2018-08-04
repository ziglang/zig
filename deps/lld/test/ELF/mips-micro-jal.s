# REQUIRES: mips
# Check PLT creation for microMIPS to microMIPS calls.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         -mattr=micromips %S/Inputs/mips-micro.s -o %t1eb.o
# RUN: ld.lld -shared -o %teb.so %t1eb.o
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         -mattr=micromips %s -o %t2eb.o
# RUN: ld.lld -o %teb.exe %t2eb.o %teb.so
# RUN: llvm-objdump -d -mattr=micromips %teb.exe | FileCheck --check-prefix=EB %s
# RUN: llvm-readobj -mips-plt-got %teb.exe | FileCheck --check-prefix=PLT %s

# RUN: llvm-mc -filetype=obj -triple=mipsel-unknown-linux \
# RUN:         -mattr=micromips %S/Inputs/mips-micro.s -o %t1el.o
# RUN: ld.lld -shared -o %tel.so %t1el.o
# RUN: llvm-mc -filetype=obj -triple=mipsel-unknown-linux \
# RUN:         -mattr=micromips %s -o %t2el.o
# RUN: ld.lld -o %tel.exe %t2el.o %tel.so
# RUN: llvm-objdump -d -mattr=micromips %tel.exe | FileCheck --check-prefix=EL %s
# RUN: llvm-readobj -mips-plt-got %tel.exe | FileCheck --check-prefix=PLT %s

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         -mattr=micromips -mcpu=mips32r6 %S/Inputs/mips-micro.s -o %t1eb.o
# RUN: ld.lld -shared -o %teb.so %t1eb.o
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         -mattr=micromips -mcpu=mips32r6 %s -o %t2eb.o
# RUN: ld.lld -o %teb.exe %t2eb.o %teb.so
# RUN: llvm-objdump -d -mattr=micromips %teb.exe | FileCheck --check-prefix=EBR6 %s

# RUN: llvm-mc -filetype=obj -triple=mipsel-unknown-linux \
# RUN:         -mattr=micromips -mcpu=mips32r6 %S/Inputs/mips-micro.s -o %t1el.o
# RUN: ld.lld -shared -o %tel.so %t1el.o
# RUN: llvm-mc -filetype=obj -triple=mipsel-unknown-linux \
# RUN:         -mattr=micromips -mcpu=mips32r6 %s -o %t2el.o
# RUN: ld.lld -o %tel.exe %t2el.o %tel.so
# RUN: llvm-objdump -d -mattr=micromips %tel.exe | FileCheck --check-prefix=ELR6 %s

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         -mattr=micromips %S/Inputs/mips-micro.s -o %t1eb.o
# RUN: ld.lld -shared -o %teb.so %t1eb.o
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         %S/Inputs/mips-fpic.s -o %t-reg.o
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         -mattr=micromips %s -o %t2eb.o
# RUN: ld.lld --no-threads -o %teb.exe %t-reg.o %t2eb.o %teb.so
# RUN: llvm-objdump -d -mattr=micromips %teb.exe \
# RUN:   | FileCheck --check-prefix=MIXED %s

# EB:      Disassembly of section .plt:
# EB-NEXT: .plt:
# EB-NEXT:    20010:       79 80 3f fd     addiupc $3, 65524
# EB-NEXT:    20014:       ff 23 00 00     lw      $25, 0($3)
# EB-NEXT:    20018:       05 35           subu16  $2, $2, $3
# EB-NEXT:    2001a:       25 25           srl16   $2, $2, 2
# EB-NEXT:    2001c:       33 02 ff fe     addiu   $24, $2, -2
# EB-NEXT:    20020:       0d ff           move    $15, $ra
# EB-NEXT:    20022:       45 f9           jalrs16 $25
# EB-NEXT:    20024:       0f 83           move    $gp, $3
# EB-NEXT:    20026:       0c 00           nop
# EB-NEXT:    20028:       00 00 00 00     nop
# EB-NEXT:    2002c:       00 00 00 00     nop

# EB-NEXT:    20030:       79 00 3f f7     addiupc $2, 65500
# EB-NEXT:    20034:       ff 22 00 00     lw      $25, 0($2)
# EB-NEXT:    20038:       45 99           jr16    $25
# EB-NEXT:    2003a:       0f 02           move    $24, $2

# EL:      Disassembly of section .plt:
# EL-NEXT: .plt:
# EL-NEXT:    20010:       80 79 fd 3f     addiupc $3, 65524
# EL-NEXT:    20014:       23 ff 00 00     lw      $25, 0($3)
# EL-NEXT:    20018:       35 05           subu16  $2, $2, $3
# EL-NEXT:    2001a:       25 25           srl16   $2, $2, 2
# EL-NEXT:    2001c:       02 33 fe ff     addiu   $24, $2, -2
# EL-NEXT:    20020:       ff 0d           move    $15, $ra
# EL-NEXT:    20022:       f9 45           jalrs16 $25
# EL-NEXT:    20024:       83 0f           move    $gp, $3
# EL-NEXT:    20026:       00 0c           nop
# EL-NEXT:    20028:       00 00 00 00     nop
# EL-NEXT:    2002c:       00 00 00 00     nop

# EL-NEXT:    20030:       00 79 f7 3f     addiupc $2, 65500
# EL-NEXT:    20034:       22 ff 00 00     lw      $25, 0($2)
# EL-NEXT:    20038:       99 45           jr16    $25
# EL-NEXT:    2003a:       02 0f           move    $24, $2

# EBR6:      Disassembly of section .plt:
# EBR6-NEXT: .plt:
# EBR6-NEXT:    20010:       78 60 3f fd     lapc    $3, 65524
# EBR6-NEXT:    20014:       ff 23 00 00     lw      $25, 0($3)
# EBR6-NEXT:    20018:       05 35           subu16  $2, $2, $3
# EBR6-NEXT:    2001a:       25 25           srl16   $2, $2, 2
# EBR6-NEXT:    2001c:       33 02 ff fe     addiu   $24, $2, -2
# EBR6-NEXT:    20020:       0d ff           move16  $15, $ra
# EBR6-NEXT:    20022:       0f 83           move16  $gp, $3
# EBR6-NEXT:    20024:       47 2b           jalr    $25

# EBR6:         20030:       78 40 3f f7     lapc    $2, 65500
# EBR6-NEXT:    20034:       ff 22 00 00     lw      $25, 0($2)
# EBR6-NEXT:    20038:       0f 02           move16  $24, $2
# EBR6-NEXT:    2003a:       47 23           jrc16   $25

# ELR6:      Disassembly of section .plt:
# ELR6-NEXT: .plt:
# ELR6-NEXT:    20010:       60 78 fd 3f     lapc    $3, 65524
# ELR6-NEXT:    20014:       23 ff 00 00     lw      $25, 0($3)
# ELR6-NEXT:    20018:       35 05           subu16  $2, $2, $3
# ELR6-NEXT:    2001a:       25 25           srl16   $2, $2, 2
# ELR6-NEXT:    2001c:       02 33 fe ff     addiu   $24, $2, -2
# ELR6-NEXT:    20020:       ff 0d           move16  $15, $ra
# ELR6-NEXT:    20022:       83 0f           move16  $gp, $3
# ELR6-NEXT:    20024:       2b 47           jalr    $25

# ELR6:         20030:       40 78 f7 3f     lapc    $2, 65500
# ELR6-NEXT:    20034:       22 ff 00 00     lw      $25, 0($2)
# ELR6-NEXT:    20038:       02 0f           move16  $24, $2
# ELR6-NEXT:    2003a:       23 47           jrc16   $25

# MIXED:      Disassembly of section .plt:
# MIXED-NEXT: .plt:
# MIXED-NEXT:    20020:       79 80 3f f9     addiupc $3, 65508
# MIXED-NEXT:    20024:       ff 23 00 00     lw      $25, 0($3)
# MIXED-NEXT:    20028:       05 35           subu16  $2, $2, $3
# MIXED-NEXT:    2002a:       25 25           srl16   $2, $2, 2
# MIXED-NEXT:    2002c:       33 02 ff fe     addiu   $24, $2, -2
# MIXED-NEXT:    20030:       0d ff           move    $15, $ra
# MIXED-NEXT:    20032:       45 f9           jalrs16 $25
# MIXED-NEXT:    20034:       0f 83           move    $gp, $3
# MIXED-NEXT:    20036:       0c 00           nop
# MIXED-NEXT:    20038:       00 00 00 00     nop
# MIXED-NEXT:    2003c:       00 00 00 00     nop

# MIXED-NEXT:    20040:       79 00 3f f3     addiupc $2, 65484
# MIXED-NEXT:    20044:       ff 22 00 00     lw      $25, 0($2)
# MIXED-NEXT:    20048:       45 99           jr16    $25
# MIXED-NEXT:    2004a:       0f 02           move    $24, $2

# PLT:      Entries [
# PLT-NEXT:   Entry {
# PLT-NEXT:     Address: 0x3000C
#                        ^ 0x20030 + 65500
# PLT-NEXT:     Initial:
# PLT-NEXT:     Value: 0x0
# PLT-NEXT:     Type: Function
# PLT-NEXT:     Section: Undefined
# PLT-NEXT:     Name: foo
# PLT-NEXT:   }
# PLT-NEXT: ]

  .text
  .set micromips
  .global __start
__start:
  jal foo
