# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

# RUN: echo "A B 100" > %t.call_graph
# RUN: echo "A C 40" >> %t.call_graph
# RUN: echo "B C 30" >> %t.call_graph
# RUN: echo "adena1 A 30" >> %t.call_graph
# RUN: echo "A adena2 30" >> %t.call_graph
# RUN: echo "poppy A 30" >> %t.call_graph
# RUN: ld.lld -e A %t --call-graph-ordering-file %t.call_graph -o /dev/null \
# RUN:   -noinhibit-exec -icf=all 2>&1 | FileCheck %s

    .section    .text.C,"ax",@progbits
    .globl  C
C:
    mov poppy, %rax
    retq

B = 0x1234

    .section    .text.A,"ax",@progbits
    .globl  A
A:
    mov poppy, %rax
    retq

# CHECK: unable to order absolute symbol: B
# CHECK: {{.*}}.call_graph: no such symbol: adena1
# CHECK: {{.*}}.call_graph: no such symbol: adena2
# CHECK: unable to order undefined symbol: poppy

# RUN: ld.lld %t --call-graph-ordering-file %t.call_graph -o /dev/null \
# RUN:   -noinhibit-exec -icf=all --no-warn-symbol-ordering 2>&1 \
# RUN:   | FileCheck %s --check-prefix=NOWARN
# NOWARN-NOT: unable to order
