# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "SECTIONS { /DISCARD/ : { *(.foo) } }" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -section-headers %t1 | FileCheck %s

# CHECK-NOT: .foo
# CHECK-NOT: .bar
# CHECK-NOT: .zed
# CHECK-NOT: .moo

## Sections dependency tree for testcase is:
## (.foo)
##   | |
##   | --(.bar)
##   |
##   --(.zed)
##       |
##       --(.moo)
##

.section .foo,"a"
.quad 0

.section .bar,"ao",@progbits,.foo
.quad 0

.section .zed,"ao",@progbits,.foo
.quad 0

.section .moo,"ao",@progbits,.zed
.quad 0
