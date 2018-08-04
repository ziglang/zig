# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: ld.lld %t -o %t2 --icf=all --print-icf-sections | FileCheck %s
# RUN: ld.lld %t -o %t2 --keep-unique f2 --keep-unique f4 --keep-unique f5 --icf=all --print-icf-sections 2>&1 | FileCheck %s -check-prefix=CHECK-KEEP

// Base case, expect only .text.f1 to be kept
// CHECK: selected section {{.*}}:(.text.f1)
// CHECK-NEXT:   removing identical section {{.*}}:(.text.f2)
// CHECK-NEXT:   removing identical section {{.*}}:(.text.f3)
// CHECK-NEXT:   removing identical section {{.*}}:(.text.f4)
// CHECK-NEXT:   removing identical section {{.*}}:(.text.f5)

// With --keep-unique f2, f4 and f5 we expect only f3 and f5 to be removed.
// f5 is not matched by --keep-unique as it is a local symbol.
// CHECK-KEEP: warning: could not find symbol f5 to keep unique
// CHECK-KEEP: selected section {{.*}}:(.text.f1)
// CHECK-KEEP-NEXT:   removing identical section {{.*}}:(.text.f3)
// CHECK-KEEP-NEXT:   removing identical section {{.*}}:(.text.f5)
 .globl _start, f1, f2, f3, f4
_start:
 ret

 .section .text.f1, "ax"
f1:
 nop

 .section .text.f2, "ax"
f2:
 nop

.section .text.f3, "ax"
f3:
 nop

.section .text.f4, "ax"
f4:
 nop

# f5 is local, not found by --keep-unique f5
.section .text.f5, "ax"
f5:
 nop
