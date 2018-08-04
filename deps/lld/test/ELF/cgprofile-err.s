# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

# RUN: echo "A B C 100" > %t.call_graph
# RUN: not ld.lld %t --call-graph-ordering-file \
# RUN:   %t.call_graph -o /dev/null 2>&1 | FileCheck %s

# CHECK: {{.*}}.call_graph: parse error

# RUN: echo "A B C" > %t.call_graph
# RUN: not ld.lld %t --call-graph-ordering-file \
# RUN:   %t.call_graph -o /dev/null 2>&1 | FileCheck %s
