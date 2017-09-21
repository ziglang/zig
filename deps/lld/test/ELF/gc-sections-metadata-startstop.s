# LINK_ORDER cnamed sections are not kept alive by the __start_* reference.
# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld --gc-sections %t.o -o %t
# RUN: llvm-objdump -section-headers -t %t | FileCheck  %s

# CHECK: Sections:
# CHECK-NOT: yy
# CHECK: xx {{.*}} DATA
# CHECK-NOT: yy

# CHECK: SYMBOL TABLE:
# CHECK: xx 00000000 __start_xx
# CHECK: w *UND* 00000000 __start_yy

.weak __start_xx
.weak __start_yy

.global _start
_start:
.quad __start_xx
.quad __start_yy

.section xx,"a"
.quad 0

.section .foo,"a"
.quad 0

.section yy,"ao",@progbits,.foo
.quad 0

