# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
# RUN: ld.lld --emit-relocs %t1.o -o %t
# RUN: llvm-readobj -t -r -s %t | FileCheck %s

## Check single dash form.
# RUN: ld.lld -emit-relocs %t1.o -o %t1
# RUN: llvm-readobj -t -r -s %t1 | FileCheck %s

## Check alias.
# RUN: ld.lld -q %t1.o -o %t2
# RUN: llvm-readobj -t -r -s %t2 | FileCheck %s

# CHECK:      Section {
# CHECK:        Index: 2
# CHECK-NEXT:   Name: .rela.text
# CHECK-NEXT:   Type: SHT_RELA
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     SHF_INFO_LINK
# CHECK-NEXT:   ]
# CHECK:      Relocations [
# CHECK-NEXT:   Section ({{.*}}) .rela.text {
# CHECK-NEXT:     0x201002 R_X86_64_32 .text 0x1
# CHECK-NEXT:     0x201007 R_X86_64_PLT32 fn 0xFFFFFFFFFFFFFFFC
# CHECK-NEXT:     0x20100E R_X86_64_32 .text 0xD
# CHECK-NEXT:     0x201013 R_X86_64_PLT32 fn2 0xFFFFFFFFFFFFFFFC
# CHECK-NEXT:   }
# CHECK-NEXT: ]
# CHECK-NEXT: Symbols [
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name:
# CHECK-NEXT:     Value: 0x0
# CHECK-NEXT:     Size: 0
# CHECK-NEXT:     Binding: Local
# CHECK-NEXT:     Type: None
# CHECK-NEXT:     Other: 0
# CHECK-NEXT:     Section: Undefined
# CHECK-NEXT:   }
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name: bar
# CHECK-NEXT:     Value: 0x201001
# CHECK-NEXT:     Size: 0
# CHECK-NEXT:     Binding: Local
# CHECK-NEXT:     Type: None
# CHECK-NEXT:     Other: 0
# CHECK-NEXT:     Section: .text
# CHECK-NEXT:   }
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name: foo
# CHECK-NEXT:     Value: 0x20100D
# CHECK-NEXT:     Size: 0
# CHECK-NEXT:     Binding: Local
# CHECK-NEXT:     Type: None
# CHECK-NEXT:     Other: 0
# CHECK-NEXT:     Section: .text
# CHECK-NEXT:   }
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name:
# CHECK-NEXT:     Value: 0x201000
# CHECK-NEXT:     Size: 0
# CHECK-NEXT:     Binding: Local
# CHECK-NEXT:     Type: Section
# CHECK-NEXT:     Other: 0
# CHECK-NEXT:     Section: .text
# CHECK-NEXT:   }
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name: fn
# CHECK-NEXT:     Value: 0x201000
# CHECK-NEXT:     Size: 0
# CHECK-NEXT:     Binding: Global
# CHECK-NEXT:     Type: Function
# CHECK-NEXT:     Other: 0
# CHECK-NEXT:     Section: .text
# CHECK-NEXT:   }
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name: fn2
# CHECK-NEXT:     Value: 0x20100C
# CHECK-NEXT:     Size: 0
# CHECK-NEXT:     Binding: Global
# CHECK-NEXT:     Type: Function
# CHECK-NEXT:     Other: 0
# CHECK-NEXT:     Section: .text
# CHECK-NEXT:   }
# CHECK-NEXT: ]

.section .text,"ax",@progbits,unique,0
.globl fn
.type fn,@function
fn:
 nop

bar:
  movl $bar, %edx
  callq fn@PLT
  nop

.section .text,"ax",@progbits,unique,1
.globl fn2
.type fn2,@function
fn2:
 nop

foo:
  movl $foo, %edx
  callq fn2@PLT
  nop
