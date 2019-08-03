// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/comdat.s -o %t2.o
// RUN: ld.lld -shared %t.o %t2.o -o %t
// RUN: llvm-objdump -d %t | FileCheck %s
// RUN: llvm-readobj -S --symbols %t | FileCheck --check-prefix=READ %s

// Check that we don't crash with --gc-section and that we print a list of
// reclaimed sections on stderr.
// RUN: ld.lld --gc-sections --print-gc-sections -shared %t.o %t.o %t2.o -o %t \
// RUN:   2>&1 | FileCheck --check-prefix=GC %s
// GC: removing unused section {{.*}}.o:(.text)
// GC: removing unused section {{.*}}.o:(.text3)
// GC: removing unused section {{.*}}.o:(.text)
// GC: removing unused section {{.*}}.o:(.text)

        .section	.text2,"axG",@progbits,foo,comdat,unique,0
foo:
        nop

// CHECK: Disassembly of section .text2:
// CHECK-EMPTY:
// CHECK-NEXT: foo:
// CHECK-NEXT:   1000: {{.*}}  nop
// CHECK-NOT: nop

        .section bar, "ax"
        call foo

// CHECK: Disassembly of section bar:
// CHECK-EMPTY:
// CHECK-NEXT: bar:
// 0x1000 - 0x1001 - 5 = -6
// CHECK-NEXT:   1001:	{{.*}}  callq  -6

        .section .text3,"axG",@progbits,zed,comdat,unique,0


// READ:      Name: .text2
// READ-NEXT: Type: SHT_PROGBITS
// READ-NEXT: Flags [
// READ-NEXT:   SHF_ALLOC
// READ-NEXT:   SHF_EXECINSTR
// READ-NEXT: ]

// READ:      Name: .text3
// READ-NEXT: Type: SHT_PROGBITS
// READ-NEXT: Flags [
// READ-NEXT:   SHF_ALLOC
// READ-NEXT:   SHF_EXECINSTR
// READ-NEXT: ]

// READ:      Symbols [
// READ-NEXT:   Symbol {
// READ-NEXT:     Name:  (0)
// READ-NEXT:     Value: 0x0
// READ-NEXT:     Size: 0
// READ-NEXT:     Binding: Local
// READ-NEXT:     Type: None
// READ-NEXT:     Other: 0
// READ-NEXT:     Section: Undefined
// READ-NEXT:   }
// READ-NEXT:   Symbol {
// READ-NEXT:     Name: foo
// READ-NEXT:     Value
// READ-NEXT:     Size: 0
// READ-NEXT:     Binding: Local
// READ-NEXT:     Type: None
// READ-NEXT:     Other: 0
// READ-NEXT:     Section: .text
// READ-NEXT:   }
// READ-NEXT:   Symbol {
// READ-NEXT:     Name: _DYNAMIC
// READ-NEXT:     Value: 0x2000
// READ-NEXT:     Size: 0
// READ-NEXT:     Binding: Local
// READ-NEXT:     Type: None
// READ-NEXT:     Other [ (0x2)
// READ-NEXT:       STV_HIDDEN
// READ-NEXT:     ]
// READ-NEXT:     Section: .dynamic
// READ-NEXT:   }
// READ-NEXT:   Symbol {
// READ-NEXT:     Name: abc
// READ-NEXT:     Value: 0x0
// READ-NEXT:     Size: 0
// READ-NEXT:     Binding: Global
// READ-NEXT:     Type: None
// READ-NEXT:     Other: 0
// READ-NEXT:     Section: Undefined
// READ-NEXT:   }
// READ-NEXT: ]
