# REQUIRES: mips
# Check LA25 stubs creation. This stub code is necessary when
# non-PIC code calls PIC function.

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

# CHECK:     Disassembly of section .text:
# CHECK-NEXT: __start:
# CHECK-NEXT:    20000:       0c 00 80 0c     jal     131120 <__LA25Thunk_foo1a>
# CHECK-NEXT:    20004:       00 00 00 00     nop
# CHECK-NEXT:    20008:       0c 00 80 16     jal     131160 <__LA25Thunk_foo2>
# CHECK-NEXT:    2000c:       00 00 00 00     nop
# CHECK-NEXT:    20010:       0c 00 80 10     jal     131136 <__LA25Thunk_foo1b>
# CHECK-NEXT:    20014:       00 00 00 00     nop
# CHECK-NEXT:    20018:       0c 00 80 16     jal     131160 <__LA25Thunk_foo2>
# CHECK-NEXT:    2001c:       00 00 00 00     nop
# CHECK-NEXT:    20020:       0c 00 80 1d     jal     131188 <__LA25Thunk_fpic>
# CHECK-NEXT:    20024:       00 00 00 00     nop
# CHECK-NEXT:    20028:       0c 00 80 28     jal     131232 <fnpic>
# CHECK-NEXT:    2002c:       00 00 00 00     nop
#
# CHECK: __LA25Thunk_foo1a:
# CHECK-NEXT:    20030:       3c 19 00 02     lui     $25, 2
# CHECK-NEXT:    20034:       08 00 80 14     j       131152 <foo1a>
# CHECK-NEXT:    20038:       27 39 00 50     addiu   $25, $25, 80
# CHECK-NEXT:    2003c:       00 00 00 00     nop

# CHECK: __LA25Thunk_foo1b:
# CHECK-NEXT:    20040:       3c 19 00 02     lui     $25, 2
# CHECK-NEXT:    20044:       08 00 80 15     j       131156 <foo1b>
# CHECK-NEXT:    20048:       27 39 00 54     addiu   $25, $25, 84
# CHECK-NEXT:    2004c:       00 00 00 00     nop

# CHECK: foo1a:
# CHECK-NEXT:    20050:       00 00 00 00     nop

# CHECK: foo1b:
# CHECK-NEXT:    20054:       00 00 00 00     nop

# CHECK: __LA25Thunk_foo2:
# CHECK-NEXT:    20058:       3c 19 00 02     lui     $25, 2
# CHECK-NEXT:    2005c:       08 00 80 1c     j       131184 <foo2>
# CHECK-NEXT:    20060:       27 39 00 70     addiu   $25, $25, 112
# CHECK-NEXT:    20064:       00 00 00 00     nop
# CHECK-NEXT:    20068:       ef ef ef ef     <unknown>
# CHECK-NEXT:    2006c:       ef ef ef ef     <unknown>

# CHECK: foo2:
# CHECK-NEXT:    20070:       00 00 00 00     nop

# CHECK: __LA25Thunk_fpic:
# CHECK-NEXT:    20074:       3c 19 00 02     lui     $25, 2
# CHECK-NEXT:    20078:       08 00 80 24     j       131216 <fpic>
# CHECK-NEXT:    2007c:       27 39 00 90     addiu   $25, $25, 144
# CHECK-NEXT:    20080:       00 00 00 00     nop
# CHECK-NEXT:    20084:       ef ef ef ef     <unknown>
# CHECK-NEXT:    20088:       ef ef ef ef     <unknown>
# CHECK-NEXT:    2008c:       ef ef ef ef     <unknown>

# CHECK: fpic:
# CHECK-NEXT:    20090:       00 00 00 00     nop
# CHECK-NEXT:    20094:       ef ef ef ef     <unknown>
# CHECK-NEXT:    20098:       ef ef ef ef     <unknown>
# CHECK-NEXT:    2009c:       ef ef ef ef     <unknown>

# CHECK: fnpic:
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
# REVERSE-NEXT:    20038:       ef ef ef ef     <unknown>
# REVERSE-NEXT:    2003c:       ef ef ef ef     <unknown>
# REVERSE: foo2:
# REVERSE-NEXT:    20040:       00 00 00 00     nop
# REVERSE-NEXT:    20044:       ef ef ef ef     <unknown>
# REVERSE-NEXT:    20048:       ef ef ef ef     <unknown>
# REVERSE-NEXT:    2004c:       ef ef ef ef     <unknown>
# REVERSE: __start:
# REVERSE-NEXT:    20050:       0c 00 80 00     jal     131072 <__LA25Thunk_foo1a>
# REVERSE-NEXT:    20054:       00 00 00 00     nop
# REVERSE-NEXT:    20058:       0c 00 80 0a     jal     131112 <__LA25Thunk_foo2>
# REVERSE-NEXT:    2005c:       00 00 00 00     nop
# REVERSE-NEXT:    20060:       0c 00 80 04     jal     131088 <__LA25Thunk_foo1b>
# REVERSE-NEXT:    20064:       00 00 00 00     nop
# REVERSE-NEXT:    20068:       0c 00 80 0a     jal     131112 <__LA25Thunk_foo2>
# REVERSE-NEXT:    2006c:       00 00 00 00     nop
# REVERSE-NEXT:    20070:       0c 00 80 20     jal     131200 <__LA25Thunk_fpic>
# REVERSE-NEXT:    20074:       00 00 00 00     nop
# REVERSE-NEXT:    20078:       0c 00 80 28     jal     131232 <fnpic>
# REVERSE-NEXT:    2007c:       00 00 00 00     nop
# REVERSE: __LA25Thunk_fpic:
# REVERSE-NEXT:    20080:       3c 19 00 02     lui     $25, 2
# REVERSE-NEXT:    20084:       08 00 80 24     j       131216 <fpic>
# REVERSE-NEXT:    20088:       27 39 00 90     addiu   $25, $25, 144
# REVERSE-NEXT:    2008c:       00 00 00 00     nop
# REVERSE: fpic:
# REVERSE-NEXT:    20090:       00 00 00 00     nop
# REVERSE-NEXT:    20094:       ef ef ef ef     <unknown>
# REVERSE-NEXT:    20098:       ef ef ef ef     <unknown>
# REVERSE-NEXT:    2009c:       ef ef ef ef     <unknown>
# REVERSE: fnpic:
# REVERSE-NEXT:    200a0:       00 00 00 00     nop

  .text
  .globl __start
__start:
  jal foo1a
  jal foo2
  jal foo1b
  jal foo2
  jal fpic
  jal fnpic
