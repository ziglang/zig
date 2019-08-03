// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %S/Inputs/arm-exidx-cantunwind.s -o %tcantunwind
// RUN: ld.lld --no-merge-exidx-entries %t %tcantunwind -o %t2 2>&1
// RUN: llvm-objdump -d -triple=armv7a-none-linux-gnueabi %t2 | FileCheck %s
// RUN: llvm-objdump -s -triple=armv7a-none-linux-gnueabi %t2 | FileCheck -check-prefix=CHECK-EXIDX %s
// RUN: llvm-readobj --program-headers --sections %t2 | FileCheck -check-prefix=CHECK-PT %s
// Use Linker script to place .ARM.exidx in between .text and orphan sections
// RUN: echo "SECTIONS { \
// RUN:          .text 0x11000 : { *(.text*) } \
// RUN:          .ARM.exidx : { *(.ARM.exidx) } } " > %t.script
// RUN: ld.lld --no-merge-exidx-entries --script %t.script %tcantunwind %t -o %t3 2>&1
// RUN: llvm-objdump -d -triple=armv7a-none-linux-gnueabi %t3 | FileCheck -check-prefix=CHECK-SCRIPT %s
// RUN: llvm-objdump -s -triple=armv7a-none-linux-gnueabi %t3 | FileCheck -check-prefix=CHECK-SCRIPT-EXIDX %s

// Each assembler created .ARM.exidx section has the SHF_LINK_ORDER flag set
// with the sh_link containing the section index of the executable section
// containing the function it describes. The linker must combine the .ARM.exidx
// InputSections in the same order that it has combined the executable section,
// such that the combined .ARM.exidx OutputSection can be used as a binary
// search table.

 .syntax unified
 .section .text, "ax",%progbits
 .globl _start
_start:
 .fnstart
 bx lr
 .cantunwind
 .fnend

 .section .text.f1, "ax", %progbits
 .globl f1
f1:
 .fnstart
 bx lr
 .cantunwind
 .fnend

 .section .text.f2, "ax", %progbits
 .globl f2
f2:
 .fnstart
 bx lr
 .cantunwind
 .fnend
 .globl f3
f3:
 .fnstart
 bx lr
 .cantunwind
 .fnend

// Check default no linker script order.

// CHECK: Disassembly of section .text:
// CHECK-EMPTY:
// CHECK: _start:
// CHECK-NEXT:    11000:       1e ff 2f e1     bx      lr
// CHECK: f1:
// CHECK-NEXT:    11004:       1e ff 2f e1     bx      lr
// CHECK: f2:
// CHECK-NEXT:    11008:       1e ff 2f e1     bx      lr
// CHECK: f3:
// CHECK-NEXT:    1100c:       1e ff 2f e1     bx      lr
// CHECK: func4:
// CHECK-NEXT:    11010:       1e ff 2f e1     bx      lr
// CHECK: func5:
// CHECK-NEXT:    11014:       1e ff 2f e1     bx      lr
// CHECK: Disassembly of section .func1:
// CHECK-EMPTY:
// CHECK-NEXT: func1:
// CHECK-NEXT:    11018:       1e ff 2f e1     bx      lr
// CHECK: Disassembly of section .func2:
// CHECK-EMPTY:
// CHECK-NEXT: func2:
// CHECK-NEXT:    1101c:       1e ff 2f e1     bx      lr
// CHECK: Disassembly of section .func3:
// CHECK-EMPTY:
// CHECK-NEXT: func3:
// CHECK-NEXT:    11020:       1e ff 2f e1     bx      lr

// Each .ARM.exidx section has two 4 byte fields
// Field 1 is the 31-bit offset to the function. The top bit is used to
// indicate whether Field 2 is a pointer or an inline table entry.
// Field 2 is either a pointer to a .ARM.extab section or an inline table
// In this example all Field 2 entries are inline can't unwind (0x1)
// We expect to see the entries in the same order as the functions

// CHECK-EXIDX: Contents of section .ARM.exidx:
// 100d4 + f2c = 11000 = _start
// 100dc + f28 = 11004 = f1
// CHECK-EXIDX-NEXT:       100d4 2c0f0000 01000000 280f0000 01000000
// 100e4 + f24 = 11008 = f2
// 100ec + f20 = 1100c = f3
// CHECK-EXIDX-NEXT:  100e4 240f0000 01000000 200f0000 01000000
// 100f4 + f1c = 11010 = func4
// 100fc + f18 = 11014 = func5
// CHECK-EXIDX-NEXT:  100f4 1c0f0000 01000000 180f0000 01000000
// 10104 + f14 = 11018 = func1
// 1010c + f10 = 1101c = func2
// CHECK-EXIDX-NEXT:  10104 140f0000 01000000 100f0000 01000000
// 10114 + f0c = 11020 = func3
// CHECK-EXIDX-NEXT:  10114 0c0f0000 01000000

