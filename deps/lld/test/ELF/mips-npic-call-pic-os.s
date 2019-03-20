# REQUIRES: mips
# Check LA25 stubs creation with caller in different Output Section to callee.
# This stub code is necessary when non-PIC code calls PIC function.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:   %p/Inputs/mips-fpic.s -o %t-fpic.o
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:   %p/Inputs/mips-fnpic.s -o %t-fnpic.o
# RUN: ld.lld -r %t-fpic.o %t-fnpic.o -o %t-sto-pic.o
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:   %p/Inputs/mips-pic.s -o %t-pic.o
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t-npic.o
# RUN: ld.lld %t-npic.o %t-pic.o %t-sto-pic.o -o %t.exe
# RUN: llvm-objdump -d %t.exe | FileCheck %s

# CHECK: Disassembly of section .text:
# CHECK-NEXT: __LA25Thunk_foo1a:
# CHECK-NEXT:    20000:       3c 19 00 02     lui     $25, 2
# CHECK-NEXT:    20004:       08 00 80 08     j       131104 <foo1a>
# CHECK-NEXT:    20008:       27 39 00 20     addiu   $25, $25, 32
# CHECK-NEXT:    2000c:       00 00 00 00     nop

# CHECK: __LA25Thunk_foo1b:
# CHECK-NEXT:    20010:       3c 19 00 02     lui     $25, 2
# CHECK-NEXT:    20014:       08 00 80 09     j       131108 <foo1b>
# CHECK-NEXT:    20018:       27 39 00 24     addiu   $25, $25, 36
# CHECK-NEXT:    2001c:       00 00 00 00     nop

# CHECK: foo1a:
# CHECK-NEXT:    20020:       00 00 00 00     nop

# CHECK: foo1b:
# CHECK-NEXT:    20024:       00 00 00 00     nop

# CHECK: __LA25Thunk_foo2:
# CHECK-NEXT:    20028:       3c 19 00 02     lui     $25, 2
# CHECK-NEXT:    2002c:       08 00 80 10     j       131136 <foo2>
# CHECK-NEXT:    20030:       27 39 00 40     addiu   $25, $25, 64
# CHECK-NEXT:    20034:       00 00 00 00     nop

# CHECK: foo2:
# CHECK-NEXT:    20040:       00 00 00 00     nop

# CHECK: __LA25Thunk_fpic:
# CHECK-NEXT:    20044:       3c 19 00 02     lui     $25, 2
# CHECK-NEXT:    20048:       08 00 80 18     j       131168 <fpic>
# CHECK-NEXT:    2004c:       27 39 00 60     addiu   $25, $25, 96
# CHECK-NEXT:    20050:       00 00 00 00     nop

# CHECK: fpic:
# CHECK-NEXT:    20060:       00 00 00 00     nop

# CHECK: fnpic:
# CHECK-NEXT:    20070:       00 00 00 00     nop
# CHECK-NEXT: Disassembly of section differentos:
# CHECK-NEXT: __start:
# CHECK-NEXT:    20074:       0c 00 80 00     jal     131072 <__LA25Thunk_foo1a>
# CHECK-NEXT:    20078:       00 00 00 00     nop
# CHECK-NEXT:    2007c:       0c 00 80 0a     jal     131112 <__LA25Thunk_foo2>
# CHECK-NEXT:    20080:       00 00 00 00     nop
# CHECK-NEXT:    20084:       0c 00 80 04     jal     131088 <__LA25Thunk_foo1b>
# CHECK-NEXT:    20088:       00 00 00 00     nop
# CHECK-NEXT:    2008c:       0c 00 80 0a     jal     131112 <__LA25Thunk_foo2>
# CHECK-NEXT:    20090:       00 00 00 00     nop
# CHECK-NEXT:    20094:       0c 00 80 11     jal     131140 <__LA25Thunk_fpic>
# CHECK-NEXT:    20098:       00 00 00 00     nop
# CHECK-NEXT:    2009c:       0c 00 80 1c     jal     131184 <fnpic>
# CHECK-NEXT:    200a0:       00 00 00 00     nop

