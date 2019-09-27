# REQUIRES: mips
# Check LA25 stubs creation. This stub code is necessary when
# non-PIC code calls PIC function.
# RUN: echo "SECTIONS { .out 0x20000 : { *(.text.*) . = . + 0x100 ;  *(.text) }  }" > %t1.script
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:   %p/Inputs/mips-fpic.s -o %t-fpic.o
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:   %p/Inputs/mips-fnpic.s -o %t-fnpic.o
# RUN: ld.lld -r %t-fpic.o %t-fnpic.o -o %t-sto-pic.o
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:   %p/Inputs/mips-pic.s -o %t-pic.o
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t-npic.o
# RUN: ld.lld --script %t1.script %t-npic.o %t-pic.o %t-sto-pic.o -o %t.exe
# RUN: llvm-objdump -d %t.exe | FileCheck %s

# CHECK: Disassembly of section .out:
# CHECK-EMPTY:
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

# CHECK: __start:
# CHECK-NEXT:    20150:       0c 00 80 00     jal     131072 <__LA25Thunk_foo1a>
# CHECK-NEXT:    20154:       00 00 00 00     nop
# CHECK-NEXT:    20158:       0c 00 80 0a     jal     131112 <__LA25Thunk_foo2>
# CHECK-NEXT:    2015c:       00 00 00 00     nop
# CHECK-NEXT:    20160:       0c 00 80 04     jal     131088 <__LA25Thunk_foo1b>
# CHECK-NEXT:    20164:       00 00 00 00     nop
# CHECK-NEXT:    20168:       0c 00 80 0a     jal     131112 <__LA25Thunk_foo2>
# CHECK-NEXT:    2016c:       00 00 00 00     nop
# CHECK-NEXT:    20170:       0c 00 80 60     jal     131456 <__LA25Thunk_fpic>
# CHECK-NEXT:    20174:       00 00 00 00     nop
# CHECK-NEXT:    20178:       0c 00 80 68     jal     131488 <fnpic>
# CHECK-NEXT:    2017c:       00 00 00 00     nop

# CHECK: __LA25Thunk_fpic:
# CHECK-NEXT:    20180:       3c 19 00 02     lui     $25, 2
# CHECK-NEXT:    20184:       08 00 80 64     j       131472 <fpic>
# CHECK-NEXT:    20188:       27 39 01 90     addiu   $25, $25, 400
# CHECK-NEXT:    2018c:       00 00 00 00     nop

# CHECK: fpic:
# CHECK-NEXT:    20190:       00 00 00 00     nop

# CHECK: fnpic:
# CHECK-NEXT:    201a0:       00 00 00 00     nop

  .text
  .globl __start
__start:
  jal foo1a
  jal foo2
  jal foo1b
  jal foo2
  jal fpic
  jal fnpic

# Test script with orphans added to existing OutputSection, the .text.1 and
# .text.2 sections will be added to .text
# RUN: echo "SECTIONS { .text 0x20000 : { *(.text) }  }" > %t2.script
# RUN: ld.lld --script %t2.script %t-npic.o %t-pic.o %t-sto-pic.o -o %t2.exe
# RUN: llvm-objdump -d %t2.exe | FileCheck -check-prefix=ORPH1 %s

# ORPH1: Disassembly of section .text:
# ORPH1-EMPTY:
# ORPH1-NEXT: __start:
# ORPH1-NEXT:    20000:       0c 00 80 15     jal     131156 <__LA25Thunk_foo1a>
# ORPH1-NEXT:    20004:       00 00 00 00     nop
# ORPH1-NEXT:    20008:       0c 00 80 22     jal     131208 <__LA25Thunk_foo2>
# ORPH1-NEXT:    2000c:       00 00 00 00     nop
# ORPH1-NEXT:    20010:       0c 00 80 19     jal     131172 <__LA25Thunk_foo1b>
# ORPH1-NEXT:    20014:       00 00 00 00     nop
# ORPH1-NEXT:    20018:       0c 00 80 22     jal     131208 <__LA25Thunk_foo2>
# ORPH1-NEXT:    2001c:       00 00 00 00     nop
# ORPH1-NEXT:    20020:       0c 00 80 0c     jal     131120 <__LA25Thunk_fpic>
# ORPH1-NEXT:    20024:       00 00 00 00     nop
# ORPH1-NEXT:    20028:       0c 00 80 14     jal     131152 <fnpic>
# ORPH1-NEXT:    2002c:       00 00 00 00     nop

# ORPH1: __LA25Thunk_fpic:
# ORPH1-NEXT:    20030:       3c 19 00 02     lui     $25, 2
# ORPH1-NEXT:    20034:       08 00 80 10     j       131136 <fpic>
# ORPH1-NEXT:    20038:       27 39 00 40     addiu   $25, $25, 64
# ORPH1-NEXT:    2003c:       00 00 00 00     nop

# ORPH1: fpic:
# ORPH1-NEXT:    20040:       00 00 00 00     nop

# ORPH1: fnpic:
# ORPH1-NEXT:    20050:       00 00 00 00     nop

# ORPH1: __LA25Thunk_foo1a:
# ORPH1-NEXT:    20054:       3c 19 00 02     lui     $25, 2
# ORPH1-NEXT:    20058:       08 00 80 20     j       131200 <foo1a>
# ORPH1-NEXT:    2005c:       27 39 00 80     addiu   $25, $25, 128
# ORPH1-NEXT:    20060:       00 00 00 00     nop

