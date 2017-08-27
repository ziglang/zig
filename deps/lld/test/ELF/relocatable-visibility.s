# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld -r %t.o -o %t1
# RUN: llvm-readobj -t %t1 | FileCheck --check-prefix=RELOCATABLE %s

# RELOCATABLE:      Name: foo
# RELOCATABLE-NEXT: Value: 0x0
# RELOCATABLE-NEXT: Size: 0
# RELOCATABLE-NEXT: Binding: Global
# RELOCATABLE-NEXT: Type: None
# RELOCATABLE-NEXT: Other [
# RELOCATABLE-NEXT:   STV_HIDDEN
# RELOCATABLE-NEXT: ]
# RELOCATABLE-NEXT: Section: Undefined

.global _start
_start:
 callq foo
 .hidden foo