// Check that PT_ARM_EXIDX program header has been generated that describes
// the .ARM.exidx output section
// CHECK-PT:          Name: .ARM.exidx
// CHECK-PT-NEXT:     Type: SHT_ARM_EXIDX (0x70000001)
// CHECK-PT-NEXT:     Flags [
// CHECK-PT-NEXT:       SHF_ALLOC
// CHECK-PT-NEXT:       SHF_LINK_ORDER
// CHECK-PT-NEXT:     ]
// CHECK-PT-NEXT:     Address: 0x100D4
// CHECK-PT-NEXT:     Offset: 0xD4
// CHECK-PT-NEXT:     Size: 80

// CHECK-PT:          Type: PT_ARM_EXIDX (0x70000001)
// CHECK-PT-NEXT:     Offset: 0xD4
// CHECK-PT-NEXT:     VirtualAddress: 0x100D4
// CHECK-PT-NEXT:     PhysicalAddress: 0x100D4
// CHECK-PT-NEXT:     FileSize: 80
// CHECK-PT-NEXT:     MemSize: 80
// CHECK-PT-NEXT:     Flags [ (0x4)
// CHECK-PT-NEXT:       PF_R (0x4)
// CHECK-PT-NEXT:     ]
// CHECK-PT-NEXT:     Alignment: 4
// CHECK-PT-NEXT:   }


// Check linker script order. The .ARM.exidx section will be inserted after
// the .text section but before the orphan sections

// CHECK-SCRIPT: Disassembly of section .text:
// CHECK-SCRIPT-EMPTY:
// CHECK-SCRIPT-NEXT: func4:
// CHECK-SCRIPT-NEXT:    11000:       1e ff 2f e1     bx      lr
// CHECK-SCRIPT:      func5:
// CHECK-SCRIPT-NEXT:    11004:       1e ff 2f e1     bx      lr
// CHECK-SCRIPT:      _start:
// CHECK-SCRIPT-NEXT:    11008:       1e ff 2f e1     bx      lr
// CHECK-SCRIPT:      f1:
// CHECK-SCRIPT-NEXT:    1100c:       1e ff 2f e1     bx      lr
// CHECK-SCRIPT:      f2:
// CHECK-SCRIPT-NEXT:    11010:       1e ff 2f e1     bx      lr
// CHECK-SCRIPT:      f3:
// CHECK-SCRIPT-NEXT:    11014:       1e ff 2f e1     bx      lr
// CHECK-SCRIPT-EMPTY:
// CHECK-SCRIPT-NEXT: Disassembly of section .func1:
// CHECK-SCRIPT-EMPTY:
// CHECK-SCRIPT-NEXT: func1:
// CHECK-SCRIPT-NEXT:    11018:       1e ff 2f e1     bx      lr
// CHECK-SCRIPT-EMPTY:
// CHECK-SCRIPT-NEXT: Disassembly of section .func2:
// CHECK-SCRIPT-EMPTY:
// CHECK-SCRIPT-NEXT: func2:
// CHECK-SCRIPT-NEXT:    1101c:       1e ff 2f e1     bx      lr
// CHECK-SCRIPT-EMPTY:
// CHECK-SCRIPT-NEXT: Disassembly of section .func3:
// CHECK-SCRIPT-EMPTY:
// CHECK-SCRIPT-NEXT: func3:
// CHECK-SCRIPT-NEXT:    11020:       1e ff 2f e1     bx      lr

// Check that the .ARM.exidx section is sorted in order as the functions
// The offset in field 1, is 32-bit so in the binary the most significant bit
// 11024 - 24 = 11000 func4
// 1102c - 28 = 11004 func5
// CHECK-SCRIPT-EXIDX:       11024 dcffff7f 01000000 d8ffff7f 01000000
// 11034 - 2c = 11008 _start
// 1103c - 30 = 1100c f1
// CHECK-SCRIPT-EXIDX-NEXT:  11034 d4ffff7f 01000000 d0ffff7f 01000000
// 11044 - 34 = 11010 f2
// 1104c - 38 = 11014 f3
// CHECK-SCRIPT-EXIDX-NEXT:  11044 ccffff7f 01000000 c8ffff7f 01000000
// 11054 - 3c = 11018 func1
// 1105c - 40 = 1101c func2
// CHECK-SCRIPT-EXIDX-NEXT:  11054 c4ffff7f 01000000 c0ffff7f 01000000
// 11064 - 44 = 11020 func3
// 11068 - 48 = 11024 func3 + sizeof(func3)
// CHECK-SCRIPT-EXIDX-NEXT:  11064 bcffff7f 01000000 b8ffff7f 01000000