# Make sure the thunks are created properly no matter how
# objects are laid out.
#
# RUN: ld.lld %t-pic.o %t-npic.o %t-sto-pic.o -o %t.exe
# RUN: llvm-objdump -d %t.exe | FileCheck -check-prefix=REVERSE %s

# REVERSE: Disassembly of section .text:
# REVERSE-NEXT: __LA25Thunk_foo1a:
# REVERSE-NEXT:    20000:       3c 19 00 02     lui     $25, 2
# REVERSE-NEXT:    20004:       08 00 80 08     j       131104 <foo1a>
# REVERSE-NEXT:    20008:       27 39 00 20     addiu   $25, $25, 32
# REVERSE-NEXT:    2000c:       00 00 00 00     nop

# REVERSE: __LA25Thunk_foo1b:
# REVERSE-NEXT:    20010:       3c 19 00 02     lui     $25, 2
# REVERSE-NEXT:    20014:       08 00 80 09     j       131108 <foo1b>
# REVERSE-NEXT:    20018:       27 39 00 24     addiu   $25, $25, 36
# REVERSE-NEXT:    2001c:       00 00 00 00     nop

# REVERSE: foo1a:
# REVERSE-NEXT:    20020:       00 00 00 00     nop

# REVERSE: foo1b:
# REVERSE-NEXT:    20024:       00 00 00 00     nop

# REVERSE: __LA25Thunk_foo2:
# REVERSE-NEXT:    20028:       3c 19 00 02     lui     $25, 2
# REVERSE-NEXT:    2002c:       08 00 80 10     j       131136 <foo2>
# REVERSE-NEXT:    20030:       27 39 00 40     addiu   $25, $25, 64
# REVERSE-NEXT:    20034:       00 00 00 00     nop

# REVERSE: foo2:
# REVERSE-NEXT:    20040:       00 00 00 00     nop

# REVERSE: __LA25Thunk_fpic:
# REVERSE-NEXT:    20050:       3c 19 00 02     lui     $25, 2
# REVERSE-NEXT:    20054:       08 00 80 18     j       131168 <fpic>
# REVERSE-NEXT:    20058:       27 39 00 60     addiu   $25, $25, 96
# REVERSE-NEXT:    2005c:       00 00 00 00     nop

# REVERSE: fpic:
# REVERSE-NEXT:    20060:       00 00 00 00     nop

# REVERSE: fnpic:
# REVERSE-NEXT:    20070:       00 00 00 00     nop

# REVERSE: Disassembly of section differentos:
# REVERSE-NEXT: __start:
# REVERSE-NEXT:    20074:       0c 00 80 00     jal     131072 <__LA25Thunk_foo1a>
# REVERSE-NEXT:    20078:       00 00 00 00     nop
# REVERSE-NEXT:    2007c:       0c 00 80 0a     jal     131112 <__LA25Thunk_foo2>
# REVERSE-NEXT:    20080:       00 00 00 00     nop
# REVERSE-NEXT:    20084:       0c 00 80 04     jal     131088 <__LA25Thunk_foo1b>
# REVERSE-NEXT:    20088:       00 00 00 00     nop
# REVERSE-NEXT:    2008c:       0c 00 80 0a     jal     131112 <__LA25Thunk_foo2>
# REVERSE-NEXT:    20090:       00 00 00 00     nop
# REVERSE-NEXT:    20094:       0c 00 80 14     jal     131152 <__LA25Thunk_fpic>
# REVERSE-NEXT:    20098:       00 00 00 00     nop
# REVERSE-NEXT:    2009c:       0c 00 80 1c     jal     131184 <fnpic>
# REVERSE-NEXT:    200a0:       00 00 00 00     nop

  .section differentos, "ax", %progbits
  .globl __start
__start:
  jal foo1a
  jal foo2
  jal foo1b
  jal foo2
  jal fpic
  jal fnpic