# ORPH1: __LA25Thunk_foo1b:
# ORPH1-NEXT:    20064:       3c 19 00 02     lui     $25, 2
# ORPH1-NEXT:    20068:       08 00 80 21     j       131204 <foo1b>
# ORPH1-NEXT:    2006c:       27 39 00 84     addiu   $25, $25, 132
# ORPH1-NEXT:    20070:       00 00 00 00     nop

# ORPH1: foo1a:
# ORPH1-NEXT:    20080:       00 00 00 00     nop

# ORPH1: foo1b:
# ORPH1-NEXT:    20084:       00 00 00 00     nop

# ORPH1: __LA25Thunk_foo2:
# ORPH1-NEXT:    20088:       3c 19 00 02     lui     $25, 2
# ORPH1-NEXT:    2008c:       08 00 80 28     j       131232 <foo2>
# ORPH1-NEXT:    20090:       27 39 00 a0     addiu   $25, $25, 160
# ORPH1-NEXT:    20094:       00 00 00 00     nop

# ORPH1: foo2:
# ORPH1-NEXT:    200a0:       00 00 00 00     nop

# Test script with orphans added to new OutputSection, the .text.1 and
# .text.2 sections will form a new OutputSection .text
# RUN: echo "SECTIONS { .out 0x20000 : { *(.text) }  }" > %t3.script
# RUN: ld.lld --script %t3.script %t-npic.o %t-pic.o %t-sto-pic.o -o %t3.exe
# RUN: llvm-objdump -d %t3.exe | FileCheck -check-prefix=ORPH2 %s

# ORPH2: Disassembly of section .out:
# ORPH2-EMPTY:
# ORPH2-NEXT: __start:
# ORPH2-NEXT:    20000:       0c 00 80 18     jal     131168 <__LA25Thunk_foo1a>
# ORPH2-NEXT:    20004:       00 00 00 00     nop
# ORPH2-NEXT:    20008:       0c 00 80 22     jal     131208 <__LA25Thunk_foo2>
# ORPH2-NEXT:    2000c:       00 00 00 00     nop
# ORPH2-NEXT:    20010:       0c 00 80 1c     jal     131184 <__LA25Thunk_foo1b>
# ORPH2-NEXT:    20014:       00 00 00 00     nop
# ORPH2-NEXT:    20018:       0c 00 80 22     jal     131208 <__LA25Thunk_foo2>
# ORPH2-NEXT:    2001c:       00 00 00 00     nop
# ORPH2-NEXT:    20020:       0c 00 80 0c     jal     131120 <__LA25Thunk_fpic>
# ORPH2-NEXT:    20024:       00 00 00 00     nop
# ORPH2-NEXT:    20028:       0c 00 80 14     jal     131152 <fnpic>
# ORPH2-NEXT:    2002c:       00 00 00 00     nop

# ORPH2: __LA25Thunk_fpic:
# ORPH2-NEXT:    20030:       3c 19 00 02     lui     $25, 2
# ORPH2-NEXT:    20034:       08 00 80 10     j       131136 <fpic>
# ORPH2-NEXT:    20038:       27 39 00 40     addiu   $25, $25, 64
# ORPH2-NEXT:    2003c:       00 00 00 00     nop

# ORPH2: fpic:
# ORPH2-NEXT:    20040:       00 00 00 00     nop

# ORPH2: fnpic:
# ORPH2-NEXT:    20050:       00 00 00 00     nop
# ORPH2-EMPTY:
# ORPH2-NEXT: Disassembly of section .text:
# ORPH2-EMPTY:

# ORPH2-NEXT: __LA25Thunk_foo1a:
# ORPH2-NEXT:    20060:       3c 19 00 02     lui     $25, 2
# ORPH2-NEXT:    20064:       08 00 80 20     j       131200 <foo1a>
# ORPH2-NEXT:    20068:       27 39 00 80     addiu   $25, $25, 128
# ORPH2-NEXT:    2006c:       00 00 00 00     nop

# ORPH2: __LA25Thunk_foo1b:
# ORPH2-NEXT:    20070:       3c 19 00 02     lui     $25, 2
# ORPH2-NEXT:    20074:       08 00 80 21     j       131204 <foo1b>
# ORPH2-NEXT:    20078:       27 39 00 84     addiu   $25, $25, 132
# ORPH2-NEXT:    2007c:       00 00 00 00     nop

# ORPH2: foo1a:
# ORPH2-NEXT:    20080:       00 00 00 00     nop

# ORPH2: foo1b:
# ORPH2-NEXT:    20084:       00 00 00 00     nop

# ORPH2: __LA25Thunk_foo2:
# ORPH2-NEXT:    20088:       3c 19 00 02     lui     $25, 2
# ORPH2-NEXT:    2008c:       08 00 80 28     j       131232 <foo2>
# ORPH2-NEXT:    20090:       27 39 00 a0     addiu   $25, $25, 160
# ORPH2-NEXT:    20094:       00 00 00 00     nop

# ORPH2: foo2:
# ORPH2-NEXT:    200a0:       00 00 00 00     nop
