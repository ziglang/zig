# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "SECTIONS { /DISCARD/ : { *(.discard.*) }}" > %t.script
# RUN: ld.lld -o %t --script %t.script -r %t.o
# RUN: llvm-readobj -sections %t | FileCheck %s

## Test shows that we do not crash after discarding the .discard.foo with -r.
## Previously it happened because of 2 reasons:
## 1) .rela.discard.foo was not handled properly and was not discarded.
##    Remaining reference was invalid and caused the crash.
## 2) Third-party section .debug_info referencing discarded section
##    did not handle this case properly and tried to apply the
##    relocation instead of ignoring it.

# CHECK-NOT: .discard

.section .discard.foo,"ax"
callq fn@PLT

.section .debug_info,"",@progbits
.long .discard.foo
