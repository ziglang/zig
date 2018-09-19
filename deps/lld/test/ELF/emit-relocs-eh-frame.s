# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
# RUN: ld.lld --emit-relocs %t1.o -o %t
# RUN: llvm-readobj -r %t | FileCheck %s

# CHECK:      Relocations [
# CHECK-NEXT:   Section {{.*}} .rela.eh_frame {
# CHECK-NEXT:     0x{{.*}} R_X86_64_PC32 .text 0x0
# CHECK-NEXT:   }
# CHECK-NEXT: ]

.text
.globl foo
foo:
 .cfi_startproc
 .cfi_endproc
