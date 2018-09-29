# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: ld.lld %t -o /dev/null --icf=all --ignore-data-address-equality --print-icf-sections | FileCheck %s

# CHECK: selected section {{.*}}:(.data.rel.ro)
# CHECK:   removing identical section {{.*}}:(.data.rel.ro.foo)

.section .data.rel.ro,"aw"
.quad foo

.section .data.rel.ro.foo,"aw"
foo:
.quad foo
